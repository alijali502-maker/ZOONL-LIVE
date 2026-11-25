import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelHistoryScreen extends StatefulWidget {
  const LevelHistoryScreen({super.key});

  @override
  State<LevelHistoryScreen> createState() => _LevelHistoryScreenState();
}

class _LevelHistoryScreenState extends State<LevelHistoryScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  late Future<_LevelPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LevelPageData> _load() async {
    final values = await Future.wait<dynamic>([
      _db.rpc('zoonl_my_level'),
      _db.rpc('zoonl_my_lifetime_gift_exp'),
      _db.from('wealth_levels')
          .select('level,title,tier_name,required_exp,badge_gradient,badge_border,unlocked_perk')
          .order('level'),
      _db.from('gift_sends')
          .select('id,gift_id,quantity,total_coins,created_at')
          .order('created_at', ascending: false)
          .limit(100),
    ]);
    final level = (values[0] is num ? (values[0] as num).toInt() : 1)
        .clamp(1, 100).toInt();
    final exp = values[1] is num ? (values[1] as num).toInt() : 0;
    final levels = (values[2] as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final history = (values[3] as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return _LevelPageData(level, exp, levels, history);
  }

  Color _color(String? raw, Color fallback) {
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (match == null) return fallback;
    final n = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return n == null ? fallback : Color(0xFF000000 | n);
  }

  List<Color> _colors(String? raw, int level) {
    final result = RegExp(r'#[0-9a-fA-F]{6}').allMatches(raw ?? '')
        .map((m) => _color(m.group(0), const Color(0xFFD6B46A))).toList();
    if (result.length >= 2) return result;
    return level >= 100
        ? const [Color(0xFFFFF1B8), Color(0xFFD6A63D), Color(0xFF754515)]
        : const [Color(0xFF5D3A91), Color(0xFFB78BFA)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080611),
      appBar: AppBar(
        backgroundColor: const Color(0xFF100C1D),
        title: const Text('WEALTH LEVELS & HISTORY',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_LevelPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, color: Colors.white54, size: 36),
                const SizedBox(height: 10),
                const Text('Level data could not be loaded.',
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('RETRY'),
                ),
              ]),
            ));
          }
          final data = snapshot.data!;
          final next = data.level >= 100 ? null : data.levels.firstWhere(
            (r) => (r['level'] as num).toInt() == data.level + 1,
            orElse: () => <String, dynamic>{},
          );
          final nextExp = (next?['required_exp'] as num?)?.toInt() ?? 0;
          final progress = data.level >= 100 || nextExp <= 0
              ? 1.0 : (data.exp / nextExp).clamp(0.0, 1.0).toDouble();
          return RefreshIndicator(
            onRefresh: () async { setState(() => _future = _load()); await _future; },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _colors(
                      data.levels[data.level - 1]['badge_gradient']?.toString(),
                      data.level)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD6B46A), width: 1.5),
                    boxShadow: const [BoxShadow(color: Color(0x665D3A91), blurRadius: 18)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('YOUR CURRENT WEALTH LEVEL',
                        style: TextStyle(color: Colors.white70, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _medal(data.level, data.levels[data.level - 1]['badge_gradient']?.toString()),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('LEVEL ${data.level}',
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                        Text((data.levels[data.level - 1]['title'] ?? '').toString(),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${data.exp} EXP',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                    const SizedBox(height: 15),
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: progress, minHeight: 8,
                        backgroundColor: Colors.black38,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFE9A5)))),
                    const SizedBox(height: 7),
                    Text(data.level >= 100 ? 'Maximum level reached'
                        : '${(nextExp - data.exp).clamp(0, nextExp)} EXP to Level ${data.level + 1}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 22),
                const Text('ALL 100 LEVEL BADGES',
                    style: TextStyle(color: Color(0xFFE6C47A),
                        fontWeight: FontWeight.w900, letterSpacing: .8)),
                const SizedBox(height: 10),
                for (final row in data.levels)
                  _levelRow(row, data.level),
                const SizedBox(height: 22),
                const Text('GIFT & EXP HISTORY',
                    style: TextStyle(color: Color(0xFFE6C47A),
                        fontWeight: FontWeight.w900, letterSpacing: .8)),
                const SizedBox(height: 8),
                if (data.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No gift transactions recorded yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  )
                else
                  for (final item in data.history)
                    Card(
                      color: const Color(0xFF171126),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF302044),
                          child: Icon(Icons.card_giftcard, color: Color(0xFFE6C47A)),
                        ),
                        title: Text('Gift sent • ${item['quantity'] ?? 1} item(s)'),
                        subtitle: Text(DateTime.parse(item['created_at'].toString())
                            .toLocal().toString().substring(0, 16)),
                        trailing: Text('${item['total_coins'] ?? 0} coins',
                            style: const TextStyle(color: Color(0xFFE6C47A),
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _medal(int level, String? gradient) => Container(
    width: 76, height: 76,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: _colors(gradient, level)),
      border: Border.all(color: const Color(0xFFFFE9A5), width: 2.5),
      boxShadow: const [BoxShadow(color: Color(0x99D6A63D), blurRadius: 14)],
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.workspace_premium, size: 20, color: Color(0xFFFFF4D0)),
      Text('$level', style: const TextStyle(fontSize: 25, height: 1,
          fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _levelRow(Map<String, dynamic> row, int currentLevel) {
    final level = (row['level'] as num).toInt();
    final unlocked = level <= currentLevel;
    final gradient = _colors(row['badge_gradient']?.toString(), level);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF171126),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: unlocked ? const Color(0xFFD6B46A) : Colors.white12),
      ),
      child: Row(children: [
        Container(
          width: 43, height: 43,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: gradient),
            border: Border.all(color: const Color(0xFFD6B46A))),
          child: Center(child: Text('$level',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((row['title'] ?? 'Level $level').toString(),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Text((row['tier_name'] ?? '').toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text('Required EXP: ${row['required_exp'] ?? 0}',
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          if ((row['unlocked_perk'] ?? '').toString().isNotEmpty)
            Text(row['unlocked_perk'].toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE6C47A), fontSize: 10)),
        ])),
        Icon(unlocked ? Icons.verified : Icons.lock_outline,
            color: unlocked ? const Color(0xFFE6C47A) : Colors.white30, size: 19),
      ]),
    );
  }
}

class _LevelPageData {
  final int level;
  final int exp;
  final List<Map<String, dynamic>> levels;
  final List<Map<String, dynamic>> history;
  const _LevelPageData(this.level, this.exp, this.levels, this.history);
}
