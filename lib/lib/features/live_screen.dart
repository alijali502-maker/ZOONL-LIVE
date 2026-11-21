import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../event_control_screen.dart';
import '../../profile_edit_screen.dart';
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
    Widget body;
    if (_isLive) {
      body = _buildLiveRoom();
    } else if (_isHost) {
      body = _buildStartScreen();
    } else {
      body = const Center(child: CircularProgressIndicator(color: Color(0xFFE6C47A)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080510),
      extendBodyBehindAppBar: true,
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: body),
        if (_entryBannerName != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: IgnorePointer(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _glassPanel(child: Row(children: [
                if ((_entryBannerMedia ?? '').startsWith('https://'))
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: Image.network(_entryBannerMedia!, width: 42, height: 42, fit: BoxFit.cover))
                else const Icon(Icons.auto_awesome, color: Color(0xFFE6C47A), size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text('$_entryBannerName ENTERED • ${_entryBannerEffect ?? 'Standard Entry'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ])),
            )),
          ),
      ]),
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
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
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
              child: const Center(child: Icon(Icons.graphic_eq, size: 116, color: Colors.white70)),
            )
          else
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF080510), Color(0xFF24153A), Color(0xFF080510)]))),
          const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x99080510), Colors.transparent, Color(0xEE080510)],
              stops: [0, .42, 1]))),
          Positioned(
            top: 10, left: 14, right: 14,
            child: Row(children: [
              _glassPanel(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 22,
                    backgroundColor: const Color(0xFF302047),
                    backgroundImage: (_hostAvatarUrl ?? '').isNotEmpty ? NetworkImage(_hostAvatarUrl!) : null,
                    child: (_hostAvatarUrl ?? '').isEmpty ? const Icon(Icons.person, color: Color(0xFFE6C47A)) : null),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('ZOONL ID ${widget.userId}', style: const TextStyle(color: Color(0xFFE6C47A), fontSize: 10)),
                  ]),
                ]),
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: _previewLoading ? null : _flipPreviewCamera,
                style: IconButton.styleFrom(backgroundColor: const Color(0xAA171126), foregroundColor: Colors.white),
                icon: const Icon(Icons.flip_camera_android),
              ),
            ]),
          ),
          if (_selectedRoomType == 'video' && (camera == null || !camera.value.isInitialized))
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.camera_alt_outlined, size: 54, color: Color(0xFFE6C47A)),
              const SizedBox(height: 10),
              Text(_previewError ?? (_previewLoading ? 'Camera opening…' : 'Camera preview unavailable'),
                style: const TextStyle(color: Colors.white70)),
              if (!_previewLoading) TextButton(onPressed: _initializePreviewCamera, child: const Text('RETRY CAMERA')),
            ])),
          Positioned(
            left: 12, right: 12, bottom: 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight * .58),
              child: _glassPanel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: SingleChildScrollView(child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Text('VIP BROADCAST STUDIO',
                        style: TextStyle(color: Color(0xFFE6C47A), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFF7D244A), borderRadius: BorderRadius.circular(20)),
                        child: const Text('PREVIEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _studioModeButton('VIDEO LIVE', _selectedRoomType == 'video', () {
                        setState(() => _selectedRoomType = 'video');
                        unawaited(_initializePreviewCamera());
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: _studioModeButton('AUDIO LIVE', _selectedRoomType == 'audio', () {
                        setState(() => _selectedRoomType = 'audio');
                        unawaited(_disposePreviewCamera());
                      })),
                    ]),
                    if (_selectedRoomType == 'video') ...[
                      const SizedBox(height: 12),
                      const Text('LIVE LOOKS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      const SizedBox(height: 7),
                      Wrap(spacing: 7, runSpacing: 7, children: _previewFilters.map((filter) =>
                        ChoiceChip(label: Text(filter), selected: _previewFilter == filter,
                          onSelected: (_) => setState(() { _previewFilter = filter; _filterConfirmed = true; }))
                      ).toList()),
                      Row(children: [
                        const Text('Look strength', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Expanded(child: Slider(value: _filterStrength, onChanged: (v) => setState(() => _filterStrength = v))),
                        Text('${(_filterStrength * 100).round()}%', style: const TextStyle(color: Colors.white)),
                      ]),
                      const Text('ये अभी केवल कैमरा preview का colour look है। LiveKit के outgoing video पर असली skin-retouch/face-shape effects अभी wired नहीं हैं।',
                        style: TextStyle(color: Color(0xFFFFD59A), fontSize: 10)),
                    ] else ...[
                      OutlinedButton.icon(onPressed: _openAudioThemePicker,
                        icon: const Icon(Icons.wallpaper), label: const Text('FULL-SCREEN ROOM THEME')),
                    ],
                    const SizedBox(height: 8),
                    TextField(controller: _titleController, maxLength: 60,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(counterText: '', hintText: 'Broadcast title',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true, fillColor: const Color(0x66201630),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0x66E6C47A))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0x66E6C47A)))),
                    ),
                    Row(children: [
                      Expanded(child: Text('Profile photo: ${(_hostAvatarUrl ?? '').isNotEmpty ? 'SAVED' : 'NOT SET'}',
                        style: TextStyle(color: (_hostAvatarUrl ?? '').isNotEmpty ? const Color(0xFF8FE0C4) : const Color(0xFFFFD59A), fontSize: 11, fontWeight: FontWeight.bold))),
                      TextButton(onPressed: () async {
                        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => const ProfileEditScreen()));
                        if (saved == true) await _loadHostProfile();
                      }, child: const Text('EDIT PROFILE')),
                    ]),
                    Row(children: [
                      IconButton.filled(onPressed: _toggleMicrophone, icon: Icon(_microphoneEnabled ? Icons.mic : Icons.mic_off),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF49305E))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_microphoneEnabled ? 'Microphone ready' : 'Microphone muted',
                        style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      if (_canUsePrivateRooms)
                        IconButton(onPressed: () => setState(() { _privateRoom = !_privateRoom; _lockedRoom = _privateRoom || _lockedRoom; }),
                          icon: Icon(_privateRoom ? Icons.lock : Icons.lock_open, color: Colors.white)),
                    ]),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
                      onPressed: _busy || (_selectedRoomType == 'video' && camera?.value.isInitialized != true) ? null : _startLive,
                      icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                      label: Text(_busy ? 'CONNECTING…' : 'START BROADCAST'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6C47A), foregroundColor: const Color(0xFF160F22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    )),
                  ],
                )),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _glassPanel({required Widget child, EdgeInsets padding = const EdgeInsets.all(10)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x66FFFFFF), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 28, spreadRadius: 1),
              BoxShadow(color: Color(0x18FFFFFF), blurRadius: 1, offset: Offset(0, 1)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _studioModeButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(onTap: _busy ? null : onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected ? const Color(0xCCFFFFFF) : const Color(0x33000000),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: selected ? Colors.white : const Color(0x66FFFFFF)),
      ),
      child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white,
        fontSize: 10, fontWeight: FontWeight.w900))),
    ));
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
    final hostName = _roomOwnerId == _myId ? widget.userName : _roomName;
    return LayoutBuilder(builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _selectedRoomType == 'audio'
            ? _AudioRoomThemeBackdrop(themeCode: _audioThemeCode,
                child: const Center(child: Icon(Icons.graphic_eq, size: 120, color: Colors.white70)))
            : _videoLayer(),
        ),
        const Positioned.fill(child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x99080510), Colors.transparent, Color(0xEE080510)],
            stops: [0, .45, 1]))))),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12,
          child: Row(children: [
            _glassPanel(child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 21, backgroundColor: const Color(0xFF302047),
                backgroundImage: (_hostAvatarUrl ?? '').isNotEmpty ? NetworkImage(_hostAvatarUrl!) : null,
                child: (_hostAvatarUrl ?? '').isEmpty ? const Icon(Icons.person, color: Color(0xFFE6C47A)) : null),
              const SizedBox(width: 9),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hostName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                Text('ZOONL LIVE • LEVEL $_hostLevel', style: const TextStyle(color: Color(0xFFE6C47A), fontSize: 9)),
              ]),
            ])),
            const Spacer(),
            _glassPanel(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text('$viewers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ])),
          ]),
        ),
        if ((_isHost && _guestSeats.any((seat) => seat['seat_status'] == 'occupied')) || _isGuest)
          Positioned(right: 12, top: MediaQuery.of(context).padding.top + 72, child: _guestMiniOverlay()),
        if (_giftBanner != null) Positioned.fill(child: _liveGiftBanner()),
        Positioned(
          left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 10,
          child: _glassPanel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_roomName.isNotEmpty)
                Align(alignment: Alignment.centerLeft, child: Text(_roomName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.w900, fontSize: 12))),
              if (_chatEnabled) ...[
                SizedBox(height: math.min(88, constraints.maxHeight * .14),
                  child: ListView.builder(reverse: true, itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final item = _messages[_messages.length - 1 - index];
                      return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: _buildChatLine(item));
                    })),
                Row(children: [
                  Expanded(child: TextField(controller: _messageController, maxLength: 300,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(hintText: 'Write a message…', counterText: '',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true, fillColor: const Color(0x55302047),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
                    onSubmitted: (_) => _sendMessage())),
                  IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Color(0xFFE6C47A))),
                ]),
              ],
              const SizedBox(height: 4),
              SizedBox(height: 76, child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: (_isHost ? _hostControls() : _viewerControls())
                  .map((control) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: control)).toList()),
              )),
            ]),
          ),
        ),
      ],
    ));
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
