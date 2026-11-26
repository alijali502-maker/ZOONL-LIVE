import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressionCenterScreen extends StatefulWidget {
  const ProgressionCenterScreen({super.key});
  @override
  State<ProgressionCenterScreen> createState() => _ProgressionCenterScreenState();
}

class _ProgressionCenterScreenState extends State<ProgressionCenterScreen> {
  late Future<_ProgressionData> _future;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_ProgressionData> _load() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final values = await Future.wait<dynamic>([
      db.from('profiles').select('wealth_exp,wealth_level,talent_exp,talent_level')
          .eq('id', user.id).maybeSingle(),
      db.from('wealth_levels').select('level,tier_bracket,tier_name,title,required_exp,is_milestone,frame_name,asset_url,motif,color_tier,glow_primary,glow_core,glow_accent')
          .order('level'),
      db.from('talent_levels').select('level,tier,required_exp,required_coins')
          .order('level'),
    ]);
    final profile = values[0] as Map<String, dynamic>? ?? <String, dynamic>{};
    return _ProgressionData(
      wealthExp: (profile['wealth_exp'] as num?)?.toInt() ?? 0,
      wealthLevel: (profile['wealth_level'] as num?)?.toInt() ?? 1,
      talentExp: (profile['talent_exp'] as num?)?.toInt() ?? 0,
      talentLevel: (profile['talent_level'] as num?)?.toInt() ?? 1,
      wealthRows: (values[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      talentRows: (values[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try { await _future; } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LEVEL & CROWN / DEMON'),
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.stars), text: 'USER LEVEL'),
            Tab(icon: Icon(Icons.workspace_premium), text: 'CROWN / DEMON'),
          ]),
        ),
        body: FutureBuilder<_ProgressionData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Progression data could not load: ${snapshot.error ?? 'No data'}'),
              ));
            }
            final data = snapshot.data!;
            return TabBarView(children: [
              _wealthPage(data),
              _talentPage(data),
            ]);
          },
        ),
      ),
    );
  }

  Widget _wealthPage(_ProgressionData data) {
    return _progressPage(
      title: 'USER LEVEL',
      subtitle: 'Earned by sending gifts. This counter belongs to the sender only.',
      level: data.wealthLevel,
      exp: data.wealthExp,
      rows: data.wealthRows,
      isWealth: true,
    );
  }

  Widget _talentPage(_ProgressionData data) {
    return _progressPage(
      title: 'CROWN / DEMON',
      subtitle: 'Earned by receiving gifts. This counter belongs to the receiver only.',
      level: data.talentLevel,
      exp: data.talentExp,
      rows: data.talentRows,
      isWealth: false,
    );
  }

  Widget _progressPage({
    required String title,
    required String subtitle,
    required int level,
    required int exp,
    required List<Map<String, dynamic>> rows,
    required bool isWealth,
  }) {
    Map<String, dynamic>? current;
    Map<String, dynamic>? next;
    for (final row in rows) {
      final rowLevel = (row['level'] as num).toInt();
      if (rowLevel == level) current = row;
      if (rowLevel > level && (next == null || rowLevel < (next['level'] as num).toInt())) next = row;
    }
    final currentExp = (current?['required_exp'] as num?)?.toInt() ?? 0;
    final nextExp = (next?['required_exp'] as num?)?.toInt() ?? currentExp;
    final progress = next == null ? 1.0 :
        ((exp - currentExp) / (nextExp - currentExp)).clamp(0.0, 1.0).toDouble();
    final groups = isWealth
        ? <List<int>>[[1,20],[21,40],[41,60],[61,80],[81,100]]
        : <List<int>>[[1,10],[11,20],[21,30],[31,40],[41,50]];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isWealth
                ? const [Color(0xFF3D2B58), Color(0xFF7655A0)]
                : const [Color(0xFF4A2339), Color(0xFF9B4567)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD9B979)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Color(0xFFFFE9B4), fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text('LEVEL $level', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            Text('${exp.toString()} EXP', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(minHeight: 8, value: progress,
                backgroundColor: Colors.black26,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFE4A0))),
            ),
            const SizedBox(height: 6),
            Text(next == null ? 'Maximum level reached' : '${nextExp - exp} EXP to Level ${(next['level'] as num).toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ),
        for (final range in groups)
          Card(
            color: const Color(0xFF171126),
            child: ExpansionTile(
              initiallyExpanded: level >= range[0] && level <= range[1],
              title: Text('LEVELS ${range[0]}–${range[1]}',
                style: const TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.w800)),
              children: rows.where((r) {
                final n = (r['level'] as num).toInt();
                return n >= range.$1 && n <= range.$2;
              }).map((row) {
                final n = (row['level'] as num).toInt();
                final requiredExp = (row['required_exp'] as num).toInt();
                final active = n == level;
                return ListTile(
                  dense: true,
                  leading: Icon(active ? Icons.check_circle : Icons.lock_outline,
                    color: active ? const Color(0xFFFFD77A) : Colors.white38, size: 18),
                  title: Text(isWealth
                      ? (row['title'] ?? 'Level $n').toString()
                      : 'Crown / Demon Level $n • Tier ${row['tier']}',
                    style: TextStyle(color: active ? const Color(0xFFFFE6A6) : Colors.white70,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w500, fontSize: 12)),
                  subtitle: Text(isWealth && row['frame_name'] != null
                      ? '${requiredExp.toString()} EXP required • Profile Frame: ${row['frame_name']}'
                      : '${requiredExp.toString()} EXP required',
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  trailing: isWealth && row['frame_name'] != null
                    ? Icon(Icons.crop_portrait, size: 19,
                        color: active ? const Color(0xFFFFD77A) : const Color(0xFFB78BFA))
                    : (active ? const Text('CURRENT',
                        style: TextStyle(color: Color(0xFFFFD77A), fontSize: 9, fontWeight: FontWeight.w900)) : null),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ProgressionData {
  final int wealthExp, wealthLevel, talentExp, talentLevel;
  final List<Map<String, dynamic>> wealthRows, talentRows;
  const _ProgressionData({
    required this.wealthExp, required this.wealthLevel,
    required this.talentExp, required this.talentLevel,
    required this.wealthRows, required this.talentRows,
  });
}
