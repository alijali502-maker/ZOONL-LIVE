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
  }


  Future<void> _initializePreviewCamera() async {
    if (!mounted || !_isHost || _isLive || _selectedRoomType != 'video' || _previewLoading) return;
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
      if (!mounted) { await next.dispose(); return; }
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
      if (mounted) setState(() => _busy = false);
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

    if (_isHost) {
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (_selectedRoomType == 'video') {
        await room.localParticipant?.setCameraEnabled(true);
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
    if (roomId != null) await _markRoomEnded(roomId);

    await _closeChannel();
    await _disconnectLiveKit();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _isLive = false;
      _roomId = null;
      _messages.clear();
      _seenMessageIds.clear();
      _messageController.clear();
    });
    _showMessage('Live session ended.');
  }

  Future<void> _leaveViewer() async {
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

  Widget _buildStartScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6E3B8F), Color(0xFF21152F)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Icon(
              _selectedRoomType == 'audio' ? Icons.headphones : Icons.live_tv,
              size: 85,
              color: const Color(0xFFE5BD70),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Start Your Live Room',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
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
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Room Type', style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ChoiceChip(label: const Text('Video Live'), selected: _selectedRoomType == 'video', onSelected: _busy ? null : (_) => setState(() => _selectedRoomType = 'video'))),
          const SizedBox(width: 10),
          Expanded(child: ChoiceChip(label: const Text('Audio Live'), selected: _selectedRoomType == 'audio', onSelected: _busy ? null : (_) => setState(() => _selectedRoomType = 'audio'))),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF241630),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFE5BD70)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.userName}  •  ID ${widget.userId}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _startLive,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle),
            label: const Text('GO LIVE'),
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
        icon: Icons.call_end,
        label: 'End Live',
        color: Colors.red,
        onTap: _endLive,
      ),
    ];
  }

  List<Widget> _viewerControls() {
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
