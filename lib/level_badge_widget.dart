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
          level: 1, exp: 0, nextExp: 0, title: 'LEVEL 01',
          gradient: [Color(0xFF5D3A91), Color(0xFFB78BFA)],
          border: Color(0xFFD6B46A),
        );
        final colors = data.gradient;
        final isApex = false;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _shine,
            builder: (context, _) {
              final glow = .35 + (_shine.value * .65);
              return Tooltip(
                message: 'Level ${data.level} • ${data.title}',
                child: Container(
                  constraints: const BoxConstraints(minWidth: 142, maxWidth: 190),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: colors,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isApex ? const Color(0xFFFFE28A) : data.border,
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isApex ? const Color(0xFFFFC94D) : data.border)
                            .withOpacity(glow * .55),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF1B8), Color(0xFFD69B27), Color(0xFF70420F)],
                          ),
                          border: Border.all(color: const Color(0xFFFFF4C7), width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0x99FFD65A), blurRadius: 7),
                          ],
                        ),
                        child: const Icon(Icons.stars, color: Color(0xFF40220A), size: 19),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LV ${data.level}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                value: data.progress,
                                backgroundColor: Colors.black45,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFF0B0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (data.level >= 96) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.diamond, size: 14, color: Color(0xFFFFF0B0)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
