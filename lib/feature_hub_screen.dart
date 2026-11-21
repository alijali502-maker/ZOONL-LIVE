import 'package:flutter/material.dart';

import 'core/backend.dart';
import 'lib/features/live_screen.dart';
import 'role_portals_screen.dart';
import 'settings_center_screen.dart';
import 'short_video_studio_screen.dart';
import 'short_video_feed_screen.dart';

class FeatureHubScreen extends StatefulWidget {
  final String? roomTypeFilter;
  const FeatureHubScreen({super.key, this.roomTypeFilter});

  @override
  State<FeatureHubScreen> createState() => _FeatureHubScreenState();
}

class _FeatureHubScreenState extends State<FeatureHubScreen> {
  static const Color _bg = Color(0xFF080D14);
  static const Color _panel = Color(0xFF17232E);
  static const Color _panelRaised = Color(0xFF1D2B37);
  static const Color _gold = Color(0xFFD6B46A);
  static const Color _teal = Color(0xFF4BC2B0);
  static const Color _muted = Color(0xFFAAB5BE);

  bool _loading = true;
  bool _canHost = false;
  String? _error;
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _guestInvites = [];
  List<Map<String, dynamic>> _privateInvites = [];
  List<Map<String, dynamic>> _shortVideos = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = Backend.currentUserId;
      if (userId == null) {
        throw StateError('Login required.');
      }

      final profile = await Backend.client
          .from('profiles')
          .select('username, display_name, avatar_url, user_level, is_verified')
          .eq('id', userId)
          .maybeSingle();

      final publicProfile = await Backend.client
          .from('user_public_profiles')
          .select('zoonl_id')
          .eq('user_id', userId)
          .maybeSingle();
      final owner = await Backend.isZoonlOwner();
      var roomQuery = Backend.client
          .from('live_rooms')
          .select('id, owner_id, room_name, room_type, viewer_count, is_private, is_locked')
          .eq('is_live', true)
          .eq('is_private', false)
          .eq('is_locked', false);
      if (widget.roomTypeFilter != null) {
        roomQuery = roomQuery.eq('room_type', widget.roomTypeFilter!);
      }
      final roomsRaw = await roomQuery
          .order('created_at', ascending: false)
          .limit(30);

      final guestInvitesRaw = await Backend.client
          .from('room_guest_invitations')
          .select('id, room_id, inviter_id, invitee_id, seat_number, invite_status, expires_at, is_video_enabled, is_audio_enabled')
          .eq('invitee_id', userId)
          .eq('invite_status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final privateInvitesRaw = await Backend.client
          .from('private_room_invites')
          .select('id, room_id, inviter_id, invite_status, expires_at, created_at')
          .eq('invitee_id', userId)
          .eq('invite_status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final shortsRaw = await Backend.client
          .from('short_videos')
          .select('id,user_id,video_url,caption,duration_seconds,likes_count,created_at')
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(5);

      final giftsRaw = await Backend.client
          .from('gifts')
          .select('id, gift_name, coin_price')
          .eq('is_active', true)
          .order('coin_price', ascending: true)
          .limit(8);

      if (!mounted) return;
      setState(() {
        _profile = <String, dynamic>{
          ..._map(profile),
          'zoonl_id': publicProfile?['zoonl_id'],
        };
        _canHost = owner || profile?['is_verified'] == true;
        _rooms = (roomsRaw as List)
            .map((row) => _map(row))
            .toList();
        _gifts = (giftsRaw as List)
            .map((row) => _map(row))
            .toList();
        _guestInvites = (guestInvitesRaw as List)
            .map((row) => _map(row))
            .toList();
        _privateInvites = (privateInvitesRaw as List)
            .map((row) => _map(row))
            .toList();
        _shortVideos = (shortsRaw as List)
            .map((row) => _map(row))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startLive({required String roomType}) async {
    if (!_canHost) {
      _notice('Broadcasting is available to the Owner or an approved Host only.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveScreen(
          userName: (_profile['display_name'] ?? 'ZOONL Host').toString(),
          userId: (_profile['zoonl_id'] ?? '').toString(),
          roomType: roomType,
        ),
      ),
    );
    _loadDashboard();
  }

  Future<void> _openShortStudio() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ShortVideoStudioScreen()),
    );
    if (uploaded == true) await _loadDashboard();
  }

