import 'package:flutter/material.dart';

import 'core/backend.dart';
import 'lib/features/live_screen.dart';
import 'role_portals_screen.dart';
import 'settings_center_screen.dart';

class FeatureHubScreen extends StatefulWidget {
  const FeatureHubScreen({super.key});

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

  // 1-50 Talent / Gift Progression Tiers (ہر 5 لیول پر نیا رنگ اور شیپ)
  static const List> _talentTiers = [
    {'tier': 1, 'min': 1, 'max': 5, 'name': 'Rose Heart', 'shape': 'heart', 'pill': Color(0xFFC81E4E), 'gradA': Color(0xFFFB7185), 'gradB': Color(0xFFE11D48), 'rim': Color(0xFFFDE047)},
    {'tier': 2, 'min': 6, 'max': 10, 'name': 'Sky Diamond', 'shape': 'diamond', 'pill': Color(0xFF0369A1), 'gradA': Color(0xFF38BDF8), 'gradB': Color(0xFF0284C7), 'rim': Color(0xFFFDE047)},
    {'tier': 3, 'min': 11, 'max': 15, 'name': 'Emerald Diamond', 'shape': 'diamond', 'pill': Color(0xFF047857), 'gradA': Color(0xFF34D399), 'gradB': Color(0xFF059669), 'rim': Color(0xFFFDE047)},
    {'tier': 4, 'min': 16, 'max': 20, 'name': 'Crimson Crown', 'shape': 'crown', 'pill': Color(0xFFB91C1C), 'gradA': Color(0xFFF87171), 'gradB': Color(0xFFDC2626), 'rim': Color(0xFFFBBF24)},
    {'tier': 5, 'min': 21, 'max': 25, 'name': 'Violet Crown', 'shape': 'crown', 'pill': Color(0xFF6D28D9), 'gradA': Color(0xFFA78BFA), 'gradB': Color(0xFF7C3AED), 'rim': Color(0xFFFBBF24)},
    {'tier': 6, 'min': 26, 'max': 30, 'name': 'Amber Gold Crown', 'shape': 'crown', 'pill': Color(0xFFB45309), 'gradA': Color(0xFFFBBF24), 'gradB': Color(0xFFB45309), 'rim': Color(0xFFFEF08A)},
    {'tier': 7, 'min': 31, 'max': 35, 'name': 'Sapphire Crown', 'shape': 'crown', 'pill': Color(0xFF1D4ED8), 'gradA': Color(0xFF60A5FA), 'gradB': Color(0xFF1D4ED8), 'rim': Color(0xFFFDE047)},
    {'tier': 8, 'min': 36, 'max': 40, 'name': 'Ruby Crown', 'shape': 'crown', 'pill': Color(0xFF9F1239), 'gradA': Color(0xFFFB7185), 'gradB': Color(0xFF9F1239), 'rim': Color(0xFFFBBF24)},
    {'tier': 9, 'min': 41, 'max': 45, 'name': 'Obsidian Crown', 'shape': 'crown', 'pill': Color(0xFF334155), 'gradA': Color(0xFF94A3B8), 'gradB': Color(0xFF1E293B), 'rim': Color(0xFFE2E8F0)},
    {'tier': 10, 'min': 46, 'max': 50, 'name': 'Celestial Crown', 'shape': 'crown', 'pill': Color(0xFF5B21B6), 'gradA': Color(0xFFC084FC), 'gradB': Color(0xFF6D28D9), 'rim': Color(0xFFFEF08A)},
  ];

