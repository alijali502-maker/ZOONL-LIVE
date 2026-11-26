import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Receiver progression is separate from sender Wealth Level.
/// Level thresholds and tier styling are read from Supabase.
class ZoonlCrownDemonBadge extends StatefulWidget {
  const ZoonlCrownDemonBadge({super.key});
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
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('CROWN / DEMON PROGRESSION'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Talent Level ${data.level} • Tier ${data.tier}'),
                  const SizedBox(height: 8),
                  Text('Received-gift EXP: ${data.exp}'),
                  const SizedBox(height: 6),
                  Text(data.nextExp > 0
                      ? '${data.nextExp - data.exp} EXP to the next level'
                      : 'Maximum level reached'),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  const Text('Receiving gifts increases Crown / Demon Talent Level. Sending gifts increases the separate User Wealth Level.'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
                TextButton(onPressed: () {
                  Navigator.pop(dialogContext);
                  _refresh();
                }, child: const Text('REFRESH')),
              ],
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 142, maxWidth: 190),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: data.gradient),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: data.border, width: 1.3),
              boxShadow: [BoxShadow(color: data.border.withOpacity(.3), blurRadius: 10)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, size: 17, color: Color(0xFFFFD6A0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CROWN / DEMON  ${data.level}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 3, value: progress,
                          backgroundColor: Colors.black38,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD6A0)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: SizedBox(width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ),
              ],
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
