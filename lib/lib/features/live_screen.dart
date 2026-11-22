import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../camera_studio/zoonl_beauty_track_processor.dart';
import '../../event_control_screen.dart';
import '../../streamer_progress_screen.dart';
import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart'
    show Room, RoomOptions, VideoTrack, VideoTrackRenderer, LocalVideoTrack, LocalVideoTrackExt, CameraPosition, CameraCaptureOptions;
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
  bool _frontLiveCamera = true;
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
  static const List<String> _previewFilters = <String>['Natural', 'Soft Glow', 'Vivid', 'Cinema', 'Warm', 'Sunset', 'Cool', 'Ice', 'Rose', 'Peach', 'Mint', 'Lavender', 'Mono'];

  String? _roomId;
  String? _roomOwnerId;
  String _roomName = '';

  RealtimeChannel? _channel;
  Room? _lk;
  ZoonlBeautyTrackProcessor? _liveBeautyProcessor;
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
  int _hostStarDailyCoins = 0;
  int _hostStarCount = 0;
  List<Map<String, dynamic>> _viewerPreviewProfiles = <Map<String, dynamic>>[];
  bool _loadingViewerPreview = false;
  static const List<int> _starThresholds = <int>[10000, 50000, 300000, 600000, 1000000];
  static const List<Color> _starColors = <Color>[Color(0xFF42C7FF), Color(0xFF56E39B), Color(0xFFB68AFF), Color(0xFFFF6F75), Color(0xFFFFD66E)];
  String _hostDisplayName = '';
  String _hostZoonlId = '';
  String? _hostAvatarUrl;
  bool _isTrustedOwner = false;
  bool get _canUsePrivateRooms => _isTrustedOwner || _hostLevel >= 10;

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _messageController =
      TextEditingController();

  final List<Map<String, String>> _messages = [];
  final Set<String> _seenMessageIds = {};
  final Map<String, String> _chatBadges = {};
  final Map<String, int> _chatLevels = {};
  final Map<String, String> _chatNames = {};
  final Map<String, String> _chatAvatars = {};
  final Map<String, String> _chatTiers = {};
  final Map<String, String> _chatColorHex = {};
  final Map<String, String> _chatFrameMedia = {};
  bool _canModerateChat = false;

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
    unawaited(_loadChatModerationAccess());
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
      backgroundColor: const Color(0xFF080808),
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

  Future<void> _loadHostStarProgress(String userId) async {
    try {
      final row = await _supabase.from('streamer_gifting_summary').select('daily_coins').eq('streamer_id', userId).maybeSingle();
      final coins = (row?['daily_coins'] as num?)?.toInt() ?? 0;
      var stars = 0;
      for (final target in _starThresholds) { if (coins >= target) { stars++; } else { break; } }
      if (!mounted) return;
      setState(() { _hostStarDailyCoins = coins; _hostStarCount = stars; });
    } catch (_) { if (mounted) setState(() { _hostStarDailyCoins = 0; _hostStarCount = 0; }); }
  }

  Widget _hostStarStrip() {
    final stars = _hostStarCount.clamp(0, 5);
    final next = stars >= 5 ? _starThresholds.last : _starThresholds[stars];
    final previous = stars == 0 ? 0 : _starThresholds[stars - 1];
    final progress = stars >= 5 ? 1.0 : ((_hostStarDailyCoins - previous) / (next - previous)).clamp(0.0, 1.0).toDouble();
    final color = stars == 0 ? const Color(0xFF9AA6B8) : _starColors[stars - 1];
    final label = stars == 0 ? '0 STAR' : '$stars STAR';
    return Container(
      width: 238,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xF5101728), color.withOpacity(.34), const Color(0xF50A1020)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.9), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(.28), blurRadius: 16), const BoxShadow(color: Colors.black54, blurRadius: 7, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 43, height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color.withOpacity(.95), const Color(0xFF172033), color.withOpacity(.65)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white.withOpacity(.72), width: 1.1),
            boxShadow: [BoxShadow(color: color.withOpacity(.55), blurRadius: 12)],
          ),
          child: Center(child: Text('$stars', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 2))]))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8)), const Spacer(), Text(' / 5', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(color))),
          const SizedBox(height: 4),
          Text(stars >= 5 ? 'Daily star target completed' : '$_hostStarDailyCoins / $next coins today', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 8)),
        ])),
      ]),
    );
  }

  Future<void> _loadHostIdentity(String userId) async {
    try {
      final profile = await _supabase.from('profiles')
          .select('display_name,avatar_url').eq('id', userId).maybeSingle();
      final publicProfile = await _supabase.from('user_public_profiles')
          .select('zoonl_id').eq('user_id', userId).maybeSingle();
      if (!mounted) return;
      setState(() {
        _hostDisplayName = (profile?['display_name'] ?? widget.userName).toString();
        _hostAvatarUrl = profile?['avatar_url']?.toString();
        _hostZoonlId = (publicProfile?['zoonl_id'] ?? widget.userId).toString();
      });
      unawaited(_loadHostStarProgress(userId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hostDisplayName = widget.userName;
        _hostZoonlId = widget.userId;
      });
    }
  }

  Widget _hostIdentityGlass() {
    final name = _hostDisplayName.isEmpty ? widget.userName : _hostDisplayName;
    final zoonlId = _hostZoonlId.isEmpty ? widget.userId : _hostZoonlId;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 270),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xAA050505),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x77FFFFFF)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: ClipOval(
                child: (_hostAvatarUrl ?? '').trim().isNotEmpty
                    ? Image.network(_hostAvatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF242424),
                          child: Icon(Icons.person, color: Colors.white, size: 27),
                        ))
                    : const ColoredBox(
                        color: Color(0xFF242424),
                        child: Icon(Icons.person, color: Colors.white, size: 27),
                      ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('ID $zoonlId', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Color(0xFFFF4545), size: 7),
                  SizedBox(width: 4),
                  Text('LIVE NOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                ]),
              ],
            )),
          ]),
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
    const identity = <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final strength = _filterStrength.clamp(0.0, 1.0);
    if (_previewFilter == 'Natural' || strength == 0) {
      return const ColorFilter.matrix(identity);
    }

    // Real per-channel tone, contrast and saturation transforms. These are
    // rendered over the published LiveKit track for host and viewers.
    final presets = <String, ({double saturation, double contrast, double brightness, double red, double green, double blue})>{
      'Soft Glow': (saturation: .92, contrast: .96, brightness: 9, red: 3, green: 2, blue: 0),
      'Vivid': (saturation: 1.34, contrast: 1.12, brightness: 1, red: 0, green: 0, blue: 0),
      'Cinema': (saturation: .86, contrast: 1.20, brightness: -5, red: 3, green: 1, blue: 7),
      'Warm': (saturation: 1.08, contrast: 1.05, brightness: 3, red: 8, green: 2, blue: -8),
      'Sunset': (saturation: 1.18, contrast: 1.10, brightness: 2, red: 12, green: 0, blue: -10),
      'Cool': (saturation: 1.04, contrast: 1.06, brightness: 2, red: -5, green: 1, blue: 9),
      'Ice': (saturation: .92, contrast: 1.12, brightness: 7, red: -5, green: 2, blue: 12),
      'Rose': (saturation: 1.12, contrast: 1.04, brightness: 3, red: 9, green: -3, blue: 3),
      'Peach': (saturation: 1.05, contrast: 1.02, brightness: 7, red: 10, green: 3, blue: -4),
      'Mint': (saturation: 1.08, contrast: 1.06, brightness: 3, red: -4, green: 8, blue: 3),
      'Lavender': (saturation: .98, contrast: 1.08, brightness: 4, red: 5, green: 0, blue: 10),
      'Mono': (saturation: 0, contrast: 1.08, brightness: 0, red: 0, green: 0, blue: 0),
    };
    final preset = presets[_previewFilter];
    if (preset == null) return const ColorFilter.matrix(identity);

    const lr = .2126;
    const lg = .7152;
    const lb = .0722;
    final sat = preset.saturation;
    final contrast = 1 + (preset.contrast - 1) * strength;
    final saturation = 1 + (sat - 1) * strength;
    final red = (preset.red * strength) + 128 * (1 - contrast);
    final green = (preset.green * strength) + 128 * (1 - contrast);
    final blue = (preset.blue * strength) + 128 * (1 - contrast);
    final matrix = <double>[
      (lr * (1 - saturation) + saturation) * contrast,
      (lg * (1 - saturation)) * contrast,
      (lb * (1 - saturation)) * contrast, 0,
      red + preset.brightness * strength,
      (lr * (1 - saturation)) * contrast,
      (lg * (1 - saturation) + saturation) * contrast,
      (lb * (1 - saturation)) * contrast, 0,
      green + preset.brightness * strength,
      (lr * (1 - saturation)) * contrast,
      (lg * (1 - saturation)) * contrast,
      (lb * (1 - saturation) + saturation) * contrast, 0,
      blue + preset.brightness * strength,
      0, 0, 0, 1, 0,
    ];
    return ColorFilter.matrix(matrix);
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
      unawaited(_loadHostIdentity(myId));
      final hostProfile = await _supabase.from('profiles')
          .select('user_level').eq('id', myId).maybeSingle();
      _hostLevel = (hostProfile?['user_level'] as num?)?.toInt() ?? 1;
      unawaited(_loadHostStarProgress(myId));

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
      if (_roomOwnerId != null) unawaited(_loadHostIdentity(_roomOwnerId!));
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
      // Announce this authenticated viewer using their server-owned equipped entry.
      unawaited(_supabase.rpc('zoonl_emit_room_entry', params: <String, dynamic>{'p_room_id': roomId})
          .then((_) {}).catchError((_) {}));
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

  ZoonlBeautyTrackProcessor _createLiveBeautyProcessor() {
    final look = _previewFilter;
    final strength = _filterStrength;
    return ZoonlBeautyTrackProcessor(
      look: look,
      intensity: strength,
      smoothing: look == 'Soft Glow' ? 0.42 : 0.12 + (strength * 0.12),
      glow: look == 'Soft Glow'
          ? 0.38
          : look == 'Natural'
              ? 0.08
              : 0.16 * strength,
      brightness: look == 'Cinema'
          ? -0.035
          : look == 'Peach' || look == 'Sunset'
              ? 0.025
              : 0.0,
      warmth: look == 'Warm' || look == 'Sunset' || look == 'Peach'
          ? 0.22 * strength
          : look == 'Cool' || look == 'Ice'
              ? -0.18 * strength
              : 0.0,
    );
  }

  Future<void> _updateLiveBeautyProcessor({
    required String look,
    required double strength,
  }) async {
    await _liveBeautyProcessor?.update(
      look: look,
      intensity: strength,
      smoothing: look == 'Soft Glow' ? 0.42 : 0.12 + (strength * 0.12),
      glow: look == 'Soft Glow'
          ? 0.38
          : look == 'Natural'
              ? 0.08
              : 0.16 * strength,
      brightness: look == 'Cinema'
          ? -0.035
          : look == 'Peach' || look == 'Sunset'
              ? 0.025
              : 0.0,
      warmth: look == 'Warm' || look == 'Sunset' || look == 'Peach'
          ? 0.22 * strength
          : look == 'Cool' || look == 'Ice'
              ? -0.18 * strength
              : 0.0,
    );
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
        final beautyProcessor = _createLiveBeautyProcessor();
        _liveBeautyProcessor = beautyProcessor;
        await room.localParticipant?.setCameraEnabled(
          _guestVideoAllowed && _cameraEnabled,
          cameraCaptureOptions: CameraCaptureOptions(
            cameraPosition: _frontLiveCamera
                ? CameraPosition.front
                : CameraPosition.back,
            maxFrameRate: 24,
            processor: beautyProcessor,
          ),
        );
      }
    }
  }

  Future<void> _refreshViewerPreview() async {
    final room = _lk;
    if (room == null || _loadingViewerPreview) return;
    final ids = room.remoteParticipants.values.where((p) => _isHost || p.identity != _roomOwnerId)
      .map((p) => p.identity).where((id) => id.isNotEmpty).take(40).toList();
    if (ids.isEmpty) { if (mounted && _viewerPreviewProfiles.isNotEmpty) setState(() => _viewerPreviewProfiles = []); return; }
    _loadingViewerPreview = true;
    try {
      final rows = await _supabase.from('profiles').select('id,display_name,avatar_url').inFilter('id', ids);
      final byId = <String, Map<String, dynamic>>{for (final row in rows) row['id'].toString(): Map<String, dynamic>.from(row)};
      final next = ids.map((id) => byId[id] ?? <String, dynamic>{'id':id,'display_name':'Viewer','avatar_url':null}).toList();
      if (mounted) setState(() => _viewerPreviewProfiles = next);
    } catch (_) {
      if (mounted) setState(() => _viewerPreviewProfiles = ids.map((id) => <String,dynamic>{'id':id,'display_name':'Viewer'}).toList());
    } finally { _loadingViewerPreview = false; }
  }

  Widget _viewerPreviewStrip(int viewers) {
    final preview = _viewerPreviewProfiles.take(4).toList();
    return Material(color: Colors.transparent, child: InkWell(onTap: _showLiveViewerList, borderRadius: BorderRadius.circular(22),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xAA050505), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x77FFFFFF))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility, color: Colors.white, size: 15), const SizedBox(width: 5),
          Text('$viewers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(width: 5),
          ...preview.map((p) { final url=(p['avatar_url']??'').toString(); return Container(width:29,height:29,margin:const EdgeInsets.only(right:3),
            decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0xFFE6C47A))),
            child:ClipOval(child:url.isEmpty?const ColoredBox(color:Color(0xFF29243A),child:Icon(Icons.person,color:Colors.white70,size:17))
              :Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.person,color:Colors.white70,size:17)))); }),
          if (viewers > 4) const Text('+', style: TextStyle(color: Colors.white70, fontSize: 9)),
          const Icon(Icons.chevron_right, color: Colors.white70, size: 15),
        ]))));
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
    unawaited(_refreshViewerPreview());
  }

  Future<void> _showLiveViewerList() async {
    final room = _lk;
    if (room == null || !mounted) return;
    final participants = room.remoteParticipants.values.where((p) =>
      _isHost || p.identity != _roomOwnerId
    ).toList();
    final ids = participants.map((p) => p.identity).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) {
      _showMessage('अभी कोई viewer नहीं है।');
      return;
    }
    try {
      final profiles = await _supabase.from('profiles')
          .select('id,display_name,avatar_url').inFilter('id', ids);
      final publicProfiles = await _supabase.from('user_public_profiles')
          .select('user_id,zoonl_id').inFilter('user_id', ids);
      final profileById = <String, Map<String, dynamic>>{
        for (final row in profiles) row['id'].toString(): Map<String, dynamic>.from(row),
      };
      final publicById = <String, Map<String, dynamic>>{
        for (final row in publicProfiles) row['user_id'].toString(): Map<String, dynamic>.from(row),
      };
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF101010),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .62,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(children: [
                  const Icon(Icons.visibility, color: Colors.white70),
                  const SizedBox(width: 9),
                  Text('LIVE VIEWERS  •  ${ids.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
              ),
              const Divider(color: Color(0x33FFFFFF), height: 1),
              Expanded(child: ListView.separated(
                itemCount: ids.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0x1FFFFFFF), height: 1),
                itemBuilder: (_, index) {
                  final id = ids[index];
                  final profile = profileById[id] ?? const <String, dynamic>{};
                  final publicProfile = publicById[id] ?? const <String, dynamic>{};
                  final name = (profile['display_name'] ?? participants[index].name).toString();
                  final zoonlId = (publicProfile['zoonl_id'] ?? 'Not set').toString();
                  final avatar = profile['avatar_url']?.toString() ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF303030),
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
                    ),
                    title: Text(name.isEmpty ? 'Viewer' : name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text('ZOONL ID: $zoonlId',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    trailing: const Icon(Icons.circle, color: Color(0xFF54D68B), size: 9),
                  );
                },
              )),
            ]),
          ),
        ),
      );
    } catch (error) {
      _showMessage('Viewer list नहीं खुली: ${_readable(error)}');
    }
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
    _liveBeautyProcessor = null;
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

  Future<void> _showGuestInviteDialog({int? initialSeatNumber}) async {
    final roomId = _roomId;
    if (roomId == null || !_isHost) return;
    final idController = TextEditingController();
    int seatNumber = initialSeatNumber ?? 1;
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

  void _hideMutedChatMessages(Map<String, dynamic> row) {
    final mutedUserId = row['muted_user_id']?.toString() ?? '';
    if (mutedUserId.isEmpty || !mounted) return;
    setState(() => _messages.removeWhere((message) => message['sender_id'] == mutedUserId));
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
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_room_chat_mutes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => _hideMutedChatMessages(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_room_chat_mutes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => _hideMutedChatMessages(payload.newRecord),
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
      final profileResults = await Future.wait<dynamic>([
        _supabase.from('user_public_profiles')
            .select('username,zoonl_id').eq('user_id', userId).maybeSingle(),
        _supabase.from('profiles')
            .select('display_name,avatar_url').eq('id', userId).maybeSingle(),
      ]);
      final publicProfile = profileResults[0] as Map<String, dynamic>?;
      final privateProfile = profileResults[1] as Map<String, dynamic>?;
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
        final displayName = privateProfile?['display_name']?.toString().trim() ?? '';
        final username = publicProfile?['username']?.toString().trim() ?? '';
        _entryBannerName = displayName.isNotEmpty ? displayName
            : username.isNotEmpty ? username
            : 'ID ${publicProfile?['zoonl_id'] ?? 'Member'}';
        _entryBannerEffect = effect?['zoonl_item_name']?.toString() ?? 'Standard Entry';
        _entryBannerMedia = (effect?['media_url']?.toString().trim().isNotEmpty == true)
            ? effect!['media_url'].toString()
            : code;
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
    if (senderId == _roomOwnerId && _hostDisplayName.isNotEmpty) return _hostDisplayName;
    return _chatNames[senderId] ?? 'User ${senderId.substring(0, 4)}';
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
        'tier': _chatTiers[senderId] ?? 'NONE',
        'chatColor': _chatColorHex[senderId] ?? '',
        'frameMedia': _chatFrameMedia[senderId] ?? '',
        'level': '${_chatLevels[senderId] ?? 1}',
        'avatar': _chatAvatars[senderId] ?? '',
      });
    });
  }

  Future<void> _loadChatModerationAccess() async {
    if (_isHost) {
      if (mounted) setState(() => _canModerateChat = true);
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        _supabase.rpc('is_zoonl_owner'),
        _supabase.rpc('is_zoonl_admin_allowed',
          params: <String, dynamic>{'p_permission_key': 'moderate_live_chat'}),
      ]);
      if (mounted) setState(() => _canModerateChat = results[0] == true || results[1] == true);
    } catch (_) {
      if (mounted) setState(() => _canModerateChat = false);
    }
  }

  Future<void> _moderateChatUser(String targetUserId) async {
    final roomId = _roomId;
    if (!_canModerateChat || roomId == null || targetUserId.isEmpty || targetUserId == _myId) return;
    final action = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('LIVE CHAT MODERATION',
              style: TextStyle(color: Color(0xFFFFE7B0), fontWeight: FontWeight.w900)),
          ),
          ListTile(
            leading: const Icon(Icons.timer, color: Color(0xFFFFD98B)),
            title: const Text('Mute for 1 hour'),
            onTap: () => Navigator.pop(sheetContext, 60),
          ),
          ListTile(
            leading: const Icon(Icons.volume_off, color: Color(0xFFFF8292)),
            title: const Text('Mute until Live ends'),
            onTap: () => Navigator.pop(sheetContext, -1),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up, color: Color(0xFF8CEBFF)),
            title: const Text('Unmute in this room'),
            onTap: () => Navigator.pop(sheetContext, 0),
          ),
        ]),
      ),
    );
    if (action == null) return;
    try {
      await _supabase.rpc('moderate_live_chat_user', params: <String, dynamic>{
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
        'p_muted': action != 0,
        'p_reason': 'Live room moderator action',
        'p_duration_minutes': action == -1 ? null : (action == 0 ? null : action),
      });
      if (action != 0 && mounted) {
        setState(() => _messages.removeWhere((message) => message['sender_id'] == targetUserId));
      }
      _showMessage(action == 0 ? 'User unmuted.' : 'User muted in this Live room.');
    } catch (error) {
      _showMessage('Moderation failed: ${_readable(error)}');
    }
  }

  Future<void> _loadChatBadge(String senderId) async {
    if (senderId.isEmpty || _chatBadges.containsKey(senderId)) return;
    _chatBadges[senderId] = 'LOADING';
    try {
      Future<dynamic> safe(Future<dynamic> request) async {
        try { return await request; } catch (_) { return null; }
      }
      final results = await Future.wait<dynamic>([
        safe(_supabase.rpc(
          'get_public_chat_badges',
          params: <String, dynamic>{'p_user_ids': <String>[senderId]},
        )),
        safe(_supabase.rpc(
          'get_public_chat_styles',
          params: <String, dynamic>{'p_user_ids': <String>[senderId]},
        )),
        safe(_supabase.rpc(
          'zoonl_level_for_user',
          params: <String, dynamic>{'p_user_id': senderId},
        )),
        safe(_supabase.from('user_public_profiles')
            .select('username').eq('user_id', senderId).maybeSingle()),
        safe(_supabase.from('profiles')
            .select('display_name,avatar_url').eq('id', senderId).maybeSingle()),
      ]);
      final rows = results[0] is List ? results[0] as List : const [];
      final badge = rows.isNotEmpty && rows.first is Map
          ? (rows.first['badge_code'] ?? 'NONE').toString()
          : 'NONE';
      final styleRows = results[1] is List ? results[1] as List : const [];
      final style = styleRows.isNotEmpty && styleRows.first is Map
          ? Map<String, dynamic>.from(styleRows.first as Map) : <String, dynamic>{};
      final tier = (style['tier_code'] ?? 'NONE').toString();
      final chatColor = (style['chat_color_hex'] ?? '').toString();
      final frameMedia = (style['frame_media_url'] ?? '').toString();
      final level = ((results[2] as num?)?.toInt() ?? 1).clamp(1, 100).toInt();
      final publicProfile = results[3] is Map ? results[3] as Map<String, dynamic> : null;
      final privateProfile = results[4] is Map ? results[4] as Map<String, dynamic> : null;
      final publicName = publicProfile?['username']?.toString().trim() ?? '';
      final profileName = privateProfile?['display_name']?.toString().trim() ?? '';
      final username = profileName.isNotEmpty ? profileName : publicName;
      final avatar = privateProfile?['avatar_url']?.toString().trim() ?? '';
      if (!mounted) return;
      setState(() {
        _chatBadges[senderId] = badge;
        _chatTiers[senderId] = tier;
        _chatColorHex[senderId] = chatColor;
        _chatFrameMedia[senderId] = frameMedia;
        _chatLevels[senderId] = level;
        if (username.isNotEmpty) _chatNames[senderId] = username;
        if (avatar.startsWith('http')) _chatAvatars[senderId] = avatar;
        for (final item in _messages) {
          if (item['sender_id'] == senderId) {
            item['badge'] = badge;
            item['tier'] = tier;
            item['chatColor'] = chatColor;
            item['frameMedia'] = frameMedia;
            item['level'] = '$level';
            if (username.isNotEmpty) item['name'] = username;
            if (avatar.startsWith('http')) item['avatar'] = avatar;
          }
        }
      });
    } catch (_) {
      _chatBadges[senderId] = 'NONE';
      _chatLevels[senderId] = 1;
    }
  }

  List<Color> _chatRibbonColors(int level) {
    if (level >= 91) return const [Color(0xFFFFE9A8), Color(0xFFB77A22), Color(0xFF57320D)];
    if (level >= 71) return const [Color(0xFFB8A4FF), Color(0xFF6846B5), Color(0xFF27164F)];
    if (level >= 51) return const [Color(0xFFFFC4EF), Color(0xFF9A3F8C), Color(0xFF42163F)];
    if (level >= 31) return const [Color(0xFF9CEBFF), Color(0xFF347FAE), Color(0xFF15334F)];
    if (level >= 11) return const [Color(0xFFB8E4D2), Color(0xFF367F70), Color(0xFF163D3A)];
    return const [Color(0xFFE4D0AA), Color(0xFF98734A), Color(0xFF45301F)];
  }

  Widget _buildChatLine(Map<String, String> item) {
    final tier = item['tier'] ?? 'NONE';
    final badge = tier == 'VIP' || tier == 'SVIP' || tier == 'VVIP'
        ? tier : (item['badge'] ?? 'NONE');
    final level = int.tryParse(item['level'] ?? '') ?? 1;
    final rawPalette = (item['chatColor'] ?? '').split(',');
    final customColors = <Color>[];
    for (final raw in rawPalette.take(3)) {
      final hex = raw.trim().replaceFirst('#', '');
      final value = int.tryParse(hex, radix: 16);
      if (value != null) customColors.add(Color(0xFF000000 | value));
    }
    final colors = customColors.length >= 3 ? customColors : _chatRibbonColors(level);
    final name = item['name'] ?? 'User';
    final initial = name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();
    final avatar = item['avatar'] ?? '';
    final frameMedia = item['frameMedia'] ?? '';
    final framePath = frameMedia.toLowerCase().split('?').first;
    final showFrameMedia = frameMedia.startsWith('http') &&
        (framePath.endsWith('.png') || framePath.endsWith('.jpg') ||
         framePath.endsWith('.jpeg') || framePath.endsWith('.webp') ||
         framePath.endsWith('.gif'));
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [colors[2].withOpacity(.88), colors[1].withOpacity(.30), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: colors[0], width: 2.2)),
        boxShadow: [BoxShadow(color: colors[1].withOpacity(.16), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30, height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 23, height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [colors[0], colors[1], colors[2]]),
                    border: Border.all(color: colors[0].withOpacity(.95), width: 1),
                    boxShadow: [BoxShadow(color: colors[0].withOpacity(.45), blurRadius: 7)],
                  ),
                  child: avatar.startsWith('http')
                      ? ClipOval(child: Image.network(avatar, width: 23, height: 23, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))))
                      : Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                ),
                if (showFrameMedia)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image.network(frameMedia, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors[0], fontSize: 10, fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: colors[1].withOpacity(.8), blurRadius: 5)])),
                    if (badge == 'VIP' || badge == 'SVIP' || badge == 'VVIP')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: badge == 'SVIP'
                              ? const [Color(0xFFFF8292), Color(0xFF9D1E42)]
                              : badge == 'VVIP'
                                  ? const [Color(0xFFD9B6FF), Color(0xFF6C35B4)]
                                  : const [Color(0xFFFFE8A8), Color(0xFF9D6A1E)]),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withOpacity(.65), width: .5),
                        ),
                        child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .4)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [colors[0], colors[1]]),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withOpacity(.65), width: .5),
                      ),
                      child: Text('LV $level', style: const TextStyle(color: Color(0xFF101018), fontSize: 7, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(item['message'] ?? '', style: TextStyle(color: badge == 'NONE' ? Colors.white : colors[0], fontSize: 11, height: 1.12, fontWeight: badge == 'NONE' ? FontWeight.normal : FontWeight.w600)),
              ],
            ),
          ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171126),
        title: const Text('End this live broadcast?'),
        content: const Text('The room will close for every viewer and all guest seats will be released.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('KEEP LIVE')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.call_end),
            label: const Text('END LIVE'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
    final media = (gift['media_url'] ?? gift['image_url'] ?? '').toString().trim();
    final screen = MediaQuery.of(context).size;
    final mediaSize = math.min(screen.width * .94, screen.height * .68)
        .clamp(180.0, 520.0).toDouble();
    return IgnorePointer(
      child: SizedBox.expand(
        child: ColoredBox(
          color: const Color(0x33000000),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (media.isNotEmpty)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .72, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: _LiveGiftMedia(url: media, size: mediaSize),
                )
              else
                Icon(Icons.card_giftcard, size: mediaSize * .48,
                    color: Colors.white),
              Positioned(
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).padding.bottom + 94,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0x66FFFFFF)),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text((gift['gift_name'] ?? 'Live Gift').toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white,
                              fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${gift['sender_name'] ?? 'Viewer'}  •  ×${gift['quantity'] ?? 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

  Future<void> _flipLiveCamera() async {
    if (!_isLive || _selectedRoomType != 'video' || (!_isHost && !_isGuest)) return;
    final room = _lk;
    if (room == null) return;
    try {
      final publications = room.localParticipant?.videoTrackPublications ?? const [];
      for (final publication in publications) {
        final track = publication.track;
        if (track is LocalVideoTrack) {
          final next = _frontLiveCamera ? CameraPosition.back : CameraPosition.front;
          await track.setCameraPosition(next);
          if (mounted) setState(() => _frontLiveCamera = !_frontLiveCamera);
          return;
        }
      }
      _showMessage('Active camera track not found.');
    } catch (error) {
      _showMessage('Camera switch failed: \${_readable(error)}');
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
    final liveNow = _isLive;
    if (!_isHost || _selectedRoomType != 'video') return;
    if (liveNow && (roomId == null || userId == null)) return;

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
                const Text('LIVE VIDEO FILTERS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _previewFilters.map((filter) => ChoiceChip(
                    label: Text(filter),
                    selected: selected == filter,
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF202020),
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    labelStyle: TextStyle(color: selected == filter ? Colors.black : Colors.white, fontWeight: FontWeight.w700),
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
                  'ZOONL Beauty Studio processes camera frames before LiveKit publishing: subtle smoothing, glow, brightness and warm/cool tone. Face Studio avatar tracking and AR masks are a separate engine and are not active in this build.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : () async {
                      setSheetState(() => saving = true);
                      try {
                        if (liveNow) {
                          final updated = await _supabase.from('live_rooms')
                            .update({
                              'video_filter_code': selected,
                              'video_filter_strength': strength,
                            })
                            .eq('id', roomId!)
                            .eq('owner_id', userId!)
                            .select('id')
                            .maybeSingle();
                          if (updated == null) {
                            throw StateError('Room filter could not be saved. Check live-room update permission.');
                          }
                          await _updateLiveBeautyProcessor(
                            look: selected,
                            strength: strength,
                          );
                        }
                        if (mounted) {
                          setState(() {
                            _previewFilter = selected;
                            _filterStrength = strength;
                            _filterConfirmed = true;
                          });
                        }
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        _showMessage(liveNow ? 'Beauty filter applied to the live camera.' : 'Beauty filter saved for your next live.');
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
            fixedSize: const Size(54, 54),
            shape: const CircleBorder(),
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
      appBar: _isLive ? null : AppBar(
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
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('entry-$_entryBannerName-$_entryBannerEffect'),
                    tween: Tween<double>(begin: -1.35, end: 1.35),
                    duration: const Duration(milliseconds: 3900),
                    curve: Curves.easeInOutCubic,
                    builder: (context, travel, child) => Align(
                      alignment: Alignment(travel, 0.08),
                      child: child,
                    ),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * .82,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xEE171126), Color(0xF02E1C4B), Color(0xEE101A2D)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFFFD98B), width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Color(0x88D8A84E), blurRadius: 30, spreadRadius: 4),
                              BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, 12)),
                            ],
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            if ((_entryBannerMedia ?? '').startsWith('https://'))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: _LiveGiftMedia(url: _entryBannerMedia!, size: 118),
                              )
                            else
                              Text(switch (_entryBannerMedia) {
                                'ENTRY_HORSE_GOLD' => '🐎',
                                'ENTRY_ELEPHANT_ROYAL' => '🐘',
                                'ENTRY_LION_ROYAL' => '🦁',
                                'ENTRY_BUTTERFLY_GLOW' => '🦋',
                                'ENTRY_FALCON_SKY' => '🦅',
                                'ENTRY_DEER_FOREST' => '🦌',
                                'ENTRY_WOLF_SHADOW' => '🐺',
                                'ENTRY_DRAGON_EMBER' => '🐉',
                                'ENTRY_PHOENIX_FIRE' => '🔥',
                                'ENTRY_UNICORN_DIAMOND' => '🦄',
                                'ENTRY_PEACOCK_ROYAL' => '🦚',
                                'ENTRY_TIGER_EMPEROR' => '🐅',
                                _ => '👑',
                              }, style: const TextStyle(fontSize: 82, height: 1.1)),
                            const SizedBox(height: 8),
                            Text((_entryBannerName ?? 'Member').toUpperCase(),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text((_entryBannerEffect ?? 'Standard Entry').toUpperCase(),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFFFE3A0), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 3),
                            const Text('HAS ENTERED THE ROOM', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          ]),
                        ),
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
    final camera = _previewCamera;
    return LayoutBuilder(builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        if (_selectedRoomType == 'video' && camera != null && camera.value.isInitialized)
          ColorFiltered(
            colorFilter: _selectedPreviewColorFilter,
            child: SizedBox.expand(child: CameraPreview(camera)),
          )
        else if (_selectedRoomType == 'audio')
          _AudioRoomThemeBackdrop(
            themeCode: _audioThemeCode,
            child: const Center(child: Icon(Icons.graphic_eq, size: 112, color: Colors.white70)),
          )
        else
          const ColoredBox(color: Color(0xFF080808)),
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x88000000), Colors.transparent, Color(0xEE000000)],
            stops: [0, .38, 1]))))),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 14,
          right: 14,
          child: Row(children: [
            _startGlass(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_tethering, color: Colors.white, size: 19),
              const SizedBox(width: 9),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ZOONL BROADCAST STUDIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .8)),
                Text('${widget.userName}  •  ID ${widget.userId}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ])),
            const Spacer(),
            IconButton.filled(
              onPressed: _previewLoading ? null : _flipPreviewCamera,
              style: IconButton.styleFrom(backgroundColor: const Color(0xAA000000), foregroundColor: Colors.white),
              icon: const Icon(Icons.flip_camera_android),
            ),
          ]),
        ),
        if (_selectedRoomType == 'video' && (camera == null || !camera.value.isInitialized))
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.camera_alt_outlined, size: 52, color: Colors.white),
            const SizedBox(height: 10),
            Text(_previewError ?? (_previewLoading ? 'Camera opening…' : 'Camera preview unavailable'),
              style: const TextStyle(color: Colors.white70)),
            if (!_previewLoading) TextButton(onPressed: _initializePreviewCamera, child: const Text('RETRY CAMERA')),
          ])),
        Positioned(
          left: 10, right: 10, bottom: 10,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .62),
            child: _startGlass(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(child: Text('GO LIVE SETUP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 12))),
                    Text('PREVIEW', style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 9, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: _startModeButton('VIDEO LIVE', _selectedRoomType == 'video', () {
                      setState(() => _selectedRoomType = 'video');
                      unawaited(_initializePreviewCamera());
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _startModeButton('AUDIO LIVE', _selectedRoomType == 'audio', () {
                      setState(() => _selectedRoomType = 'audio');
                      unawaited(_disposePreviewCamera());
                    })),
                  ]),
                  if (_selectedRoomType == 'video') ...[
                    const SizedBox(height: 10),
                    const Text('FILTER LOOK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _openLiveFilterSettings,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('OPEN BEAUTY STUDIO • ALL FILTER SETTINGS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE6C47A),
                          side: const BorderSide(color: Color(0xFFE6C47A)),
                        ),
                      ),
                    ),
                    Wrap(spacing: 6, runSpacing: 6, children: _previewFilters.map((filter) =>
                      ChoiceChip(
                        label: Text(filter, style: const TextStyle(fontSize: 10)),
                        selected: _previewFilter == filter,
                        onSelected: _busy ? null : (_) => setState(() { _previewFilter = filter; _filterConfirmed = true; }),
                        selectedColor: Colors.white,
                        backgroundColor: const Color(0x44000000),
                        side: const BorderSide(color: Color(0x66FFFFFF)),
                        labelStyle: TextStyle(color: _previewFilter == filter ? Colors.black : Colors.white),
                      )).toList()),
                    Row(children: [
                      const Text('Strength', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Expanded(child: Slider(value: _filterStrength, onChanged: _busy ? null : (v) => setState(() => _filterStrength = v))),
                      Text('${(_filterStrength * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ]),
                    const Text('Preview shows the selected colour look. ZOONL Beauty Studio applies smoothing, glow, brightness and tone to the outgoing LiveKit camera after GO LIVE.',
                      style: TextStyle(color: Colors.white70, fontSize: 9)),
                  ] else
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: _busy ? null : _openAudioThemePicker,
                      icon: const Icon(Icons.wallpaper, color: Colors.white),
                      label: const Text('ROOM BACKGROUND', style: TextStyle(color: Colors.white)),
                    )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    maxLength: 60,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Broadcast title',
                      hintStyle: const TextStyle(color: Colors.white60),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0x44000000),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x66FFFFFF))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x44FFFFFF))),
                    ),
                  ),
                  SwitchListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: const Text('Private room', style: TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: Text(_canUsePrivateRooms ? 'Invite-only access' : 'Unlocks at Level 10', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                    value: _privateRoom,
                    onChanged: _busy || !_canUsePrivateRooms ? null : (v) => setState(() { _privateRoom = v; if (v) _lockedRoom = true; }),
                  ),
                  SwitchListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: const Text('Lock room', style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: _lockedRoom,
                    onChanged: _busy || !_canUsePrivateRooms ? null : (v) => setState(() => _lockedRoom = v),
                  ),
                  Row(children: [
                    IconButton.filled(
                      onPressed: _toggleMicrophone,
                      style: IconButton.styleFrom(backgroundColor: const Color(0x66FFFFFF), foregroundColor: Colors.white),
                      icon: Icon(_microphoneEnabled ? Icons.mic : Icons.mic_off),
                    ),
                    Expanded(child: Text(_microphoneEnabled ? 'Microphone on' : 'Microphone muted', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _busy || (_selectedRoomType == 'video' && (!_filterConfirmed || camera?.value.isInitialized != true)) ? null : _startLive,
                        icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                        label: Text(_busy ? 'CONNECTING' : 'GO LIVE'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      ),
                    ),
                  ]),
                ],
              )),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _startGlass({required Widget child, EdgeInsets padding = const EdgeInsets.all(10)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _startModeButton(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x33000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
      ),
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
    final liveParticipants = _lk?.remoteParticipants.values.where((p) => _isHost || p.identity != _roomOwnerId).toList() ?? [];
    final viewers = liveParticipants.length;
    return Column(children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: ColoredBox(color: const Color(0xFF080A12),
          child: _selectedRoomType == 'audio'
            ? _AudioRoomThemeBackdrop(themeCode: _audioThemeCode, child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.headphones, size: 92, color: Colors.white), SizedBox(height: 10),
                Text('AUDIO LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))])))
            : SizedBox.expand(child: _videoLayer()))),
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[Color(0x99000000),Colors.transparent,Color(0xCC000000)],stops:[0,.48,1]))))),
        Positioned(top: 12,left: 12,child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_hostIdentityGlass(),_hostStarStrip()])),
        Positioned(top: 14,right: 12,child:_viewerPreviewStrip(viewers)),
        if (_selectedRoomType == 'audio') Positioned(left: 12,right: 12,top: 150,child:_audioSeatStage()),
        if ((_isHost && _guestSeats.any((seat)=>seat['seat_status']=='occupied')) || _isGuest)
          Positioned(right:12,top:165,child:_guestMiniOverlay()),
        if (_giftBanner != null) Positioned.fill(child:_liveGiftBanner()),
        if (_chatEnabled) Positioned(left:10,right:10,bottom:8,
          child: ConstrainedBox(constraints:BoxConstraints(maxHeight:math.min(138,MediaQuery.of(context).size.height*.20)),
            child:Container(padding:const EdgeInsets.fromLTRB(10,7,10,8),
              decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:[Color(0xB8181424),Color(0xD9080A12)]),borderRadius:BorderRadius.circular(16),
                border:Border.all(color:const Color(0x55FFFFFF)),boxShadow:const[BoxShadow(color:Colors.black54,blurRadius:14,offset:Offset(0,5))]),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                Row(children:[const Icon(Icons.chat_bubble,color:Color(0xFFE6C47A),size:13),const SizedBox(width:6),
                  const Text('LIVE CHAT',style:TextStyle(color:Colors.white70,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1)),
                  const Spacer(),Text('\${_messages.length} messages',style:const TextStyle(color:Colors.white38,fontSize:8))]),
                const SizedBox(height:4),
                SizedBox(height:102,child:ListView.builder(reverse:true,itemCount:_messages.length.clamp(0,3),itemBuilder:(context,index){
                  final item=_messages[_messages.length-1-index];final senderId=item['sender_id']??'';return Padding(padding:const EdgeInsets.symmetric(vertical:2),child:GestureDetector(onLongPress:_canModerateChat && senderId.isNotEmpty && senderId!=_myId ? ()=>_moderateChatUser(senderId) : null,child:_buildChatLine(item)));})),
                const SizedBox(height:5),
                Row(children:[
                  Expanded(child:TextField(controller:_messageController,maxLength:300,style:const TextStyle(color:Colors.white,fontSize:12),
                    decoration:InputDecoration(hintText:'Write a message...',hintStyle:const TextStyle(color:Colors.white54,fontSize:11),
                      counterText:'',isDense:true,filled:true,fillColor:const Color(0x88000000),
                      contentPadding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
                      border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)),
                    onSubmitted:(_)=>_sendMessage())),
                  const SizedBox(width:5),
                  IconButton.filled(onPressed:_sendMessage,style:IconButton.styleFrom(backgroundColor:const Color(0xFFE6C47A),foregroundColor:Colors.black,
                    minimumSize:const Size(36,36),padding:EdgeInsets.zero),icon:const Icon(Icons.send,size:17)),
                ]),
              ])))),
      ])),
      Container(padding:const EdgeInsets.fromLTRB(8,7,8,8),
        decoration:const BoxDecoration(color:Color(0xFF100C18),border:Border(top:BorderSide(color:Color(0x33FFFFFF)))),
        child:SafeArea(top:false,child:SingleChildScrollView(scrollDirection:Axis.horizontal,
          child:Row(children:_isHost?_hostControls():_viewerControls())))),
    ]);
  }

  Widget _audioSeatStage() {
    final seats = _guestSeats;
    final shown = seats.take(8).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: const Color(0x99090C18), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x66E6C47A))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('AUDIO BROADCAST • 8 GUEST SEATS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 9),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 9, children: List.generate(8, (i) {
          final seat = i < shown.length ? shown[i] : <String, dynamic>{};
          final active = seat['seat_status'] == 'occupied';
          final name = active ? (seat['display_name'] ?? seat['user_name'] ?? 'Guest').toString() : 'Open Seat';
          final seatNumber = (seat['seat_number'] as num?)?.toInt() ?? (i + 1);
          return SizedBox(width: 72, child: InkWell(
            onTap: _isHost && !active ? () => _showGuestInviteDialog(initialSeatNumber: seatNumber) : null,
            borderRadius: BorderRadius.circular(14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: LinearGradient(colors: active ? const [Color(0xFFFFD77C), Color(0xFF8A5524)] : const [Color(0xFF46516B), Color(0xFF151B2A)]),
                  border: Border.all(color: active ? const Color(0xFFFFE7AE) : Colors.white30, width: 1.4),
                  boxShadow: active ? const [BoxShadow(color: Color(0x66E6C47A), blurRadius: 10)] : null),
                child: Icon(active ? Icons.mic : Icons.add, color: Colors.white, size: 20)),
              const SizedBox(height: 3),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              Text(active ? 'SEAT $seatNumber' : (_isHost ? 'INVITE' : 'TAP TO JOIN'), style: const TextStyle(color: Color(0xFFE6C47A), fontSize: 7, fontWeight: FontWeight.w900)),
            ]),
          ));
        })),
      ]),
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
      if (_selectedRoomType == 'video') _control(icon: Icons.flip_camera_android, label: 'Flip Camera', onTap: _flipLiveCamera),
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
          _control(icon: Icons.flip_camera_android, label: 'Flip', onTap: _flipLiveCamera),
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
