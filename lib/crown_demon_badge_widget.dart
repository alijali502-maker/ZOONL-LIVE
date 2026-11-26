import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Receiver progression is independent from sender Wealth Level.
class ZoonlCrownDemonBadge extends StatefulWidget {
  const ZoonlCrownDemonBadge({super.key});
  @override
  State<ZoonlCrownDemonBadge> createState() => _ZoonlCrownDemonBadgeState();
}

class _ZoonlCrownDemonBadgeState extends State<ZoonlCrownDemonBadge> {
  late Future<_TalentProgress> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TalentProgress> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const _TalentProgress(level: 1, tier: 1, exp: 0, currentExp: 0, nextExp: 0);
    }
    final profile = await client.from('profiles')
        .select('talent_exp,talent_level').eq('id', user.id).maybeSingle();
    final exp = (profile?['talent_exp'] as num?)?.toInt() ?? 0;
    final currentRows = await client.from('talent_levels')
        .select('level,tier,required_exp').lte('required_exp', exp)
        .order('required_exp', ascending: false).limit(1);
    final nextRows = await client.from('talent_levels')
        .select('required_exp').gt('required_exp', exp)
        .order('required_exp', ascending: true).limit(1);
    final current = currentRows.isEmpty ? <String, dynamic>{} : currentRows.first;
    final next = nextRows.isEmpty ? null : nextRows.first;
    return _TalentProgress(
      level: (current['level'] as num?)?.toInt() ??
          (profile?['talent_level'] as num?)?.toInt() ?? 1,
      tier: (current['tier'] as num?)?.toInt() ?? 1,
      exp: exp,
      currentExp: (current['required_exp'] as num?)?.toInt() ?? 0,
      nextExp: (next?['required_exp'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try { await _future; } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TalentProgress>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ??
            const _TalentProgress(level: 1, tier: 1, exp: 0, nextExp: 0);
        final progress = data.nextExp <= 0
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
                  const Text('This progression increases when this account receives gifts. It does not change the sender Wealth Level.'),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF431D32), Color(0xFF8E3048), Color(0xFF4A263B)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC5D2), width: 1.2),
              boxShadow: const [BoxShadow(color: Color(0x55E65C85), blurRadius: 9)],
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
                          minHeight: 3,
                          value: progress,
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
  const _TalentProgress({
    required this.level,
    required this.tier,
    required this.exp,
    required this.nextExp,
  });
}
