import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talent progression badge: same five-level heart/diamond/crown tiers as FeatureHub.
class ZoonlCrownDemonBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlCrownDemonBadge({super.key, this.onTap});
  @override
  State<ZoonlCrownDemonBadge> createState() => _ZoonlCrownDemonBadgeState();
}

class _TalentProgress {
  final int level, exp, currentExp, nextExp;
  final String tierName;
  final Color pill, gradA, gradB, rim;
  final IconData icon;
  const _TalentProgress({
    required this.level, required this.exp, required this.currentExp,
    required this.nextExp, required this.tierName, required this.pill,
    required this.gradA, required this.gradB, required this.rim,
    required this.icon,
  });
}

class _ZoonlCrownDemonBadgeState extends State<ZoonlCrownDemonBadge> {
  late Future<_TalentProgress> _future;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _future = _load();
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      _subscription = client.from('profiles').stream(primaryKey: ['id'])
          .eq('id', uid).listen((_) {
        if (mounted) setState(() => _future = _load());
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  _TalentProgress _styleFor(int level, int exp, int current, int next) {
    final safe = level.clamp(1, 50).toInt();
    final tier = (safe - 1) ~/ 5;
    const palettes = <List<Color>>[
      [Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFFFDE047)],
      [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFFFDE047)],
      [Color(0xFF34D399), Color(0xFF059669), Color(0xFFFDE047)],
      [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFFFBBF24)],
      [Color(0xFFA78BFA), Color(0xFF7C3AED), Color(0xFFFBBF24)],
      [Color(0xFFFBBF24), Color(0xFFB45309), Color(0xFFFEF08A)],
      [Color(0xFF60A5FA), Color(0xFF1D4ED8), Color(0xFFFDE047)],
      [Color(0xFFFB7185), Color(0xFF9F1239), Color(0xFFFBBF24)],
      [Color(0xFF94A3B8), Color(0xFF1E293B), Color(0xFFE2E8F0)],
      [Color(0xFFC084FC), Color(0xFF6D28D9), Color(0xFFFEF08A)],
    ];
    const names = <String>[
      'Rose Heart', 'Sky Diamond', 'Emerald Diamond', 'Crimson Crown',
      'Violet Crown', 'Amber Gold Crown', 'Sapphire Crown', 'Ruby Crown',
      'Obsidian Crown', 'Celestial Crown',
    ];
    final p = palettes[tier];
    final icon = tier == 0 ? Icons.favorite
        : (tier == 1 || tier == 2) ? Icons.diamond
        : Icons.workspace_premium;
    return _TalentProgress(
      level: safe, exp: exp, currentExp: current, nextExp: next,
      tierName: names[tier], pill: p[1], gradA: p[0], gradB: p[1],
      rim: p[2], icon: icon,
    );
  }

  Future<_TalentProgress> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return _styleFor(1, 0, 0, 0);
    final values = await Future.wait<dynamic>([
      client.from('profiles').select('talent_exp,talent_level')
          .eq('id', user.id).maybeSingle(),
      client.from('talent_levels').select('level,required_exp')
          .order('level', ascending: true),
    ]);
    final profile = values[0] as Map<String, dynamic>? ?? {};
    final exp = (profile['talent_exp'] as num?)?.toInt() ?? 0;
    final rows = (values[1] as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    Map<String, dynamic>? current;
    Map<String, dynamic>? next;
    for (final row in rows) {
      final threshold = (row['required_exp'] as num?)?.toInt() ?? 0;
      if (threshold <= exp) current = row;
      if (threshold > exp && next == null) next = row;
    }
    final dbLevel = (current?['level'] as num?)?.toInt();
    final profileLevel = (profile['talent_level'] as num?)?.toInt() ?? 1;
    final level = (dbLevel ?? profileLevel).clamp(1, 50).toInt();
    final currentExp = (current?['required_exp'] as num?)?.toInt() ?? 0;
    final nextExp = (next?['required_exp'] as num?)?.toInt() ?? currentExp;
    return _styleFor(level, exp, currentExp, nextExp);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TalentProgress>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _styleFor(1, 0, 0, 0);
        return GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: 'Talent ${data.level} • ${data.tierName} • EXP ${data.exp}',
            child: Container(
              height: 27,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [data.gradA, data.gradB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: data.rim, width: 1.2),
                boxShadow: [BoxShadow(color: data.pill.withOpacity(.35), blurRadius: 7)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(data.icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('Lv.${data.level}', style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900,
                )),
                if (snapshot.connectionState == ConnectionState.waiting) ...[
                  const SizedBox(width: 5),
                  const SizedBox(width: 8, height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white)),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }
}