  Future<void> _openShortFeed({bool onlyMine = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShortVideoFeedScreen(onlyMine: onlyMine),
      ),
    );
    await _loadDashboard();
  }

  Future<void> _respondGuestInvite(
    Map<String, dynamic> invitation,
    bool accept,
  ) async {
    try {
      final seatId = await Backend.client.rpc(
        'room_respond_guest_invitation',
        params: <String, dynamic>{
          'p_invitation_id': invitation['id'],
          'p_accept': accept,
        },
      );
      if (!mounted) return;
      if (accept) {
        if (seatId == null) {
          _notice('This guest invitation expired or the seat was taken.');
          await _loadDashboard();
          return;
        }
        final roomId = invitation['room_id'].toString();
        final room = await Backend.client
            .from('live_rooms')
            .select('id, owner_id, room_name, room_type, viewer_count, is_private, is_locked, is_live')
            .eq('id', roomId)
            .maybeSingle();
        if (room == null || room['is_live'] != true) {
          _notice('This live room has already ended.');
          await _loadDashboard();
          return;
        }
        await _joinRoom(_map(room));
      } else {
        _notice('Guest invitation declined.');
      }
      await _loadDashboard();
    } catch (error) {
      _notice('Guest invitation could not be processed: $error');
    }
  }


  Future<void> _respondPrivateInvite(Map<String, dynamic> invite, bool accept) async {
    try {
      await Backend.client.rpc('private_room_respond_invite', params: {
        'p_invite_id': invite['id'],
        'p_accept': accept,
      });
      if (!mounted) return;
      if (!accept) {
        _notice('Private room invitation declined.');
        await _loadDashboard();
        return;
      }
      final room = await Backend.client.from('live_rooms')
          .select('id, owner_id, room_name, room_type, viewer_count, is_private, is_locked, is_live')
          .eq('id', invite['room_id'].toString()).maybeSingle();
      if (room == null || room['is_live'] != true) {
        _notice('This private live has already ended.');
        await _loadDashboard();
        return;
      }
      await _joinRoom(_map(room));
      await _loadDashboard();
    } catch (error) {
      _notice('Private invitation could not be processed: $error');
    }
  }

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveScreen(
          userName: (_profile['display_name'] ?? 'ZOONL User').toString(),
          userId: (_profile['zoonl_id'] ?? '').toString(),
          joinRoomId: room['id'].toString(),
          roomType: (room['room_type'] ?? 'video').toString(),
        ),
      ),
    );
    _loadDashboard();
  }

  Widget _panelCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(15)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF354653)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {String? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null)
            TextButton(
              onPressed: onTap,
              child: Text(trailing, style: const TextStyle(color: _teal, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile['display_name'] ?? 'ZOONL Member').toString();
    final publicId = (_profile['zoonl_id'] ?? '').toString();
    final level = (_profile['user_level'] as num?)?.toInt() ?? 1;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _panel,
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            _panelCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.diamond_outlined, color: _gold, size: 27),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'ZOONL LIVE',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loading ? null : _loadDashboard,
                        icon: const Icon(Icons.refresh_rounded, color: _teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Welcome, $name',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'User ID: ${publicId.isEmpty ? 'Not assigned' : publicId}  •  Level $level',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 15),
                  if (widget.roomTypeFilter == 'video')
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _canHost ? () => _startLive(roomType: 'video') : null,
                      icon: const Icon(Icons.videocam_rounded),
                      label: const Text('START VIDEO LIVE'),
                      style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF071713)),
                    ))
                  else if (widget.roomTypeFilter == 'audio')
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: _canHost ? () => _startLive(roomType: 'audio') : null,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('START AUDIO LIVE'),
                    ))
                  else
                    Row(children: [
                      Expanded(child: FilledButton.icon(
                        onPressed: _canHost ? () => _startLive(roomType: 'video') : null,
                        icon: const Icon(Icons.videocam_rounded),
                        label: const Text('VIDEO LIVE'),
                        style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF071713)),
                      )),
                      const SizedBox(width: 9),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _canHost ? () => _startLive(roomType: 'audio') : null,
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text('AUDIO LIVE'),
                      )),
                    ]),
                  if (!_canHost)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Live publishing unlocks after Host approval. Owner accounts can broadcast.',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            _sectionTitle('Short Videos', trailing: 'VIEW ALL', onTap: () => _openShortFeed()),
            _panelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record, publish and watch public Shorts',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openShortStudio,
                          icon: const Icon(Icons.videocam),
                          label: const Text('UPLOAD SHORT'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: const Color(0xFF071713),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openShortFeed(onlyMine: true),
                          icon: const Icon(Icons.person),
                          label: const Text('MY SHORTS'),
                        ),
                      ),
                    ],
                  ),
                  if (_shortVideos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('No public Shorts yet. Be the first to publish.',
                          style: TextStyle(color: _muted, fontSize: 11)),
                    )
                  else
                    ..._shortVideos.map((video) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_fill, color: _gold, size: 30),
                      title: Text(
                        (video['caption'] ?? 'ZOONL Short').toString().isEmpty
                            ? 'ZOONL Short'
                            : (video['caption'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${video['duration_seconds']} sec • ${video['likes_count']} likes',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ShortVideoPlayerScreen(video: video),
                      )),
                    )),
                ],
              ),
            ),
            _sectionTitle('Live Now', trailing: 'REFRESH', onTap: _loadDashboard),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _gold)))
            else if (_error != null)
              _panelCard(
                child: Text('Dashboard data could not load: $_error', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              )
            else if (_rooms.isEmpty)
              _panelCard(
                child: const Row(
                  children: [
                    Icon(Icons.live_tv_outlined, color: _muted, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No public rooms are live right now. Approved Hosts can start a broadcast from this page.',
                        style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._rooms.map((room) {
                final audio = (room['room_type'] ?? '').toString().toLowerCase() == 'audio';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _panelCard(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _panelRaised,
                        child: Icon(audio ? Icons.graphic_eq : Icons.videocam_rounded, color: _gold),
                      ),
                      title: Text((room['room_name'] ?? 'ZOONL LIVE Room').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text('${audio ? 'Audio' : 'Video'}  •  ${room['viewer_count'] ?? 0} viewers', style: const TextStyle(color: _muted, fontSize: 11)),
                      trailing: const Icon(Icons.play_circle_fill_rounded, color: _teal, size: 30),
                      onTap: () => _joinRoom(room),
                    ),
                  ),
                );
              }),
            if (_privateInvites.isNotEmpty) ...[
              _sectionTitle('Private Live Invitations'),
              ..._privateInvites.map((invite) => _panelCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_person_rounded, color: _gold, size: 28),
                  title: Text('Private Live • ${invite['room_id']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Invitation expires in 10 minutes', style: TextStyle(color: _muted, fontSize: 11)),
                  trailing: Wrap(spacing: 2, children: [
                    IconButton(tooltip: 'Accept', onPressed: () => _respondPrivateInvite(invite, true),
                      icon: const Icon(Icons.check_circle, color: Colors.greenAccent)),
                    IconButton(tooltip: 'Decline', onPressed: () => _respondPrivateInvite(invite, false),
                      icon: const Icon(Icons.cancel, color: Colors.redAccent)),
                  ]),
                ),
              )),
            ],
            if (_guestInvites.isNotEmpty) ...[
              _sectionTitle('Guest Seat Invitations'),
              ..._guestInvites.map((invite) => _panelCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.video_call_rounded, color: _gold, size: 28),
                  title: Text('Room ${invite['room_id']} • Seat ${invite['seat_number']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${invite['is_video_enabled'] == true ? 'Video' : 'Audio only'} guest invitation',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Accept',
                        onPressed: () => _respondGuestInvite(invite, true),
                        icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        onPressed: () => _respondGuestInvite(invite, false),
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              )),
            ],
            _sectionTitle('Gift Collection'),
            if (_gifts.isEmpty && !_loading)
              _panelCard(child: const Text('Gift catalog is empty or unavailable.', style: TextStyle(color: _muted, fontSize: 12)))
            else
              _panelCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _gifts.map((gift) {
                    return Chip(
                      backgroundColor: _panelRaised,
                      side: const BorderSide(color: Color(0xFF354653)),
                      label: Text(
                        '${gift['gift_name']}  •  ${gift['coin_price']} Coins',
                        style: const TextStyle(color: _gold, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
              ),
            _sectionTitle('Platform Portals'),
            Row(
              children: [
                Expanded(
                  child: _portalButton(
                    icon: Icons.business_center_rounded,
                    title: 'AGENCY',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AgencyPortalScreen())),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _portalButton(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'OWNER / ADMIN',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RolePortalGateScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _portalButton(
              icon: Icons.settings_rounded,
              title: 'SETTINGS CENTER',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsCenterScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portalButton({required IconData icon, required String title, required VoidCallback onTap}) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF354653)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_right_rounded, color: _teal, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
