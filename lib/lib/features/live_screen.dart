import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart'
    show Room, RoomOptions, VideoTrack, VideoTrackRenderer;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Tables used: live_rooms (owner_id, room_name, is_live) and
// chat_messages (room_id, sender_id, message).
class LiveScreen extends StatefulWidget {
  final String userName;
  final String userId;

  // null = you go live as Host. A room id = you watch as Viewer.
  final String? joinRoomId;
  final String roomType;

  const LiveScreen({
    super.key,
    required this.userName,
    required this.userId,
    this.joinRoomId,
    this.roomType = 'video',
  });

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool get _isHost => widget.joinRoomId == null;

  bool _isLive = false;
  bool _busy = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _chatEnabled = true;
  bool _hostSeen = false;
  late String _selectedRoomType = widget.roomType;
  CameraController? _previewCamera;
  List<CameraDescription> _availableCameras = <CameraDescription>[];
  bool _previewLoading = false;
  bool _frontCamera = true;
  String? _previewError;
  String _previewFilter = 'Natural';
  double _filterStrength = 0.35;
  static const List<String> _previewFilters = <String>['Natural', 'Warm', 'Cool', 'Mono', 'Rose'];

  String? _roomId;
  String? _roomOwnerId;
  String _roomName = '';

  RealtimeChannel? _channel;
  Room? _lk;
  Timer? _guestPoller;
  bool _isGuest = false;
  bool _guestInviteDialogShown = false;
  String? _guestSeatId;
  List<Map<String, dynamic>> _guestSeats = <Map<String, dynamic>>[];

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _messageController =
      TextEditingController();

  final List<Map<String, String>> _messages = [];
  final Set<String> _seenMessageIds = {};

