import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Receiver progression is separate from sender Wealth Level.
/// Level thresholds and tier styling are read from Supabase.
class ZoonlCrownDemonBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlCrownDemonBadge({super.key, this.onTap});
  @override
  State<ZoonlCrownDemonBadge> createState() => _ZoonlCrownDemonBadgeState();
}

class _ZoonlCrownDemonBadgeState extends State<ZoonlCrownDemonBadge> {
  late Future<_TalentProgress> _future;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _future = _load();
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      _profileSubscription = client.from('profiles')
          .stream(primaryKey: ['id']).eq('id', userId).listen((_) {
        if (mounted) setState(() => _future = _load());
      });
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Color _hex(String? raw, Color fallback) {
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (match == null) return fallback;
    final value = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  List<Color> _colors(String? raw) {
    final values = RegExp(r'#[0-9a-fA-F]{6}')
        .allMatches(raw ?? '')
        .map((m) => _hex(m.group(0), const Color(0xFF8E4568)))
        .toList();
    return values.length >= 2
        ? values
        : const [Color(0xFF4A2339), Color(0xFF9B4567)];
  }

  Future<_TalentProgress> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const _TalentProgress(level: 1, tier: 1, exp: 0,
          currentExp: 0, nextExp: 0, gradient: [Color(0xFF4A2339), Color(0xFF9B4567)],
          border: Color(0xFFFFC5D2));
    }
    final values = await Future.wait<dynamic>([
      client.from('profiles').select('talent_exp,talent_level')
          .eq('id', user.id).maybeSingle(),
      client.from('talent_levels').select('level,tier,required_exp')
          .order('level'),
      client.from('wealth_levels')
          .select('tier_bracket,badge_gradient,badge_border')
          .order('level'),
    ]);
    final profile = values[0] as Map<String, dynamic>? ?? <String, dynamic>{};
    final exp = (profile['talent_exp'] as num?)?.toInt() ?? 0;
    final rows = (values[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final styles = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final raw in values[2] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final key = (row['tier_bracket'] ?? '').toString();
      if (key.isNotEmpty && seen.add(key)) styles.add(row);
    }
    Map<String, dynamic>? current;
    Map<String, dynamic>? next;
    for (final row in rows) {
      final threshold = (row['required_exp'] as num).toInt();
      if (threshold <= exp) current = row;
      if (threshold > exp && next == null) next = row;
    }
    final level = (current?['level'] as num?)?.toInt()
        ?? (profile['talent_level'] as num?)?.toInt() ?? 1;
    final tier = (current?['tier'] as num?)?.toInt() ?? 1;
    final style = styles.isEmpty ? <String, dynamic>{}
        : styles[(tier - 1).clamp(0, styles.length - 1).toInt()];
    return _TalentProgress(
      level: level,
      tier: tier,
      exp: exp,
      currentExp: (current?['required_exp'] as num?)?.toInt() ?? 0,
      nextExp: (next?['required_exp'] as num?)?.toInt() ?? 0,
      gradient: _colors(style['badge_gradient']?.toString()),
      border: _hex(style['badge_border']?.toString(), const Color(0xFFFFC5D2)),
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _future = _load());
    try { await _future; } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TalentProgress>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _TalentProgress(
          level: 1, tier: 1, exp: 0, currentExp: 0, nextExp: 0,
          gradient: [Color(0xFF4A2339), Color(0xFF9B4567)],
          border: Color(0xFFFFC5D2),
        );
        final progress = data.nextExp <= data.currentExp
            ? 1.0
            : ((data.exp - data.currentExp) / (data.nextExp - data.currentExp))
                .clamp(0.0, 1.0).toDouble();
        return GestureDetector(
          onTap: widget.onTap ?? () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('CROWN / DEMON PROGRESSION'),
              content: Text('Talent Level ${data.level} • Tier ${data.tier}\nReceived-gift EXP: ${data.exp}'),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE'))],
            ),
          ),
          child: Tooltip(
            message: 'Crown / Demon • Level ${data.level}',
            child: Container(
              width: 112,
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: data.gradient),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: data.border, width: 1),
                boxShadow: [BoxShadow(color: data.border.withOpacity(.20), blurRadius: 4)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspace_premium, size: 14, color: Color(0xFFFFD6A0)),
                const SizedBox(width: 4),
                Expanded(child: Text('CROWN ${data.level}',
                  maxLines: 1, overflow: TextOverflow.clip,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _TalentProgress {
  final int level;
  final int tier;
  final int exp;
  final int currentExp;
  final int nextExp;
  final List<Color> gradient;
  final Color border;
  const _TalentProgress({
    required this.level,
    required this.tier,
    required this.exp,
    required this.currentExp,
    required this.nextExp,
    required this.gradient,
    required this.border,
  });
}
