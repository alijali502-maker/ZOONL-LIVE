import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../event_control_screen.dart';
import '../../streamer_progress_screen.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart'
    show Room, RoomOptions, VideoTrack, VideoTrackRenderer;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart' show VideoPlayer, VideoPlayerController;
import 'package:just_audio/just_audio.dart' show AudioPlayer;

import '../../features/pk_battle_screen.dart';

// Tables used: live_rooms (owner_id, room_name, is_live) and
// chat_messages (room_id, sender_id, message).


class _AudioRoomThemeBackdrop extends StatefulWidget {
  const _AudioRoomThemeBackdrop({required this.themeCode, required this.child});
  final String themeCode;
  final Widget child;

  @override
  State<_AudioRoomThemeBackdrop> createState() => _AudioRoomThemeBackdropState();
}

class _AudioRoomThemeBackdropState extends State<_AudioRoomThemeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  static const Map<String, List<Color>> _palettes = {
    'aurora': [Color(0xFF103C55), Color(0xFF30245C), Color(0xFF071725)],
    'rose_garden': [Color(0xFF762D58), Color(0xFF341C48), Color(0xFF130F2A)],
    'moonlight': [Color(0xFF18365E), Color(0xFF17213F), Color(0xFF080F24)],
    'golden_palace': [Color(0xFF77501E), Color(0xFF3B2549), Color(0xFF160F29)],
    'waterfall': [Color(0xFF126A78), Color(0xFF174A68), Color(0xFF081C35)],
    'ocean_dream': [Color(0xFF075B83), Color(0xFF142F69), Color(0xFF07182F)],
    'sakura': [Color(0xFF8A426D), Color(0xFF57315F), Color(0xFF21162F)],
    'starfall': [Color(0xFF253A73), Color(0xFF30245D), Color(0xFF090F2C)],
    'rainy_window': [Color(0xFF31536D), Color(0xFF26334F), Color(0xFF0C1428)],
    'butterfly': [Color(0xFF315B6D), Color(0xFF62406C), Color(0xFF16182F)],
    'crystal_cave': [Color(0xFF3D5E8B), Color(0xFF563B7C), Color(0xFF101A38)],
    'neon_city': [Color(0xFF3C1B68), Color(0xFF142C61), Color(0xFF090E27)],
    'cloud_dream': [Color(0xFF6582A5), Color(0xFF725A8B), Color(0xFF29234C)],
    'ember_glow': [Color(0xFF87401F), Color(0xFF4C243E), Color(0xFF170F27)],
    'love_lights': [Color(0xFF87365F), Color(0xFF49275F), Color(0xFF180F2D)],
  };

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[widget.themeCode] ?? _palettes['aurora']!;
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
          CustomPaint(
            painter: _AudioThemePainter(
              themeCode: widget.themeCode,
              phase: _motion.value,
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AudioThemePainter extends CustomPainter {
  const _AudioThemePainter({required this.themeCode, required this.phase});
  final String themeCode;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final isWater = themeCode == 'waterfall' || themeCode == 'ocean_dream' ||
        themeCode == 'rainy_window';
    final isWarm = themeCode == 'rose_garden' || themeCode == 'sakura' ||
        themeCode == 'love_lights' || themeCode == 'ember_glow';
    final particleColor = isWater
        ? const Color(0x8878E9F2)
        : isWarm ? const Color(0x99FFC1D9) : const Color(0x99FFE8A6);

    for (var i = 0; i < 34; i++) {
      final seed = i * 37.0;
      final x = ((seed * 13.7) % 100) / 100 * size.width;
      final travel = (phase + (i * 0.071)) % 1.0;
      final y = isWater
          ? ((travel * (size.height + 30)) - 15)
          : (size.height * (1 - travel));
      final drift = math.sin((phase * math.pi * 2) + i) * 13;
      final radius = 1.5 + (i % 4) * 1.1;
      paint.color = particleColor.withOpacity(0.25 + (i % 5) * 0.11);
      canvas.drawCircle(Offset(x + drift, y), radius, paint);
    }

    if (isWater) {
      final wavePaint = Paint()
        ..color = const Color(0x447FE8F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      for (var row = 0; row < 5; row++) {
        final path = Path();
        final baseY = size.height * (0.58 + row * 0.075);
        path.moveTo(0, baseY);
        for (var x = 0.0; x <= size.width; x += 12) {
          final y = baseY + math.sin((x / 42) + phase * math.pi * 2 + row) * 7;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, wavePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AudioThemePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.themeCode != themeCode;
}

class _LiveGiftMedia extends StatefulWidget {
  const _LiveGiftMedia({required this.url, required this.size});
  final String url;
  final double size;

  @override
  State<_LiveGiftMedia> createState() => _LiveGiftMediaState();
}

class _LiveGiftMediaState extends State<_LiveGiftMedia> {
  VideoPlayerController? _controller;
  bool _failed = false;

  bool get _isVideo {
    final path = widget.url.toLowerCase().split('?').first;
    return path.endsWith('.mp4') || path.endsWith('.webm') ||
        path.endsWith('.mov') || path.endsWith('.m4v');
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _LiveGiftMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      if (_isVideo) _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_isVideo && controller != null && controller.value.isInitialized && !_failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }
    if (!_isVideo || _failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.network(widget.url, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Color(0xFFB9AEFF), size: 38)),
      );
    }
    return SizedBox(width: widget.size, height: widget.size,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
  }
}

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
  String _audioThemeCode = 'aurora';
  bool _audioThemeLoading = false;
  List<Map<String, dynamic>> _audioThemeCatalog = <Map<String, dynamic>>[];
  final Set<String> _audioThemeUnlocked = <String>{
    'aurora', 'rose_garden', 'moonlight', 'golden_palace',
  };
  String _previewFilter = 'Natural';
  bool _filterConfirmed = false;
  double _filterStrength = 0.35;
  static const List<String> _previewFilters = <String>['Natural', 'Warm', 'Cool', 'Mono', 'Rose'];

  String? _roomId;
  String? _roomOwnerId;
  String _roomName = '';

  RealtimeChannel? _channel;
  Room? _lk;
  Timer? _guestPoller;
  bool _isGuest = false;
  bool _guestAudioAllowed = true;
  bool _guestVideoAllowed = true;
  bool _guestInviteDialogShown = false;
  String? _guestSeatId;
  List<Map<String, dynamic>> _guestSeats = <Map<String, dynamic>>[];
  bool _privateRoom = false;
  bool _lockedRoom = false;
  bool _giftLoading = false;
  List<Map<String, dynamic>> _giftCatalog = <Map<String, dynamic>>[];
  Map<String, dynamic>? _giftBanner;
  Timer? _giftBannerTimer;
  Timer? _entryBannerTimer;
  String? _entryBannerName;
  String? _entryBannerEffect;
  String? _entryBannerMedia;
  AudioPlayer? _giftAudioPlayer;
  int _hostLevel = 1;
  bool _isTrustedOwner = false;
  bool get _canUsePrivateRooms => _isTrustedOwner || _hostLevel >= 10;

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _messageController =
      TextEditingController();

  final List<Map<String, String>> _messages = [];
  final Set<String> _seenMessageIds = {};
  final Map<String, String> _chatBadges = {};

  String? get _myId => _supabase.auth.currentUser?.id;

  static const List<String> _levelStickers = <String>[
    '🌱 ROOKIE', '💠 RISING', '🦅 FALCON', '🦁 JUNGLE LORD', '🏰 PALACE DUKE',
    '💎 MILLIONAIRE', '🔥 SULTAN FIRE', '👑 ROYAL KING', '💖 HEART EMPEROR', '🏆 SUPREME LEGEND',
  ];

  String get _liveLevelSticker {
    final index = ((_hostLevel - 1) ~/ 10).clamp(0, _levelStickers.length - 1).toInt();
    return _levelStickers[index];
  }

  @override
  void initState() {
    super.initState();
    if (!_isHost) {
      _busy = true;
      _joinAsViewer();
    } else if (_selectedRoomType == 'video') {
      unawaited(_initializePreviewCamera());
    }
    if (_isHost) unawaited(_loadMyLevel());
    if (_isHost) unawaited(_loadAudioThemeCatalog());
    _guestPoller = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshGuestState(),
    );
  }




  Future<void> _loadAudioThemeCatalog() async {
    try {
      final rows = await _supabase.from('audio_room_themes')
          .select('theme_code,theme_name,description,coin_price,sort_order')
          .eq('is_active', true)
          .order('sort_order');
      final userId = _myId;
      final owned = userId == null
          ? <dynamic>[]
          : await _supabase.from('user_audio_room_theme_inventory')
              .select('theme_code').eq('user_id', userId);
      if (!mounted) return;
      setState(() {
        _audioThemeCatalog = List<Map<String, dynamic>>.from(rows);
        for (final row in owned as List) {
          _audioThemeUnlocked.add(row['theme_code'].toString());
        }
      });
    } catch (error) {
      if (mounted) _showMessage('Audio themes could not load: ${_readable(error)}');
    }
  }

  Future<void> _chooseAudioTheme(String code) async {
    Map<String, dynamic>? theme;
    for (final item in _audioThemeCatalog) {
      if (item['theme_code'] == code) {
        theme = item;
        break;
      }
    }
    if (theme == null) {
      _showMessage('This audio theme is not available yet.');
      return;
    }
    final selectedTheme = theme;
    final price = (selectedTheme['coin_price'] as num?)?.toInt() ?? 0;
    if (!_audioThemeUnlocked.contains(code) && price > 0) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF171126),
          title: Text('Unlock ${selectedTheme['theme_name']}',
              style: const TextStyle(color: Color(0xFFE6C47A))),
          content: Text('Unlock this animated audio background for $price coins?',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('UNLOCK')),
          ],
        ),
      );
      if (approved != true) return;
      try {
        await _supabase.rpc('unlock_audio_room_theme',
            params: <String, dynamic>{'p_theme_code': code});
        _audioThemeUnlocked.add(code);
      } catch (error) {
        _showMessage('Theme unlock failed: ${_readable(error)}');
        return;
      }
    }

    final roomId = _roomId;
    final userId = _myId;
    if (_isLive && _isHost && roomId != null && userId != null &&
        _selectedRoomType == 'audio') {
      try {
        final updated = await _supabase.from('live_rooms')
            .update({'audio_theme_code': code})
            .eq('id', roomId)
            .eq('owner_id', userId)
            .select('id')
            .maybeSingle();
        if (updated == null) {
          _showMessage('Theme could not be applied to this room.');
          return;
        }
      } catch (error) {
        _showMessage('Theme update failed: ${_readable(error)}');
        return;
      }
    }
    if (mounted) setState(() => _audioThemeCode = code);
  }

  Future<void> _openAudioThemePicker() async {
    if (_audioThemeCatalog.isEmpty) await _loadAudioThemeCatalog();
    if (!mounted || _audioThemeCatalog.isEmpty) {
      _showMessage('Audio themes are not available right now.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('AUDIO ROOM BACKGROUND THEMES',
                    style: TextStyle(color: Color(0xFFE6C47A),
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Text('4 free themes • More themes unlock with coins',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _audioThemeCatalog.length,
                  itemBuilder: (context, index) {
                    final item = _audioThemeCatalog[index];
                    final code = item['theme_code'].toString();
                    final price = (item['coin_price'] as num?)?.toInt() ?? 0;
                    final owned = price == 0 || _audioThemeUnlocked.contains(code);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF49305E),
                        child: Icon(
                          code == 'waterfall' || code == 'ocean_dream'
                              ? Icons.water
                              : code == 'rose_garden' || code == 'sakura'
                                  ? Icons.local_florist
                                  : code == 'starfall' || code == 'moonlight'
                                      ? Icons.nights_stay
                                      : Icons.auto_awesome,
                          color: const Color(0xFFE6C47A),
                        ),
                      ),
                      title: Text(item['theme_name'].toString(),
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(item['description'].toString(),
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: Text(
                        owned ? (code == _audioThemeCode ? 'ACTIVE' : 'APPLY')
                            : '$price COINS',
                        style: TextStyle(
                          color: owned ? const Color(0xFF77DCCB) : const Color(0xFFE6C47A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _chooseAudioTheme(code);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMyLevel() async {
    final userId = _myId;
    if (userId == null) return;
    try {
      final profile = await _supabase.from('profiles')
          .select('user_level').eq('id', userId).maybeSingle();
      final owner = await _supabase.rpc('is_zoonl_owner') == true;
      if (!mounted) return;
      setState(() {
        _hostLevel = (profile?['user_level'] as num?)?.toInt() ?? 1;
        _isTrustedOwner = owner;
      });
    } catch (_) {}
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
      return ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
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
    if (_selectedRoomType == 'video') {
      if (_previewCamera?.value.isInitialized != true) {
        _showMessage('पहले Camera Preview तैयार होने दें।');
        return;
      }
      if (!_filterConfirmed) {
        _showMessage('पहले Preview Filter चुनें, फिर Live शुरू करें।');
        return;
      }
    }
    if ((_privateRoom || _lockedRoom) && !_canUsePrivateRooms) {
      _showMessage('Private and locked rooms unlock at Level 10.');
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
            'is_private': _privateRoom,
            'is_locked': _lockedRoom || _privateRoom,
            'is_live': true,
            'video_filter_code': _selectedRoomType == 'video' ? _previewFilter : 'Natural',
            'video_filter_strength': _selectedRoomType == 'video' ? _filterStrength : 0.35,
            'audio_theme_code': _selectedRoomType == 'audio' ? _audioThemeCode : 'aurora',
          })
          .select('id')
          .single();

      final roomId = row['id'] as String;
      _roomId = roomId;
      _roomOwnerId = myId;
      final hostProfile = await _supabase.from('profiles')
          .select('user_level').eq('id', myId).maybeSingle();
      _hostLevel = (hostProfile?['user_level'] as num?)?.toInt() ?? 1;

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
          .select('room_name, owner_id, is_live, room_type, is_private, is_locked, video_filter_code, video_filter_strength, audio_theme_code')
          .eq('id', roomId)
          .maybeSingle();

      if (room == null || room['is_live'] != true) {
        _showMessage('यह Live खत्म हो चुका है।');
        return;
      }

      _roomOwnerId = room['owner_id'] as String?;
      _roomName = (room['room_name'] ?? '').toString();
      _audioThemeCode = (room['audio_theme_code'] ?? 'aurora').toString();
      _selectedRoomType = (room['room_type'] ?? 'video').toString().toLowerCase();
      _privateRoom = room['is_private'] == true;
      _lockedRoom = room['is_locked'] == true;
      _previewFilter = _previewFilters.contains(room['video_filter_code']?.toString())
          ? room['video_filter_code'].toString()
          : 'Natural';
      _filterStrength = ((room['video_filter_strength'] as num?)?.toDouble() ?? 0.35)
          .clamp(0.0, 1.0).toDouble();
      _filterConfirmed = true;
      final hostProfile = await _supabase.from('profiles')
          .select('user_level').eq('id', _roomOwnerId!).maybeSingle();
      _hostLevel = (hostProfile?['user_level'] as num?)?.toInt() ?? 1;

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
    _guestAudioAllowed = _isHost || data['audio_enabled'] == true;
    _guestVideoAllowed = _selectedRoomType == 'video' &&
        (_isHost || data['video_enabled'] == true);
    if (_isHost || _isGuest) {
      if (_isGuest && _guestAudioAllowed) {
        final micPermission = await Permission.microphone.request();
        if (!micPermission.isGranted) {
          throw StateError('Microphone permission is required for guest audio.');
        }
      }
      if (_isGuest && _guestVideoAllowed) {
        final cameraPermission = await Permission.camera.request();
        _guestVideoAllowed = cameraPermission.isGranted;
      }
      await room.localParticipant?.setMicrophoneEnabled(
        _guestAudioAllowed && _microphoneEnabled,
      );
      if (_selectedRoomType == 'video') {
        await room.localParticipant?.setCameraEnabled(
          _guestVideoAllowed && _cameraEnabled,
        );
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
      final remote = room.remoteParticipants.values.toList();
      if (_roomOwnerId != null) {
        final host = remote.where((p) => p.identity == _roomOwnerId);
        for (final participant in host) {
          for (final pub in participant.videoTrackPublications) {
            final track = pub.track;
            if (pub.subscribed && track is VideoTrack) return track;
          }
        }
      }
      for (final participant in remote) {
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (pub.subscribed && track is VideoTrack) return track;
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
        backgroundColor: const Color(0xFF141E35),
        title: const Text('Guest Seat Invitation',
            style: TextStyle(color: Color(0xFFB9AEFF))),
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
        if (seatId == null) {
          _guestInviteDialogShown = false;
          _showMessage('Guest invitation expired or the seat is no longer available.');
          return;
        }
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
        _guestInviteDialogShown = false;
        _showMessage('Guest invitation declined.');
      }
    } catch (error) {
      _guestInviteDialogShown = false;
      _showMessage('Guest invitation failed: ${_readable(error)}');
    }
  }

  Future<void> _removeGuestSeat(Map<String, dynamic> seat) async {
    final roomId = _roomId;
    final seatId = seat['id']?.toString();
    final guestId = seat['user_id']?.toString();
    if (roomId == null || seatId == null || guestId == null) return;
    try {
      await _supabase.rpc(
        'room_remove_guest',
        params: <String, dynamic>{'p_seat_id': seatId},
      );
      await _supabase.functions.invoke(
        'livekit-kick-guest',
        body: <String, dynamic>{
          'room_id': roomId,
          'participant_identity': guestId,
        },
      );
      await _refreshGuestState();
      _showMessage('Guest removed from the live room.');
    } catch (error) {
      _showMessage('Guest removal failed: ${_readable(error)}');
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
          backgroundColor: const Color(0xFF141E35),
          title: const Text('Invite Guest', style: TextStyle(color: Color(0xFFB9AEFF))),
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
                dropdownColor: const Color(0xFF141E35),
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
          color: const Color(0xFF1B2844),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB9AEFF), width: 2),
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
    final seat = _guestSeats.firstWhere(
      (item) => item['user_id']?.toString() == participant.identity,
      orElse: () => <String, dynamic>{},
    );
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
        color: const Color(0xFF1B2844),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9AEFF), width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoTrackRenderer(guestTrack),
          if (seat.isNotEmpty)
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: () => _removeGuestSeat(seat),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ),
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
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gift_sends',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => unawaited(_showRemoteGift(payload.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_room_entry_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => unawaited(_showRoomEntry(payload.newRecord)),
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
            final row = payload.newRecord;
            if (!_isHost) {
              if (_selectedRoomType == 'audio') {
                final theme = row['audio_theme_code']?.toString() ?? 'aurora';
                if (mounted) setState(() => _audioThemeCode = theme);
              }
              final code = row['video_filter_code']?.toString() ?? 'Natural';
              final strength = (row['video_filter_strength'] as num?)?.toDouble() ?? 0.35;
              if (mounted && _previewFilters.contains(code)) {
                setState(() {
                  _previewFilter = code;
                  _filterStrength = strength.clamp(0.0, 1.0).toDouble();
                });
              }
              if (row['is_live'] == false) {
                _showMessage('Live खत्म हो गया।');
                _leaveViewer();
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _showRoomEntry(Map<String, dynamic> member) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    try {
      final publicProfile = await _supabase.from('user_public_profiles')
          .select('username,zoonl_id').eq('user_id', userId).maybeSingle();
      final code = member['entry_code']?.toString() ?? '';
      Map<String, dynamic>? effect;
      if (code.isNotEmpty) {
        effect = await _supabase.from('zoonl_live_cosmetics')
            .select('zoonl_item_name,media_url,color_theme_hex')
            .eq('project_name', 'ZOONL LIVE')
            .eq('zoonl_item_code', code)
            .eq('is_active', true)
            .maybeSingle();
      }
      if (!mounted) return;
      _entryBannerTimer?.cancel();
      setState(() {
        _entryBannerName = (publicProfile?['username']?.toString().trim().isNotEmpty == true)
            ? publicProfile!['username'].toString()
            : 'ID ${publicProfile?['zoonl_id'] ?? 'Member'}';
        _entryBannerEffect = effect?['zoonl_item_name']?.toString() ?? 'Standard Entry';
        _entryBannerMedia = effect?['media_url']?.toString();
      });
      _entryBannerTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _entryBannerName = null;
          _entryBannerEffect = null;
          _entryBannerMedia = null;
        });
      });
    } catch (_) {
      // A failed cosmetic lookup must never interrupt room entry or gifting.
    }
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
    final senderId = row['sender_id']?.toString() ?? '';
    if (senderId.isNotEmpty) unawaited(_loadChatBadge(senderId));

    setState(() {
      _messages.add({
        'sender_id': senderId,
        'name': _nameFor(senderId),
        'message': (row['message'] ?? '').toString(),
        'badge': _chatBadges[senderId] ?? 'NONE',
      });
    });
  }

  Future<void> _loadChatBadge(String senderId) async {
    if (senderId.isEmpty || _chatBadges.containsKey(senderId)) return;
    _chatBadges[senderId] = 'LOADING';
    try {
      final result = await _supabase.rpc(
        'get_public_chat_badges',
        params: <String, dynamic>{'p_user_ids': <String>[senderId]},
      );
      final rows = result is List ? result : const [];
      var badge = 'NONE';
      if (rows.isNotEmpty && rows.first is Map) {
        badge = (rows.first['badge_code'] ?? 'NONE').toString();
      }
      if (!mounted) return;
      setState(() {
        _chatBadges[senderId] = badge;
        for (final item in _messages) {
          if (item['sender_id'] == senderId) item['badge'] = badge;
        }
      });
    } catch (_) {
      _chatBadges[senderId] = 'NONE';
    }
  }

  Widget _buildChatLine(Map<String, String> item) {
    final badge = item['badge'] ?? 'NONE';
    final badgeColor = badge == 'SVIP'
        ? const Color(0xFFE04455)
        : const Color(0xFFD6B46A);
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        children: [
          TextSpan(
            text: item['name'] ?? 'User',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (badge == 'VIP' || badge == 'SVIP')
            TextSpan(
              text: ' [$badge]',
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900),
            ),
          TextSpan(text: ': ${item['message'] ?? ''}'),
        ],
      ),
    );
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

  Future<void> _openPkBattle() async {
    if (!_isHost || !_isLive) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PkBattleScreen(
          currentUserName: widget.userName,
          currentUserId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _showPrivacySettings() async {
    if (!_isHost || _roomId == null) return;
    var privateValue = _privateRoom;
    var lockedValue = _lockedRoom;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141E35),
          title: const Text('Live Privacy Settings', style: TextStyle(color: Color(0xFFB9AEFF))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Private Room', style: TextStyle(color: Colors.white)),
              value: privateValue, onChanged: !_canUsePrivateRooms ? null : (v) => setDialogState(() { privateValue = v; if (v) lockedValue = true; })),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Lock Room', style: TextStyle(color: Colors.white)),
              value: lockedValue, onChanged: !_canUsePrivateRooms ? null : (v) => setDialogState(() => lockedValue = v)),
            const Text('Only invited members or approved guest seats can enter a private or locked room.',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await _supabase.from('live_rooms').update({
        'is_private': privateValue, 'is_locked': lockedValue || privateValue,
      }).eq('id', _roomId!).eq('owner_id', _myId!);
      if (!mounted) return;
      setState(() { _privateRoom = privateValue; _lockedRoom = lockedValue || privateValue; });
      _showMessage('Room privacy updated.');
    } catch (error) {
      _showMessage('Privacy update failed: ${_readable(error)}');
    }
  }

  Future<void> _showPrivateRoomInvite() async {
    if (!_isHost || _roomId == null) return;
    final controller = TextEditingController();
    final zoonlId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141E35),
        title: const Text('Invite by ZOONL ID', style: TextStyle(color: Color(0xFFB9AEFF))),
        content: TextField(controller: controller, keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Member ZOONL ID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Send Invite')),
        ],
      ),
    );
    controller.dispose();
    if (zoonlId == null || zoonlId.isEmpty) return;
    try {
      await _supabase.rpc('private_room_invite_by_zoonl_id', params: {
        'p_room_id': _roomId, 'p_target_zoonl_id': zoonlId,
      });
      _showMessage('Private room invitation sent.');
    } catch (error) {
      _showMessage('Invite failed: ${_readable(error)}');
    }
  }

  Future<List<Map<String, dynamic>>> _loadLiveGifts() async {
    final rows = await _supabase.from('gifts')
      .select('id, gift_name, image_url, animation_url, animation_3d_url, sound_url, preview_url, coin_price, diamond_value, category')
      .eq('is_active', true).order('coin_price', ascending: true);
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _openGiftPanel() async {
    final roomId = _roomId;
    if (roomId == null || !_isLive || _giftLoading) return;
    setState(() => _giftLoading = true);
    try {
      _giftCatalog = await _loadLiveGifts();
    } catch (error) {
      if (mounted) { setState(() => _giftLoading = false); _showMessage('Gift catalogue could not load: ${_readable(error)}'); }
      return;
    }
    if (!mounted) return;
    setState(() => _giftLoading = false);
    var eventRows = <Map<String, dynamic>>[];
    try {
      final rows = await _supabase
          .from('live_events')
          .select('id,title,description,event_type,starts_at,ends_at,status')
          .inFilter('status', ['upcoming', 'active'])
          .gte('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('starts_at', ascending: true)
          .limit(5);
      eventRows = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      // Event discovery is independent from the gift transaction flow.
    }
    var category = 'ALL';
    var quantity = 1;
    var sending = false;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0D1426),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = <String>{'ALL', ..._giftCatalog.map((g) => (g['category'] ?? 'General').toString().trim()).where((v) => v.isNotEmpty)};
          final visible = category == 'ALL' ? _giftCatalog : _giftCatalog.where((g) => (g['category'] ?? 'General').toString() == category).toList();
          return SafeArea(child: SizedBox(
            height: MediaQuery.of(context).size.height * .78,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                const Expanded(child: Text('ALL LIVE GIFTS', style: TextStyle(color: Color(0xFFB9AEFF), fontWeight: FontWeight.w900, fontSize: 17))),
                if (_isTrustedOwner)
                  TextButton.icon(
                    onPressed: () => Navigator.of(sheetContext).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const EventControlScreen()),
                    ),
                    icon: const Icon(Icons.event_available, size: 16),
                    label: const Text('EVENTS'),
                  ),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close, color: Colors.white)),
              ])),
              if (eventRows.isNotEmpty)
                SizedBox(
                  height: 82,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: eventRows.map((event) => Container(
                      width: 230,
                      margin: const EdgeInsets.only(right: 8, bottom: 7),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF29365E), Color(0xFF17243D)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8F7BFF).withOpacity(.55)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${event['event_type'].toString().toUpperCase()} • ${event['status'].toString().toUpperCase()}',
                            style: const TextStyle(color: Color(0xFFB9AEFF), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                          Expanded(child: Text(event['description']?.toString() ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 10))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              if (_isHost)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text('Host view: catalogue preview only. Viewers send gifts to the host.',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                ),
              SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: categories.map((c) =>
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(
                  label: Text(c), selected: category == c, onSelected: (_) => setSheetState(() => category = c),
                ))).toList())),
              Expanded(child: visible.isEmpty
                ? const Center(child: Text('No active gifts in this category.', style: TextStyle(color: Colors.white70)))
                : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .78),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final gift = visible[index];
                    final imageUrl = (gift['image_url'] ?? gift['preview_url'] ?? '').toString();
                    final animation3d = (gift['animation_3d_url'] ?? '').toString().trim();
                    final animation = (gift['animation_url'] ?? '').toString().trim();
                    final mediaUrl = animation3d.isNotEmpty ? animation3d : animation.isNotEmpty ? animation : imageUrl;
                    return InkWell(
                      onTap: sending || _isHost ? null : () async {
                        setSheetState(() => sending = true);
                        try {
                          final response = await _supabase.rpc('send_live_gift', params: {
                            'p_gift_id': gift['id'], 'p_room_id': roomId, 'p_quantity': quantity,
                          });
                          final result = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
                          _setGiftBanner({
                            'gift_name': gift['gift_name'], 'image_url': imageUrl,
                            'media_url': mediaUrl, 'sound_url': gift['sound_url'],
                            'sender_name': widget.userName, 'quantity': quantity,
                            'total_coins': result['total_coins'] ?? ((gift['coin_price'] as num? ?? 0) * quantity),
                          });
                          if (mounted) _showMessage('Gift sent: ${gift['gift_name']} ×$quantity');
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        } catch (error) {
                          if (mounted) _showMessage('Gift not sent: ${_readable(error)}');
                          setSheetState(() => sending = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF141E35), borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFFB9AEFF).withOpacity(.28))),
                        child: Column(children: [
                          Expanded(child: imageUrl.isEmpty
                            ? const Icon(Icons.card_giftcard, size: 42, color: Color(0xFFB9AEFF))
                            : Image.network(imageUrl, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 42, color: Color(0xFFB9AEFF)))),
                          Text((gift['gift_name'] ?? 'Gift').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text('${gift['coin_price'] ?? 0} coins', style: const TextStyle(color: Color(0xFFB9AEFF), fontSize: 10)),
                        ]),
                      ),
                    );
                  },
                )),
              Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 12), child: Row(children: [
                const Text('Quantity', style: TextStyle(color: Colors.white)),
                IconButton(onPressed: quantity > 1 ? () => setSheetState(() => quantity--) : null, icon: const Icon(Icons.remove_circle_outline, color: Colors.white)),
                Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(onPressed: quantity < 99 ? () => setSheetState(() => quantity++) : null, icon: const Icon(Icons.add_circle_outline, color: Colors.white)),
                const Spacer(), if (sending) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ])),
            ]),
          ));
        },
      ),
    );
  }

  void _setGiftBanner(Map<String, dynamic> data) {
    _giftBannerTimer?.cancel();
    _entryBannerTimer?.cancel();
    if (!mounted) return;
    setState(() => _giftBanner = data);
    _giftBannerTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _giftBanner = null);
    });
  }

  Future<void> _showRemoteGift(Map<String, dynamic> row) async {
    try {
      final gift = await _supabase.from('gifts').select('gift_name,image_url,animation_url,animation_3d_url,sound_url,coin_price').eq('id', row['gift_id']).maybeSingle();
      final sender = await _supabase.from('profiles').select('display_name').eq('id', row['sender_id']).maybeSingle();
      if (!mounted || gift == null) return;
      _playGiftSound((gift['sound_url'] ?? '').toString());
      _setGiftBanner({
        'gift_name': gift['gift_name'], 'image_url': gift['image_url'],
        'media_url': ((gift['animation_3d_url'] ?? '').toString().trim().isNotEmpty ? gift['animation_3d_url'] : ((gift['animation_url'] ?? '').toString().trim().isNotEmpty ? gift['animation_url'] : gift['image_url'])),
        'sound_url': gift['sound_url'],
        'sender_name': sender?['display_name'] ?? 'Viewer', 'quantity': row['quantity'] ?? 1,
        'total_coins': row['total_coins'] ?? gift['coin_price'] ?? 0,
      });
    } catch (_) {}
  }


  Future<void> _playGiftSound(String url) async {
    if (url.trim().isEmpty) return;
    final previous = _giftAudioPlayer;
    _giftAudioPlayer = null;
    if (previous != null) await previous.dispose();
    final player = AudioPlayer();
    _giftAudioPlayer = player;
    try {
      await player.setUrl(url);
      await player.play();
    } catch (_) {}
  }

  Widget _liveGiftBanner() {
    final gift = _giftBanner ?? <String, dynamic>{};
    final image = (gift['media_url'] ?? gift['image_url'] ?? '').toString();
    final screen = MediaQuery.of(context).size;
    final mediaSize = math.min(screen.width * 0.82, screen.height * 0.52)
        .clamp(150.0, 360.0).toDouble();
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 240),
        child: Container(
          color: const Color(0xCC080510),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF302047), Color(0xFF171126), Color(0xFF100B1D)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE6C47A), width: 1.4),
                boxShadow: const [
                  BoxShadow(color: Color(0x669360F5), blurRadius: 34, spreadRadius: 3),
                  BoxShadow(color: Color(0x55E6C47A), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('GIFT ARRIVED',
                    style: TextStyle(color: Color(0xFFE6C47A), fontSize: 12,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  if (image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _LiveGiftMedia(url: image, size: mediaSize),
                    )
                  else
                    SizedBox(width: mediaSize, height: mediaSize,
                      child: const Icon(Icons.card_giftcard, color: Color(0xFFE6C47A), size: 100)),
                  const SizedBox(height: 14),
                  Text((gift['gift_name'] ?? 'Live Gift').toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${gift['sender_name'] ?? 'Viewer'}  •  ×${gift['quantity'] ?? 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD9C9EC), fontSize: 13,
                      fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Future<void> _openLiveFilterSettings() async {
    final roomId = _roomId;
    final userId = _myId;
    if (!_isHost || !_isLive || roomId == null || userId == null ||
        _selectedRoomType != 'video') return;

    var selected = _previewFilter;
    var strength = _filterStrength;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LIVE VIDEO FILTER',
                  style: TextStyle(color: Color(0xFFB9AEFF), fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _previewFilters.map((filter) => ChoiceChip(
                    label: Text(filter),
                    selected: selected == filter,
                    onSelected: saving ? null : (_) => setSheetState(() => selected = filter),
                  )).toList(),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Intensity', style: TextStyle(color: Colors.white70)),
                  Expanded(child: Slider(
                    value: strength,
                    min: 0,
                    max: 1,
                    onChanged: saving ? null : (value) => setSheetState(() => strength = value),
                  )),
                  Text('${(strength * 100).round()}%', style: const TextStyle(color: Colors.white)),
                ]),
                const Text(
                  'This colour effect is synchronized to ZOONL LIVE viewers. It changes the in-app video display, not the original camera source.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : () async {
                      setSheetState(() => saving = true);
                      try {
                        final updated = await _supabase.from('live_rooms')
                          .update({
                            'video_filter_code': selected,
                            'video_filter_strength': strength,
                          })
                          .eq('id', roomId)
                          .eq('owner_id', userId)
                          .select('id')
                          .maybeSingle();
                        if (updated == null) {
                          throw StateError('Room filter could not be saved. Check live-room update permission.');
                        }
                        if (mounted) {
                          setState(() {
                            _previewFilter = selected;
                            _filterStrength = strength;
                            _filterConfirmed = true;
                          });
                        }
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        _showMessage('Filter updated for viewers.');
                      } catch (error) {
                        setSheetState(() => saving = false);
                        _showMessage('Filter update failed: ${_readable(error)}');
                      }
                    },
                    child: Text(saving ? 'SAVING...' : 'APPLY TO LIVE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    _giftBannerTimer?.cancel();
    final giftAudio = _giftAudioPlayer;
    _giftAudioPlayer = null;
    if (giftAudio != null) unawaited(giftAudio.dispose());
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
        child: CircularProgressIndicator(color: Color(0xFFB9AEFF)),
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
            color: Color(0xFFB9AEFF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: body),
            if (_entryBannerName != null)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Container(
                      key: ValueKey('$_entryBannerName-$_entryBannerEffect'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF273B70), Color(0xFF39235D), Color(0xFF173F4A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8CEBFF), width: 1.2),
                        boxShadow: [BoxShadow(color: const Color(0xFF8CEBFF).withOpacity(.16), blurRadius: 18)],
                      ),
                      child: Row(children: [
                        if ((_entryBannerMedia ?? '').startsWith('https://'))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(_entryBannerMedia!, width: 42, height: 42, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: Color(0xFF8CEBFF), size: 30)),
                          )
                        else
                          const Icon(Icons.auto_awesome, color: Color(0xFF8CEBFF), size: 30),
                        const SizedBox(width: 11),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$_entryBannerName ENTERED THE ROOM',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .6)),
                          const SizedBox(height: 3),
                          Text(_entryBannerEffect ?? 'Standard Entry',
                            style: const TextStyle(color: Color(0xFF8CEBFF), fontSize: 12, fontWeight: FontWeight.w800)),
                        ])),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildCameraPreviewPanel() {
    final camera = _previewCamera;
    return Container(
      height: 330,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2844),
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
                      size: 58, color: const Color(0xFFB9AEFF)),
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
                  color: Color(0xFFB9AEFF),
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
                    : (_) => setState(() {
                        _previewFilter = filter;
                        _filterConfirmed = true;
                      }),
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
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF171D36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _filterConfirmed ? const Color(0xFF58D6CE) : const Color(0xFF9360F5)),
            ),
            child: Row(children: [
              Icon(_filterConfirmed ? Icons.check_circle : Icons.tune,
                color: _filterConfirmed ? const Color(0xFF58D6CE) : const Color(0xFFB9AEFF), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _filterConfirmed
                  ? '$_previewFilter is saved on this room and rendered for everyone using ZOONL LIVE. It is a display-side colour effect, not baked into the source video. Face retouch still needs a dedicated video-effects engine.'
                  : 'Choose one filter above before starting the video room.',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              )),
            ]),
          ),
        ] else ...[
          SizedBox(
            height: 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _AudioRoomThemeBackdrop(
                themeCode: _audioThemeCode,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.headphones, size: 72, color: Colors.white),
                      SizedBox(height: 10),
                      Text('AUDIO LIVE READY',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openAudioThemePicker,
            icon: const Icon(Icons.wallpaper),
            label: const Text('CHOOSE AUDIO BACKGROUND'),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Start Your Live Room',
            style: TextStyle(
                color: Color(0xFFB9AEFF),
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
            fillColor: const Color(0xFF141E35),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF141E35), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ROOM PRIVACY SETTINGS', style: TextStyle(color: Color(0xFFB9AEFF), fontWeight: FontWeight.bold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private Room', style: TextStyle(color: Colors.white)),
              subtitle: Text(_canUsePrivateRooms ? 'Only invited members and approved guest seats can enter.' : 'Unlocks at Level 10. Current level: $_hostLevel.', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              value: _privateRoom,
              activeColor: const Color(0xFFB9AEFF),
              onChanged: _busy || !_canUsePrivateRooms ? null : (v) => setState(() { _privateRoom = v; if (v) _lockedRoom = true; }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lock Room', style: TextStyle(color: Colors.white)),
              value: _lockedRoom,
              activeColor: const Color(0xFFB9AEFF),
              onChanged: _busy || !_canUsePrivateRooms ? null : (v) => setState(() => _lockedRoom = v),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Room Type',
            style: TextStyle(
                color: Color(0xFFB9AEFF), fontWeight: FontWeight.bold)),
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
              color: const Color(0xFF141E35),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.person, color: Color(0xFFB9AEFF)),
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
            onPressed: _busy || (_selectedRoomType == 'video' &&
                (!_filterConfirmed || _previewCamera?.value.isInitialized != true))
                ? null : _startLive,
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
      return ColorFiltered(
        colorFilter: _selectedPreviewColorFilter,
        child: VideoTrackRenderer(track),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 110, color: Color(0xFFB9AEFF)),
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
                color: const Color(0xFF1B2844),
                child: _selectedRoomType == 'audio'
                    ? _AudioRoomThemeBackdrop(
                        themeCode: _audioThemeCode,
                        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.headphones, size: 100, color: Colors.white),
                          SizedBox(height: 12),
                          Text('AUDIO LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                        ])),
                      )
                    : _videoLayer(),
              ),
              if (_giftBanner != null)
                Positioned.fill(child: _liveGiftBanner()),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF542CA0), Color(0xFF211735)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6C47A), width: 1),
                    boxShadow: const [BoxShadow(color: Color(0x559360F5), blurRadius: 14)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE6C47A), Color(0xFF9360F5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white70, width: 1),
                          boxShadow: const [
                            BoxShadow(color: Color(0x669360F5), blurRadius: 9),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$_hostLevel',
                            style: const TextStyle(
                              color: Color(0xFF160F22),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _privateRoom || _lockedRoom ? 'PRIVATE LIVE' : 'LIVE NOW',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                          Text(
                            '$_liveLevelSticker  •  LEVEL $_hostLevel',
                            style: const TextStyle(
                              color: Color(0xFFE6C47A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
                        child: _buildChatLine(item),
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
                        color: Color(0xFFB9AEFF),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _isHost ? _hostControls() : _viewerControls()),
          ),
        ),
      ],
    );
  }

  List<Widget> _hostControls() {
    return [
      if (_selectedRoomType == 'audio')
        _control(icon: Icons.wallpaper, label: 'Theme', onTap: _openAudioThemePicker),
      if (_selectedRoomType == 'video')
        _control(icon: Icons.auto_awesome, label: 'Filter', onTap: _openLiveFilterSettings),
      _control(icon: Icons.card_giftcard, label: 'Gifts', onTap: _openGiftPanel),
      _control(
        icon: Icons.stars,
        label: 'Stars & History',
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const StreamerProgressScreen(),
          ),
        ),
      ),
      _control(icon: Icons.sports_mma, label: 'PK Battle', onTap: _openPkBattle),
      _control(icon: _privateRoom || _lockedRoom ? Icons.lock : Icons.lock_open,
          label: 'Privacy', onTap: _showPrivacySettings),
      _control(icon: Icons.person_add_alt_1, label: 'Invite', onTap: _showPrivateRoomInvite),
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
        _control(icon: Icons.card_giftcard, label: 'Gifts', onTap: _openGiftPanel),
        _control(
          icon: Icons.chat,
          label: 'Chat',
          onTap: () => setState(() => _chatEnabled = !_chatEnabled),
        ),
        if (_guestAudioAllowed)
          _control(
          icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
          label: 'Mic',
          onTap: _toggleMicrophone,
        ),
        if (_selectedRoomType == 'video' && _guestVideoAllowed)
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
      _control(icon: Icons.card_giftcard, label: 'Gifts', onTap: _openGiftPanel),
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
