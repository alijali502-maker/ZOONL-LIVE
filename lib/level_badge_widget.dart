import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The profile badge reads the canonical wealth_levels design and the
/// authenticated user's server-calculated wealth level.
class ZoonlMiniLevelBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlMiniLevelBadge({super.key, this.onTap});

  @override
  State<ZoonlMiniLevelBadge> createState() => _ZoonlMiniLevelBadgeState();
}

class _LevelBadgeData {
  final int level;
  final int exp;
  final int nextExp;
  final String title;
  final String tier;
  final List<Color> gradient;
  final Color border;

  const _LevelBadgeData({
    required this.level,
    required this.exp,
    required this.nextExp,
    required this.title,
    required this.tier,
    required this.gradient,
    required this.border,
  });

  double get progress {
    if (level >= 100 || nextExp <= 0) return 1;
    return (exp / nextExp).clamp(0.0, 1.0).toDouble();
  }
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

  Color _readHex(String? raw, Color fallback) {
    if (raw == null) return fallback;
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw);
    if (match == null) return fallback;
    final value = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  List<Color> _readGradient(String? raw, int level) {
    final matches = RegExp(r'#[0-9a-fA-F]{6}').allMatches(raw ?? '');
    final colors = matches
        .map((m) => _readHex(m.group(0), const Color(0xFF8A5A22)))
        .toList(growable: false);
    if (colors.length >= 2) return colors;
    if (level >= 100) {
      return const [Color(0xFF312E81), Color(0xFFFBBF24), Color(0xFF34D399)];
    }
    if (level >= 10) {
      return const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF34D399)];
    }
    return const [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)];
  }

  Future<_LevelBadgeData> _loadLevel() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      return const _LevelBadgeData(
        level: 1, exp: 0, nextExp: 5000, title: 'Bronze Initiate',
        tier: 'Novice Bronze (1-5)',
        gradient: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
        border: Color(0xFFD97706),
      );
    }

    final results = await Future.wait<dynamic>([
      client.rpc('zoonl_my_level'),
      client.rpc('zoonl_my_lifetime_gift_exp'),
    ]);
    final levelValue = results[0];
    final expValue = results[1];
    final level = (levelValue is num ? levelValue.toInt() : 1)
        .clamp(1, 100).toInt();
    final exp = expValue is num ? expValue.toInt().clamp(0, 1 << 62).toInt() : 0;

    final currentRow = await client
        .from('wealth_levels')
        .select('title,tier_name,badge_gradient,badge_border,required_exp')
        .eq('level', level)
        .maybeSingle();
    final nextRow = level >= 100
        ? null
        : await client
            .from('wealth_levels')
            .select('required_exp')
            .eq('level', level + 1)
            .maybeSingle();

    final title = (currentRow?['title'] ?? 'Level $level').toString();
    final tier = (currentRow?['tier_name'] ?? '').toString();
    final nextExp = (nextRow?['required_exp'] as num?)?.toInt() ?? 0;
    return _LevelBadgeData(
      level: level,
      exp: exp,
      nextExp: nextExp,
      title: title,
      tier: tier,
      gradient: _readGradient(currentRow?['badge_gradient']?.toString(), level),
      border: _readHex(currentRow?['badge_border']?.toString(),
          const Color(0xFFD97706)),
    );
  }

  void _subscribeToOwnProfile() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId == _subscribedUserId) return;
    _subscribedUserId = userId;
    _profileSubscription = client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((_) {
          if (!mounted) return;
          setState(() => _levelFuture = _loadLevel());
        });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _levelFuture = _loadLevel());
    try {
      await _levelFuture;
    } catch (_) {
      // Keep the last usable badge layout; the next refresh can retry.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToOwnProfile();
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
        final data = snapshot.data ??
            const _LevelBadgeData(
              level: 1, exp: 0, nextExp: 5000,
              title: 'Bronze Initiate', tier: 'Novice Bronze (1-5)',
              gradient: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
              border: Color(0xFFD97706),
            );
        final pulse = .72 + ((_shine.value * 2 - 1).abs() * .28);
        return GestureDetector(
          onTap: () {
            widget.onTap?.call();
            _refresh();
          },
          child: AnimatedBuilder(
            animation: _shine,
            builder: (context, child) => Container(
              constraints: const BoxConstraints(minWidth: 92, maxWidth: 126),
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: data.gradient,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: data.border, width: 1.25),
                boxShadow: [
                  BoxShadow(
                    color: data.gradient.last.withOpacity(pulse * .58),
                    blurRadius: 13 + pulse * 4,
                    spreadRadius: .6,
                  ),
                  const BoxShadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.level >= 100
                            ? Icons.workspace_premium
                            : Icons.shield,
                        size: 14,
                        color: const Color(0xFFFFF0C2),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          data.level >= 100
                              ? 'OWNER 100'
                              : 'LEVEL ${data.level.toString().padLeft(2, '0')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFF4D6),
                            fontSize: 9,
                            letterSpacing: .45,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (data.level < 100) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: SizedBox(
                        height: 3,
                        width: double.infinity,
                        child: LinearProgressIndicator(
                          value: data.progress,
                          backgroundColor: Colors.black38,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFE7A0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