  // 1-100 User Level Tiger Colors (ہر 5 لیول پر رنگ بدلتا ہے)
  static const List<Color> _userLevelColors = [
    Color(0xFFD6B46A),
    Color(0xFF4BC2B0),
    Color(0xFF38BDF8),
    Color(0xFFA78BFA),
    Color(0xFFFB7185),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFFF97316),
    Color(0xFF60A5FA),
    Color(0xFFE879F9),
  ];

  bool _loading = true;
  bool _canHost = false;
  bool _sendingGift = false;
  String? _error;
  Map<String, dynamic> _profile = {};
  List> _rooms = [];
  List> _gifts = [];
  List> _talentLevels = [];
  List> _userLevels = [];

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

  Map<String, dynamic> _tierForTalentLevel(int level) {
    final clamped = level.clamp(1, 50);
    final index = ((clamped - 1) ~/ 5).clamp(0, _talentTiers.length - 1);
    return _talentTiers[index];
  }

  Color _colorForUserLevel(int level) {
    final clamped = level.clamp(1, 100);
    final idx = ((clamped - 1) ~/ 5) % _userLevelColors.length;
    return _userLevelColors[idx];
  }

  IconData _shapeIcon(String shape) {
    if (shape == 'heart') return Icons.favorite;
    if (shape == 'diamond') return Icons.diamond;
    return Icons.workspace_premium;
  }

  int _requiredExpForTalentLevel(int level) {
    final clamped = level.clamp(1, 50);
    for (final row in _talentLevels) {
      final lvl = (row['level'] as num?)?.toInt() ?? 0;
      if (lvl == clamped) {
        return (row['required_exp'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  Map<String, dynamic>? _userLevelRow(int level) {
    final clamped = level.clamp(1, 100);
    for (final row in _userLevels) {
      final lvl = (row['level'] as num?)?.toInt() ?? 0;
      if (lvl == clamped) return row;
    }
    return null;
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
          .select('username, display_name, avatar_url, user_level, is_verified, talent_exp, talent_level, gift_send_exp')
          .eq('id', userId)
          .maybeSingle();

      final owner = await Backend.isZoonlOwner();
      final roomsRaw = await Backend.client
          .from('live_rooms')
          .select('id, owner_id, room_name, room_type, viewer_count, is_private, is_locked')
          .eq('is_live', true)
          .eq('is_private', false)
          .eq('is_locked', false)
          .order('created_at', ascending: false)
          .limit(30);

      final giftsRaw = await Backend.client
          .from('gifts')
          .select('id, gift_name, coin_price')
          .eq('is_active', true)
          .order('coin_price', ascending: true)
          .limit(8);

      final levelsRaw = await Backend.client
          .from('talent_levels')
          .select('level, tier, required_exp, required_coins')
          .order('level', ascending: true);

      List> parsedUserLevels = [];
      try {
        final userLvlRaw = await Backend.client
            .from('wealth_levels')
            .select()
            .order('level', ascending: true);
        parsedUserLevels = (userLvlRaw as List).map((row) => _map(row)).toList();
      } catch (_) {
        parsedUserLevels = [];
      }

      if (!mounted) return;
      setState(() {
        _profile = _map(profile);
        _canHost = owner || profile?['is_verified'] == true;
        _rooms = (roomsRaw as List)
            .map((row) => _map(row))
            .toList();
        _gifts = (giftsRaw as List)
            .map((row) => _map(row))
            .toList();
        _talentLevels = (levelsRaw as List)
            .map((row) => _map(row))
            .toList();
        _userLevels = parsedUserLevels;
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

  Future<void> _sendGiftAndUpdateExp(Map<String, dynamic> gift) async {
    if (_sendingGift) return;
    final senderId = Backend.currentUserId;
    if (senderId == null) {
      _notice('Login required.');
      return;
    }

    final coins = (gift['coin_price'] as num?)?.toInt() ?? 0;
    if (coins <= 0) {
      _notice('Invalid gift coin price.');
      return;
    }

    final receiverId = _rooms.isNotEmpty && _rooms.first['owner_id'] != null
        ? _rooms.first['owner_id']
        : senderId;

    setState(() => _sendingGift = true);
    try {
      await Backend.client.rpc('process_gift_exp', params: {
        'p_sender_id': senderId,
        'p_receiver_id': receiverId,
        'p_coins': coins,
      });
      _notice('Sent ${gift['gift_name']} (+$coins EXP)');
      await _loadDashboard();
    } catch (error) {
      _notice('Gift EXP update failed: $error');
    } finally {
      if (mounted) {
        setState(() => _sendingGift = false);
      }
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
          userId: (_profile['username'] ?? '').toString(),
          roomType: roomType,
        ),
      ),
    );
    _loadDashboard();
  }

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveScreen(
          userName: (_profile['display_name'] ?? 'ZOONL User').toString(),
          userId: (_profile['username'] ?? '').toString(),
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

  Widget _avatarWithTalentFrame({
    required String? avatarUrl,
    required int talentLevel,
  }) {
    final tier = _tierForTalentLevel(talentLevel);
    final Color pillColor = tier['pill'] as Color;
    final Color gradA = tier['gradA'] as Color;
    final Color gradB = tier['gradB'] as Color;
    final Color rimColor = tier['rim'] as Color;
    final String shape = tier['shape'] as String;

    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [gradA, gradB]),
              border: Border.all(color: rimColor, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: pillColor.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: _panelRaised,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.white, size: 28)
                : null,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_shapeIcon(shape), color: Colors.white, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    'Lv.$talentLevel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userLevelCard({required int userLevel}) {
    final safeLvl = userLevel.clamp(1, 100);
    final badgeColor = _colorForUserLevel(safeLvl);
    final dbRow = _userLevelRow(safeLvl);
    final extraInfo = dbRow != null ? ' • DB Matched' : '';

    return _panelCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_rounded, color: badgeColor, size: 16),
                const SizedBox(width: 5),
                Text(
                  'User Lv.$safeLvl',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'User Level System (1–100)$extraInfo',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _talentProgressionSection({
    required int talentLevel,
    required int talentExp,
    required int giftSendExp,
  }) {
    final currentTier = _tierForTalentLevel(talentLevel);
    final currentFloor = _requiredExpForTalentLevel(talentLevel);
    final nextLvl = talentLevel < 50 ? talentLevel + 1 : 50;
    final nextTarget = _requiredExpForTalentLevel(nextLvl);

    double progress = 1.0;
    if (talentLevel < 50 && nextTarget > currentFloor) {
      progress = ((talentExp - currentFloor) / (nextTarget - currentFloor)).clamp(0.0, 1.0);
    }

    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: currentTier['pill'] as Color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_shapeIcon(currentTier['shape'] as String), color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'Lv.$talentLevel • ${currentTier['name']}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'EXP: $talentExp',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sent EXP: $giftSendExp  •  Next Lv.$nextLvl: $nextTarget EXP',
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: _panelRaised,
              valueColor: AlwaysStoppedAnimation<Color>(currentTier['pill'] as Color),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 50,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final lvl = idx + 1;
                final t = _tierForTalentLevel(lvl);
                final req = _requiredExpForTalentLevel(lvl);
                final unlocked = talentExp >= req;

                return Container(
                  width: 86,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _panelRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: lvl == talentLevel
                          ? (t['pill'] as Color)
                          : const Color(0xFF354653),
                      width: lvl == talentLevel ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: t['pill'] as Color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_shapeIcon(t['shape'] as String), color: Colors.white, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              'Lv.$lvl',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        unlocked ? 'Unlocked' : 'Locked',
                        style: TextStyle(
                          color: unlocked ? _teal : _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Exp:$req',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profile['display_name'] ?? 'ZOONL Member').toString();
    final publicId = (_profile['username'] ?? '').toString();
    final avatarUrl = _profile['avatar_url']?.toString();
    final userLevel = (_profile['user_level'] as num?)?.toInt() ?? 1;
    final talentExp = (_profile['talent_exp'] as num?)?.toInt() ?? 0;
    final talentLevel = (_profile['talent_level'] as num?)?.toInt() ?? 1;
    final giftSendExp = (_profile['gift_send_exp'] as num?)?.toInt() ?? 0;

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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _avatarWithTalentFrame(
                        avatarUrl: avatarUrl,
                        talentLevel: talentLevel,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $name',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'User ID: ${publicId.isEmpty ? 'Not assigned' : publicId}  •  User Lv.$userLevel  •  Talent Lv.$talentLevel',
                              style: const TextStyle(color: _muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _canHost ? () => _startLive(roomType: 'video') : null,
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('VIDEO LIVE'),
                          style: FilledButton.styleFrom(backgroundColor: _teal, foregroundColor: const Color(0xFF071713)),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _canHost ? () => _startLive(roomType: 'audio') : null,
                          icon: const Icon(Icons.mic_rounded),
                          label: const Text('AUDIO LIVE'),
                        ),
                      ),
                    ],
                  ),
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
            _sectionTitle('User Level (1–100)'),
            _userLevelCard(userLevel: userLevel),
            _sectionTitle('Talent & Gift Progression (1–50)'),
            _talentProgressionSection(
              talentLevel: talentLevel,
              talentExp: talentExp,
              giftSendExp: giftSendExp,
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
            _sectionTitle('Gift Collection'),
            if (_gifts.isEmpty && !_loading)
              _panelCard(child: const Text('Gift catalog is empty or unavailable.', style: TextStyle(color: _muted, fontSize: 12)))
            else
              _panelCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _gifts.map((gift) {
                    return ActionChip(
                      backgroundColor: _panelRaised,
                      side: const BorderSide(color: Color(0xFF354653)),
                      onPressed: _sendingGift ? null : () => _sendGiftAndUpdateExp(gift),
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