  String? get _myId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (!_isHost) {
      _busy = true;
      _joinAsViewer();
    } else if (_selectedRoomType == 'video') {
      unawaited(_initializePreviewCamera());
    }
    _guestPoller = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshGuestState(),
    );
  }


  Future<void> _initializePreviewCamera() async {
    if (!mounted || !_isHost || _isLive || _busy || _selectedRoomType != 'video' || _previewLoading) return;
    setState(() { _previewLoading = true; _previewError = null; });
    CameraController? next;
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) throw StateError('Camera permission is required.');
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) throw StateError('No camera found.');
      final direction = _frontCamera ? CameraLensDirection.front : CameraLensDirection.back;
      final description = _availableCameras.firstWhere(
        (item) => item.lensDirection == direction,
        orElse: () => _availableCameras.first,
      );
      next = CameraController(description, ResolutionPreset.high, enableAudio: false);
      await next.initialize();
      if (!mounted || _busy || _isLive || _selectedRoomType != 'video') {
        await next.dispose();
        return;
      }
      final old = _previewCamera;
      _previewCamera = next;
      next = null;
      await old?.dispose();
    } catch (error) {
      await next?.dispose();
      if (mounted) _previewError = error.toString();
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _disposePreviewCamera() async {
    final old = _previewCamera;
    _previewCamera = null;
    if (old != null) {
      try { await old.dispose(); } catch (_) {}
    }
  }

  Future<void> _flipPreviewCamera() async {
    if (_availableCameras.length < 2) {
      _showMessage('इस डिवाइस पर दूसरा Camera उपलब्ध नहीं है।');
      return;
    }
    setState(() => _frontCamera = !_frontCamera);
    await _disposePreviewCamera();
    await _initializePreviewCamera();
  }

  ColorFilter get _selectedPreviewColorFilter {
    if (_previewFilter == 'Mono') {
      return const ColorFilter.mode(Colors.white, BlendMode.saturation);
    }
    Color tint = Colors.transparent;
    if (_previewFilter == 'Warm') tint = const Color(0xFFFFA45B);
    if (_previewFilter == 'Cool') tint = const Color(0xFF73B9FF);
    if (_previewFilter == 'Rose') tint = const Color(0xFFFF78B7);
    return ColorFilter.mode(tint.withOpacity(_filterStrength * 0.30), BlendMode.softLight);
  }

  // ---------- Host: go live ----------
  Future<void> _startLive() async {
    if (_busy) return;

    final myId = _myId;
    final title = _titleController.text.trim();

    if (myId == null) {
      _showMessage('Live शुरू करने के लिए पहले Login करें।');
      return;
    }

    if (title.isEmpty) {
      _showMessage('Please enter a live room title.');
      return;
    }

    final requestedPermissions = <Permission>[Permission.microphone];
    if (_selectedRoomType == 'video') requestedPermissions.add(Permission.camera);
    final permissions = await requestedPermissions.request();
    if (permissions[Permission.microphone]?.isGranted != true ||
        (_selectedRoomType == 'video' && permissions[Permission.camera]?.isGranted != true)) {
      _showMessage('इस Room के लिए जरूरी Microphone/Camera permission दें।');
      return;
    }

    if (!mounted) return;
    setState(() => _busy = true);

    try {
      if (_selectedRoomType == 'video') await _disposePreviewCamera();
      // Close any old room of mine that is stuck as live.
      await _supabase
          .from('live_rooms')
          .update({'is_live': false})
          .eq('owner_id', myId)
          .eq('is_live', true);

      final row = await _supabase
          .from('live_rooms')
          .insert({
            'owner_id': myId,
            'room_name': title,
            'room_type': _selectedRoomType,
            'is_live': true,
          })
          .select('id')
          .single();

      final roomId = row['id'] as String;
      _roomId = roomId;
      _roomOwnerId = myId;

      await _connectLiveKit(roomId);
      _subscribeRealtime(roomId);

      if (!mounted) return;
      setState(() {
        _roomName = title;
        _isLive = true;
        _messages.clear();
        _seenMessageIds.clear();
      });

      _showMessage('आप Live हैं।');
    } catch (error) {
      final roomId = _roomId;
      _roomId = null;
      if (roomId != null) await _markRoomEnded(roomId);
      await _closeChannel();
      await _disconnectLiveKit();
      _showMessage('Live शुरू नहीं हुआ: ${_readable(error)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (!_isLive && _selectedRoomType == 'video') {
          unawaited(_initializePreviewCamera());
        }
      }
    }
  }

  // ---------- Viewer: join ----------
  Future<void> _joinAsViewer() async {
    final roomId = widget.joinRoomId!;
    var joined = false;

    try {
      if (_myId == null) {
        _showMessage('Live देखने के लिए पहले Login करें।');
        return;
      }

      final room = await _supabase
          .from('live_rooms')
          .select('room_name, owner_id, is_live, room_type')
          .eq('id', roomId)
          .maybeSingle();

      if (room == null || room['is_live'] != true) {
        _showMessage('यह Live खत्म हो चुका है।');
        return;
      }

      _roomOwnerId = room['owner_id'] as String?;
      _roomName = (room['room_name'] ?? '').toString();
      _selectedRoomType = (room['room_type'] ?? 'video').toString().toLowerCase();

      await _connectLiveKit(roomId);
      _subscribeRealtime(roomId);

      if (!mounted) return;
      setState(() {
        _roomId = roomId;
        _isLive = true;
      });
      joined = true;
    } catch (error) {
      _showMessage('Live में जुड़ नहीं सके: ${_readable(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
      if (!joined) {
        await _closeChannel();
        await _disconnectLiveKit();
        if (mounted) Navigator.of(context).maybePop();
      }
    }
  }

  // ---------- LiveKit (video + audio) ----------
  Future<void> _connectLiveKit(String roomId) async {
    final response = await _supabase.functions.invoke(
      'livekit-token',
      body: {'room_id': roomId},
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    final room = Room();
    _lk = room;
    room.addListener(_onRoomChanged);

    await room.connect(
      data['url'] as String,
      data['token'] as String,
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    _isGuest = data['is_guest'] == true;
    _guestSeatId = data['seat_id']?.toString();
    if (_isHost || _isGuest) {
      final audioAllowed = _isHost || data['audio_enabled'] == true;
      final videoAllowed = _selectedRoomType == 'video' &&
          (_isHost || data['video_enabled'] == true);
      if (_isGuest) {
        final micPermission = await Permission.microphone.request();
        if (!micPermission.isGranted) {
          throw StateError('Microphone permission is required for guest audio.');
        }
        if (videoAllowed) await Permission.camera.request();
      }
      await room.localParticipant?.setMicrophoneEnabled(
        audioAllowed && _microphoneEnabled,
      );
      if (_selectedRoomType == 'video') {
        await room.localParticipant?.setCameraEnabled(videoAllowed);
      }
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;

    // Viewer: if the host was here and has now left, the live is over.
    final room = _lk;
    final ownerId = _roomOwnerId;
    if (!_isHost && room != null && ownerId != null) {
      final hostHere =
          room.remoteParticipants.values.any((p) => p.identity == ownerId);
      if (hostHere) {
        _hostSeen = true;
      } else if (_hostSeen && _isLive) {
        _hostSeen = false;
        _showMessage('Live खत्म हो गया।');
        _leaveViewer();
        return;
      }
    }

    setState(() {});
  }

  Future<void> _disconnectLiveKit() async {
    final room = _lk;
    _lk = null;
    if (room == null) return;

    room.removeListener(_onRoomChanged);
    try {
      await room.disconnect();
    } catch (_) {}
    room.dispose();
  }

  VideoTrack? _activeVideoTrack() {
    final room = _lk;
    if (room == null) return null;

    if (_isHost) {
      final pubs = room.localParticipant?.videoTrackPublications;
      if (pubs != null) {
        for (final pub in pubs) {
          final track = pub.track;
          if (track != null) return track;
        }
      }
    } else {
      for (final participant in room.remoteParticipants.values) {
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (pub.subscribed && track != null) return track;
        }
      }
    }
    return null;
  }

  Future<void> _refreshGuestState() async {
    final roomId = _roomId;
    final myId = _myId;
    if (!mounted || !_isLive || roomId == null || myId == null) return;

    try {
      if (_isHost) {
        final rows = await _supabase
            .from('room_guest_seats')
            .select('id, seat_number, user_id, seat_status, is_video_enabled, is_audio_enabled')
            .eq('room_id', roomId)
            .order('seat_number', ascending: true);
        if (mounted) {
          setState(() {
            _guestSeats = (rows as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList();
          });
        }
        return;
      }

      final invitations = await _supabase
          .from('room_guest_invitations')
          .select('id, seat_number, inviter_id, invite_status, expires_at, is_video_enabled, is_audio_enabled')
          .eq('room_id', roomId)
          .eq('invitee_id', myId)
          .eq('invite_status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);

      if ((invitations as List).isNotEmpty && !_guestInviteDialogShown) {
        unawaited(_showIncomingGuestInvite(
          Map<String, dynamic>.from(invitations.first as Map),
        ));
      }

      if (_isGuest) {
        final seat = await _supabase
            .from('room_guest_seats')
            .select('id, seat_number, is_video_enabled, is_audio_enabled')
            .eq('room_id', roomId)
            .eq('user_id', myId)
            .eq('seat_status', 'occupied')
            .maybeSingle();
        if (mounted && seat != null) {
          setState(() => _guestSeatId = seat['id']?.toString());
        }
      }
    } catch (error) {
      // Guest polling is best-effort; the main live session stays connected.
    }
  }

  Future<void> _showIncomingGuestInvite(Map<String, dynamic> invitation) async {
    if (!mounted || _guestInviteDialogShown) return;
    _guestInviteDialogShown = true;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF241630),
        title: const Text('Guest Seat Invitation',
            style: TextStyle(color: Color(0xFFE5BD70))),
        content: Text(
          'The host invited you to guest seat ${invitation['seat_number']}. Join this live room as a guest?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (accept == null) return;
    await _respondGuestInvitation(invitation['id'].toString(), accept);
  }

  Future<void> _respondGuestInvitation(String invitationId, bool accept) async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      if (accept) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          _showMessage('Microphone permission is required to join as a guest.');
          _guestInviteDialogShown = false;
          return;
        }
        if (_selectedRoomType == 'video') {
          await Permission.camera.request();
        }
      }

      final seatId = await _supabase.rpc(
        'room_respond_guest_invitation',
        params: <String, dynamic>{
          'p_invitation_id': invitationId,
          'p_accept': accept,
        },
      );

      if (accept) {
        await _disconnectLiveKit();
        await _connectLiveKit(roomId);
        if (mounted) {
          setState(() {
            _isGuest = true;
            _guestSeatId = seatId?.toString();
          });
        }
        _showMessage('You joined the live as a guest.');
      } else {
        _showMessage('Guest invitation declined.');
      }
    } catch (error) {
      _guestInviteDialogShown = false;
      _showMessage('Guest invitation failed: ${_readable(error)}');
    }
  }

  Future<void> _showGuestInviteDialog() async {
    final roomId = _roomId;
    if (roomId == null || !_isHost) return;
    final idController = TextEditingController();
    int seatNumber = 1;
    bool videoEnabled = _selectedRoomType == 'video';
    bool audioEnabled = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF241630),
          title: const Text('Invite Guest', style: TextStyle(color: Color(0xFFE5BD70))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Guest ZOONL ID',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: seatNumber,
                dropdownColor: const Color(0xFF241630),
                isExpanded: true,
                items: List<DropdownMenuItem<int>>.generate(
                  6,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('Guest Seat ${index + 1}'),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) setDialogState(() => seatNumber = value);
                },
              ),
              if (_selectedRoomType == 'video')
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Guest Video', style: TextStyle(color: Colors.white)),
                  value: videoEnabled,
                  onChanged: (value) => setDialogState(() => videoEnabled = value ?? false),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Guest Audio', style: TextStyle(color: Colors.white)),
                value: audioEnabled,
                onChanged: (value) => setDialogState(() => audioEnabled = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, <String, dynamic>{
                'zoonl_id': idController.text.trim(),
                'seat_number': seatNumber,
                'video_enabled': videoEnabled,
                'audio_enabled': audioEnabled,
              }),
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
    final guestId = (result?['zoonl_id'] ?? '').toString();
    idController.dispose();
    if (result == null || guestId.isEmpty) return;

    try {
      await _supabase.rpc(
        'room_invite_guest',
        params: <String, dynamic>{
          'p_room_id': roomId,
          'p_target_zoonl_id': guestId,
          'p_seat_number': result['seat_number'],
          'p_video_enabled': result['video_enabled'],
          'p_audio_enabled': result['audio_enabled'],
        },
      );
      _showMessage('Guest invitation sent.');
    } catch (error) {
      _showMessage('Could not invite guest: ${_readable(error)}');
    }
  }

  Widget _guestMiniOverlay() {
    final room = _lk;
    if (room == null) return const SizedBox.shrink();

    if (_isGuest) {
      VideoTrack? localTrack;
      for (final publication
          in room.localParticipant?.videoTrackPublications ?? const []) {
        if (publication.track is VideoTrack) {
          localTrack = publication.track as VideoTrack;
          break;
        }
      }
      if (localTrack == null) return const SizedBox.shrink();
      return Container(
        width: 112,
        height: 156,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF21152F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5BD70), width: 2),
        ),
        child: VideoTrackRenderer(localTrack),
      );
    }

    if (!_isHost) return const SizedBox.shrink();
    final guests = room.remoteParticipants.values.where((participant) {
      if (participant.identity == _roomOwnerId) return false;
      return participant.videoTrackPublications.any(
        (publication) => publication.track is VideoTrack,
      );
    }).toList();
    if (guests.isEmpty) return const SizedBox.shrink();

    final participant = guests.first;
    VideoTrack? guestTrack;
    for (final publication in participant.videoTrackPublications) {
      if (publication.track is VideoTrack) {
        guestTrack = publication.track as VideoTrack;
        break;
      }
    }
    if (guestTrack == null) return const SizedBox.shrink();
    return Container(
      width: 112,
      height: 156,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF21152F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5BD70), width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(guestTrack),
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              color: Colors.black54,
              child: Text(
                'Guest ${participant.identity.substring(0, participant.identity.length > 6 ? 6 : participant.identity.length)}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Realtime: chat + room end ----------
  void _subscribeRealtime(String roomId) {
    _channel = _supabase
        .channel('live_room_$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => _addIncoming(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) {
            if (!_isHost && payload.newRecord['is_live'] == false) {
              _showMessage('Live खत्म हो गया।');
              _leaveViewer();
            }
          },
        )
        .subscribe();
  }

  String _nameFor(String? senderId) {
    if (senderId == null) return 'User';
    if (senderId == _myId) return widget.userName;
    if (senderId == _roomOwnerId) return 'Host';
    return 'User ${senderId.substring(0, 4)}';
  }

  void _addIncoming(Map<String, dynamic> row) {
    if (!mounted) return;

    final id = (row['id'] ?? '').toString();
    if (id.isNotEmpty && !_seenMessageIds.add(id)) return;

    setState(() {
      _messages.add({
        'name': _nameFor(row['sender_id']?.toString()),
        'message': (row['message'] ?? '').toString(),
      });
    });
  }

  Future<void> _sendMessage() async {
    final roomId = _roomId;
    final myId = _myId;
    final message = _messageController.text.trim();

    if (roomId == null || message.isEmpty) return;

    if (myId == null) {
      _showMessage('Message भेजने के लिए पहले Login करें।');
      return;
    }

    _messageController.clear();

    try {
      final row = await _supabase
          .from('chat_messages')
          .insert({
            'room_id': roomId,
            'sender_id': myId,
            'message': message,
          })
          .select('id, sender_id, message')
          .single();

      // Show it right away; realtime copy is skipped by id.
      _addIncoming(row);
    } catch (error) {
      _showMessage('Message नहीं गया: ${_readable(error)}');
    }
  }

  // ---------- End / leave ----------
  Future<void> _markRoomEnded(String roomId) async {
    try {
      await _supabase
          .from('live_rooms')
          .update({'is_live': false})
          .eq('id', roomId);
    } catch (_) {}
  }

  Future<void> _endLive() async {
    if (_busy) return;
    setState(() => _busy = true);

    final roomId = _roomId;
    if (roomId != null) {
      for (final seat in _guestSeats) {
        final seatId = seat['id']?.toString();
        if (seatId == null || seat['seat_status'] != 'occupied') continue;
        try {
          await _supabase.rpc(
            'room_remove_guest',
            params: <String, dynamic>{'p_seat_id': seatId},
          );
        } catch (_) {}
      }
      await _markRoomEnded(roomId);
    }

    await _closeChannel();
    await _disconnectLiveKit();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _isLive = false;
      _isGuest = false;
      _guestSeatId = null;
      _guestSeats.clear();
      _roomId = null;
      _messages.clear();
      _seenMessageIds.clear();
      _messageController.clear();
    });
    _showMessage('Live session ended.');
    if (_selectedRoomType == 'video') unawaited(_initializePreviewCamera());
  }

  Future<void> _leaveViewer() async {
    final seatId = _guestSeatId;
    if (_isGuest && seatId != null) {
      try {
        await _supabase.rpc(
          'room_leave_guest_seat',
          params: <String, dynamic>{'p_seat_id': seatId},
        );
      } catch (_) {}
    }
    _isGuest = false;
    _guestSeatId = null;
    await _closeChannel();
    await _disconnectLiveKit();

    if (!mounted) return;
    setState(() {
      _isLive = false;
      _roomId = null;
    });
    Navigator.of(context).maybePop();
  }

  Future<void> _closeChannel() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
  }

  // ---------- Controls ----------
  Future<void> _toggleMicrophone() async {
    final next = !_microphoneEnabled;
    try {
      await _lk?.localParticipant?.setMicrophoneEnabled(next);
      if (mounted) setState(() => _microphoneEnabled = next);
    } catch (error) {
      _showMessage('Microphone बदल नहीं सका: ${_readable(error)}');
    }
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraEnabled;
    try {
      await _lk?.localParticipant?.setCameraEnabled(next);
      if (mounted) setState(() => _cameraEnabled = next);
    } catch (error) {
      _showMessage('Camera बदल नहीं सका: ${_readable(error)}');
    }
  }

  String _readable(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    if (error is FunctionException) {
      return 'server error (${error.status}) ${error.details ?? ''}';
    }
    return error.toString();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF39234D),
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: color,
            fixedSize: const Size(52, 52),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }

  @override
  void dispose() {
    final roomId = _roomId;
    if (_isHost && roomId != null) {
      unawaited(_markRoomEnded(roomId));
    }

    unawaited(_closeChannel());
    unawaited(_disconnectLiveKit());

    _guestPoller?.cancel();
    if (_isGuest && _guestSeatId != null) {
      unawaited(_supabase.rpc(
        'room_leave_guest_seat',
        params: <String, dynamic>{'p_seat_id': _guestSeatId},
      ).then((_) {}).catchError((_) {}));
    }
    final preview = _previewCamera;
    _previewCamera = null;
    if (preview != null) unawaited(preview.dispose());

    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLive) {
      body = _buildLiveRoom();
    } else if (_isHost) {
      body = _buildStartScreen();
    } else {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFFE5BD70)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'ZOONL LIVE ROOM',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: body),
    );
  }


  Widget _buildCameraPreviewPanel() {
    final camera = _previewCamera;
    return Container(
      height: 330,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF21152F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF9360F5)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (camera != null && camera.value.isInitialized)
            ColorFiltered(
              colorFilter: _selectedPreviewColorFilter,
              child: CameraPreview(camera),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_previewLoading ? Icons.camera : Icons.no_photography,
                      size: 58, color: const Color(0xFFE5BD70)),
                  const SizedBox(height: 10),
                  Text(
                    _previewError ?? (_previewLoading ? 'Opening camera...' : 'Camera preview unavailable'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (!_previewLoading)
                    TextButton(
                      onPressed: _initializePreviewCamera,
                      child: const Text('Retry camera'),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('PRE-LIVE PREVIEW',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filled(
              onPressed: _previewLoading ? null : _flipPreviewCamera,
              style: IconButton.styleFrom(
                  backgroundColor: Colors.black54, foregroundColor: Colors.white),
              icon: const Icon(Icons.flip_camera_android),
              tooltip: 'Switch camera',
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Text('Filter: $_previewFilter',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_selectedRoomType == 'video') ...[
          _buildCameraPreviewPanel(),
          const SizedBox(height: 16),
          const Text('Preview Filters',
              style: TextStyle(
                  color: Color(0xFFE5BD70),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _previewFilters.map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: _previewFilter == filter,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _previewFilter = filter),
              );
            }).toList(),
          ),
          Row(
            children: [
              const Text('Intensity',
                  style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _filterStrength,
                  min: 0,
                  max: 1,
                  activeColor: const Color(0xFFDA65C8),
                  onChanged: (value) =>
                      setState(() => _filterStrength = value),
                ),
              ),
              Text('${(_filterStrength * 100).round()}%',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
          const Text(
            'Note: these colour effects change the pre-live preview only. '
            'Face retouch effects (Whitening, Teeth, Big Eyes and Peeling) '
            'need a face-effects SDK before they can be applied to the outgoing stream.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ] else
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6E3B8F), Color(0xFF21152F)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.headphones, size: 72, color: Color(0xFFE5BD70)),
                SizedBox(height: 10),
                Text('AUDIO LIVE READY',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text('Start Your Live Room',
            style: TextStyle(
                color: Color(0xFFE5BD70),
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          maxLength: 60,
          decoration: InputDecoration(
            labelText: 'Live Room Title',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF241630),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Room Type',
            style: TextStyle(
                color: Color(0xFFE5BD70), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Video Live'),
                selected: _selectedRoomType == 'video',
                onSelected: _busy
                    ? null
                    : (_) {
                        setState(() => _selectedRoomType = 'video');
                        unawaited(_initializePreviewCamera());
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Audio Live'),
                selected: _selectedRoomType == 'audio',
                onSelected: _busy
                    ? null
                    : (_) {
                        setState(() => _selectedRoomType = 'audio');
                        unawaited(_disposePreviewCamera());
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF241630),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFE5BD70)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${widget.userName}  •  ID ${widget.userId}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filled(
              onPressed: _toggleMicrophone,
              style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF39234D),
                  foregroundColor: Colors.white),
              icon: Icon(_microphoneEnabled ? Icons.mic : Icons.mic_off),
              tooltip: 'Toggle microphone before live',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _microphoneEnabled
                    ? 'Microphone will be ON when live starts'
                    : 'Live will start with microphone muted',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _startLive,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_circle),
            label: Text(_busy
                ? 'CONNECTING...'
                : _selectedRoomType == 'audio'
                    ? 'START AUDIO LIVE'
                    : 'GO LIVE'),
          ),
        ),
      ],
    );
  }

  Widget _videoLayer() {
    final track = _activeVideoTrack();

    if (track != null) {
      return VideoTrackRenderer(track);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 110, color: Color(0xFFE5BD70)),
          if (!_isHost)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Host का video आ रहा है...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveRoom() {
    final viewers = _lk?.remoteParticipants.length ?? 0;

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFF21152F),
                child: _selectedRoomType == 'audio'
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.headphones, size: 100, color: Color(0xFFE5BD70)), SizedBox(height: 12), Text('AUDIO LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))]))
                    : _videoLayer(),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$viewers',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isHost && _guestSeats.any((seat) => seat['seat_status'] == 'occupied') || _isGuest)
                Positioned(
                  right: 14,
                  bottom: 54,
                  child: _guestMiniOverlay(),
                ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Text(
                  _roomName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_chatEnabled)
          Container(
            height: 145,
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1B1225),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item =
                          _messages[_messages.length - 1 - index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${item['name']}: ${item['message']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLength: 300,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          hintStyle: TextStyle(color: Colors.white54),
                          counterText: '',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFFE5BD70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
          color: const Color(0xFF1B1225),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _isHost ? _hostControls() : _viewerControls(),
          ),
        ),
      ],
    );
  }

  List<Widget> _hostControls() {
    return [
      _control(
        icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
        label: 'Microphone',
        onTap: _toggleMicrophone,
      ),
      if (_selectedRoomType == 'video') _control(
        icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
        label: 'Camera',
        onTap: _toggleCamera,
      ),
      _control(
        icon: Icons.chat,
        label: 'Chat',
        onTap: () => setState(() => _chatEnabled = !_chatEnabled),
      ),
      _control(
        icon: Icons.person_add_alt_1,
        label: 'Guest',
        onTap: _showGuestInviteDialog,
      ),
      _control(
        icon: Icons.call_end,
        label: 'End Live',
        color: Colors.red,
        onTap: _endLive,
      ),
    ];
  }

  List<Widget> _viewerControls() {
    if (_isGuest) {
      return [
        _control(
          icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
          label: 'Mic',
          onTap: _toggleMicrophone,
        ),
        if (_selectedRoomType == 'video')
          _control(
            icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            onTap: _toggleCamera,
          ),
        _control(
          icon: Icons.exit_to_app,
          label: 'Leave Guest',
          color: Colors.red,
          onTap: _leaveViewer,
        ),
      ];
    }
    return [
      _control(
        icon: Icons.chat,
        label: 'Chat',
        onTap: () => setState(() => _chatEnabled = !_chatEnabled),
      ),
      _control(
        icon: Icons.exit_to_app,
        label: 'Leave',
        color: Colors.red,
        onTap: _leaveViewer,
      ),
    ];
  }
}
