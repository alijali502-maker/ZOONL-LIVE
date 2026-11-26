import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ZoonlMiniLevelBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlMiniLevelBadge({super.key, this.onTap});

  @override
  State<ZoonlMiniLevelBadge> createState() => _ZoonlMiniLevelBadgeState();
}

class _LevelBadgeData {
  final int level;
  final int exp;
  final int currentExp;
  final int nextExp;
  final String title;
  final List<Color> gradient;
  final Color border;

  const _LevelBadgeData({
    required this.level,
    required this.exp,
    required this.currentExp,
    required this.nextExp,
    required this.title,
    required this.gradient,
    required this.border,
  });

  double get progress => level >= 100 || nextExp <= currentExp
      ? 1
      : ((exp - currentExp) / (nextExp - currentExp)).clamp(0.0, 1.0).toDouble();
}

class _ZoonlMiniLevelBadgeState extends State<ZoonlMiniLevelBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late Future<_LevelBadgeData> _levelFuture;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  String? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    _levelFuture = _loadLevel();
    _subscribeToOwnProfile();
  }

  Color _hex(String? raw, Color fallback) {
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (match == null) return fallback;
    final value = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  List<Color> _gradient(String? raw, int level) {
    final colors = RegExp(r'#[0-9a-fA-F]{6}')
        .allMatches(raw ?? '')
        .map((m) => _hex(m.group(0), const Color(0xFFD6B46A)))
        .toList();
    if (colors.length >= 2) return colors;
    return level >= 100
        ? const [Color(0xFFFFF1B8), Color(0xFFD6A63D), Color(0xFF754515)]
        : const [Color(0xFF5D3A91), Color(0xFFB78BFA), Color(0xFF35205B)];
  }

  Future<_LevelBadgeData> _loadLevel() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      return const _LevelBadgeData(
        level: 1, exp: 0, currentExp: 0, nextExp: 0, title: 'LEVEL 01',
        gradient: [Color(0xFF5D3A91), Color(0xFFB78BFA)],
        border: Color(0xFFD6B46A),
      );
    }
    final values = await Future.wait<dynamic>([
      client.rpc('zoonl_my_level'),
      client.rpc('zoonl_my_lifetime_gift_exp'),
    ]);
    final level = (values[0] is num ? (values[0] as num).toInt() : 1)
        .clamp(1, 100).toInt();
    final exp = values[1] is num ? (values[1] as num).toInt() : 0;
    final current = await client.from('wealth_levels')
        .select('level,tier_bracket,tier_name,title,required_exp,badge_gradient,badge_border,badge_glow,chat_ribbon_theme,chat_ribbon_bg,chat_ribbon_border,chat_ribbon_shadow,unlocked_perk,is_milestone')
        .eq('level', level).maybeSingle();
    final next = level == 100 ? null : await client.from('wealth_levels')
        .select('required_exp').eq('level', level + 1).maybeSingle();
    return _LevelBadgeData(
      level: level,
      exp: exp,
      currentExp: (current?['required_exp'] as num?)?.toInt() ?? 0,
      nextExp: (next?['required_exp'] as num?)?.toInt() ?? 0,
      title: (current?['title'] ?? 'LEVEL $level').toString(),
      gradient: _gradient(current?['badge_gradient']?.toString(), level),
      border: _hex(current?['badge_border']?.toString(),
          const Color(0xFFD6B46A)),
    );
  }

  void _subscribeToOwnProfile() {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || uid == _subscribedUserId) return;
    _subscribedUserId = uid;
    _profileSubscription = client.from('profiles')
        .stream(primaryKey: ['id']).eq('id', uid).listen((_) {
      if (mounted) setState(() => _levelFuture = _loadLevel());
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _levelFuture = _loadLevel());
    try { await _levelFuture; } catch (_) {}
  }


  @override
  void dispose() {
    _profileSubscription?.cancel();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LevelBadgeData>(
      future: _levelFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _LevelBadgeData(
          level: 1, exp: 0, currentExp: 0, nextExp: 0, title: 'LEVEL 01',
          gradient: [Color(0xFF5D3A91), Color(0xFFB78BFA)],
          border: Color(0xFFD6B46A),
        );
        final colors = data.gradient;
        final isApex = data.level >= 100;
        return GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: 'Level ${data.level} • ${data.title}',
            child: Container(
              width: 104,
              height: 27,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isApex ? const Color(0xFFFFE28A) : data.border,
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(color: data.border.withOpacity(.22), blurRadius: 5),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFE7A0), size: 15),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('LV ${data.level}',
                      maxLines: 1, overflow: TextOverflow.clip,
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                        height: 1, fontWeight: FontWeight.w900)),
                  ),
                  if (isApex)
                    const Icon(Icons.diamond, size: 12, color: Color(0xFFFFF0B0)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
