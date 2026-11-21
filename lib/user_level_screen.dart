import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/zoonl_theme.dart';

class UserLevelScreen extends StatefulWidget {
  const UserLevelScreen({super.key});
  @override
  State<UserLevelScreen> createState() => _UserLevelScreenState();
}

class _UserLevelScreenState extends State<UserLevelScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  int _level = 1;
  int _sentCoins = 0;
  List<Map<String, dynamic>> _levels = <Map<String, dynamic>>[];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      setState(() { _loading = false; _error = 'Login required.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final myLevel = await _db.rpc('zoonl_my_level');
      final sentRows = await _db.from('gift_sends')
          .select('total_coins').eq('sender_id', user.id);
      final levelRows = await _db.from('level_definitions')
          .select('level,required_exp,level_name').order('level');
      final sent = (sentRows as List).fold<int>(0, (sum, row) =>
        sum + ((row['total_coins'] as num?)?.toInt() ?? 0));
      if (!mounted) return;
      setState(() {
        _level = (myLevel as num?)?.toInt() ?? 1;
        _sentCoins = sent;
        _levels = (levelRows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? current;
    Map<String, dynamic>? next;
    for (final row in _levels) {
      final rowLevel = (row['level'] as num).toInt();
      if (rowLevel == _level) current = row;
      if (rowLevel > _level && next == null) next = row;
    }
    final currentExp = (current?['required_exp'] as num?)?.toInt() ?? 0;
    final nextExp = (next?['required_exp'] as num?)?.toInt() ?? currentExp;
    final progress = next == null ? 1.0 : ((_sentCoins - currentExp) / (nextExp - currentExp).clamp(1, 1 << 30)).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('ACCOUNT LEVEL')),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
        : RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF33447A), Color(0xFF1A2447), Color(0xFF111A31)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ZoonlTheme.champagne.withOpacity(.6)),
                boxShadow: [BoxShadow(color: ZoonlTheme.champagne.withOpacity(.12), blurRadius: 22)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ZOONL MEMBER RANK', style: TextStyle(color: Color(0xFFC7D3F4), fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(width: 66, height: 66,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFB9AEFF), Color(0xFF58D6CE)]),
                      boxShadow: [BoxShadow(color: ZoonlTheme.champagne.withOpacity(.25), blurRadius: 15)]),
                    child: Center(child: Text('$_level', style: const TextStyle(color: Color(0xFF10182E), fontWeight: FontWeight.w900, fontSize: 25))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(current?['level_name']?.toString() ?? 'Level $_level',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const Text('Verified account progression', style: TextStyle(color: Color(0xFFC7D3F4), fontSize: 11)),
                  ])),
                  const Icon(Icons.workspace_premium, color: Color(0xFFB9AEFF), size: 32),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Text('GIFTING EXPERIENCE', style: TextStyle(color: Color(0xFFC7D3F4), fontSize: 10, fontWeight: FontWeight.w800))),
                  Text('$_sentCoins / ${next == null ? _sentCoins : nextExp}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8CEBFF)))),
                const SizedBox(height: 8),
                Text(next == null ? 'Maximum configured level reached.'
                  : '${(nextExp - _sentCoins).clamp(0, nextExp)} coins until Level ${next['level']}',
                  style: const TextStyle(color: Color(0xFFC7D3F4), fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('LEVEL LADDER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 8),
            for (final row in _levels)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: (row['level'] as num).toInt() == _level ? ZoonlTheme.surfaceRaised : ZoonlTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: (row['level'] as num).toInt() <= _level ? ZoonlTheme.champagne.withOpacity(.2) : ZoonlTheme.backgroundRaised,
                  child: Text(row['level'].toString(), style: TextStyle(color: (row['level'] as num).toInt() <= _level ? ZoonlTheme.champagne : ZoonlTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                title: Text(row['level_name']?.toString() ?? 'Level ${row['level']}'),
                trailing: Text('${row['required_exp']} EXP', style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 10)),
              ),
          ]),
        ),
    );
  }
}
