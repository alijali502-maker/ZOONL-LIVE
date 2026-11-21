import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserLevelScreen extends StatefulWidget {
  const UserLevelScreen({super.key});
  @override
  State<UserLevelScreen> createState() => _UserLevelScreenState();
}

class _UserLevelScreenState extends State<UserLevelScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true, _isOwner = false;
  String? _error;
  String _primeStatus = 'Checking…', _entryStatus = 'Checking…';
  int _level = 1, _sentCoins = 0;
  List<Map<String, dynamic>> _levels = [];

  static const List<Color> _rankColors = [
    Color(0xFFB8C5D8), Color(0xFF67D7C5), Color(0xFF63B8F4),
    Color(0xFF9C83F5), Color(0xFFE78AC8), Color(0xFFE7A16B),
    Color(0xFFE5D17C), Color(0xFFEC777F), Color(0xFF78D9EA),
    Color(0xFFD5B8FF),
  ];
  Color _rankColor(int level) => _rankColors[(level - 1).clamp(0, _rankColors.length - 1).toInt()];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loading = false; _error = 'Login required.'; });
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait<dynamic>([
        _db.rpc('zoonl_my_level'),
        _db.from('gift_sends').select('total_coins').eq('sender_id', user.id),
        _db.from('level_definitions').select('level,required_exp,level_name').order('level'),
        _db.rpc('is_zoonl_owner'),
        _db.from('user_prime_memberships').select('id,prime_tier_id,expires_at,is_active').eq('user_id', user.id).eq('is_active', true),
        _db.from('zoonl_live_user_baggage').select('zoonl_item_code,item_type,is_equipped,expires_at').eq('user_id', user.id).eq('project_name', 'ZOONL LIVE'),
      ]);
      final sent = (r[1] as List).fold<int>(0, (sum, row) => sum + ((row['total_coins'] as num?)?.toInt() ?? 0));
      final now = DateTime.now();
      final prime = (r[4] as List).any((row) {
        final exp = row['expires_at'];
        return exp == null || (DateTime.tryParse(exp.toString())?.isAfter(now) ?? false);
      });
      final entries = (r[5] as List).where((row) {
        if (row['item_type']?.toString() != 'ENTRY_EFFECT') return false;
        final exp = row['expires_at'];
        return exp == null || (DateTime.tryParse(exp.toString())?.isAfter(now) ?? false);
      }).toList();
      if (!mounted) return;
      setState(() {
        _level = (r[0] as num?)?.toInt() ?? 1;
        _sentCoins = sent;
        _levels = (r[2] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _isOwner = r[3] == true;
        _primeStatus = prime ? 'ACTIVE' : 'Not assigned to this account';
        _entryStatus = entries.isEmpty ? 'No Entry effect in account inventory' : entries.map((e) => e['zoonl_item_code']?.toString() == 'ZOONL_OWNER_ENTRY' ? 'Owner Royal Entry' : (e['zoonl_item_code']?.toString() ?? 'Entry effect')).join(', ');
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Widget _glass({required Widget child, Color? accent, EdgeInsets padding = const EdgeInsets.all(16)}) {
    final edge = accent ?? Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xB9161720),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: edge.withOpacity(.48), width: 1.1),
            boxShadow: [
              BoxShadow(color: edge.withOpacity(.12), blurRadius: 24, spreadRadius: 1),
              const BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 9)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statusLine(IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.14), border: Border.all(color: color.withOpacity(.5))),
          child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? current, next;
    for (final row in _levels) {
      final n = (row['level'] as num?)?.toInt() ?? 0;
      if (n == _level) current = row;
      if (n > _level && next == null) next = row;
    }
    final currentExp = (current?['required_exp'] as num?)?.toInt() ?? 0;
    final nextExp = (next?['required_exp'] as num?)?.toInt() ?? currentExp;
    final progress = next == null ? 1.0 : ((_sentCoins - currentExp) / (nextExp - currentExp).clamp(1, 1 << 30)).clamp(0.0, 1.0).toDouble();
    final accent = _rankColor(_level);

    return Scaffold(
      backgroundColor: const Color(0xFF08090E),
      appBar: AppBar(title: const Text('LEVEL & RANK'), backgroundColor: const Color(0xFF090A10),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('RETRY')),
          ])))
        : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
            _glass(accent: accent, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('ZOONL MEMBER RANK', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w900))),
                if (_isOwner) Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFE8D28B).withOpacity(.13), borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE8D28B).withOpacity(.8)),
                    boxShadow: const [BoxShadow(color: Color(0x55E8D28B), blurRadius: 13)]),
                  child: const Text('✦ OWNER', style: TextStyle(color: Color(0xFFFFE9A8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [accent.withOpacity(.42), const Color(0xFF14151D), const Color(0xFF0A0B10)], stops: const [0, .62, 1]),
                  border: Border.all(color: accent.withOpacity(.95), width: 2),
                  boxShadow: [BoxShadow(color: accent.withOpacity(.4), blurRadius: 25, spreadRadius: 2), const BoxShadow(color: Colors.white10, blurRadius: 5, offset: Offset(-2, -2))]),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.workspace_premium_rounded, color: accent, size: 22),
                    Text('$_level', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, shadows: [Shadow(color: accent, blurRadius: 14)])),
                  ]))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(current?['level_name']?.toString() ?? 'Level $_level', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(_isOwner ? 'Sovereign Owner • Level $_level' : 'ZOONL LIVE • Level $_level', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('$_sentCoins EXP earned from gifts', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(child: Text('LEVEL PROGRESS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
                Text(next == null ? 'MAX RANK' : '${(progress * 100).round()}%', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 9),
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(children: [
                Container(height: 11, color: Colors.white12),
                FractionallySizedBox(widthFactor: progress, child: Container(height: 11, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent.withOpacity(.55), accent, Colors.white.withOpacity(.9)]),
                  borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: accent.withOpacity(.6), blurRadius: 10)]))),
              ])),
              const SizedBox(height: 9),
              Text(next == null ? 'Highest level currently configured.' : '${(nextExp - _sentCoins).clamp(0, nextExp)} EXP to Level ${next['level']}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            if (_isOwner) ...[
              const SizedBox(height: 14),
              _glass(accent: const Color(0xFFE8D28B), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('OWNER ACCOUNT STATUS', style: TextStyle(color: Color(0xFFFFE9A8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 8),
                _statusLine(Icons.verified_user_rounded, 'Trusted role', 'OWNER verified by Supabase', const Color(0xFFFFD98B)),
                _statusLine(Icons.workspace_premium_rounded, 'Prime membership', _primeStatus, const Color(0xFFBCA0FF)),
                _statusLine(Icons.bolt_rounded, 'Entry effect', _entryStatus, const Color(0xFF83DDF0)),
                const Divider(color: Colors.white12, height: 18),
                const Text('Owner identity is verified separately from the public ZOONL ID. Prime and Entry status above is read from the real account records.',
                  style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.45)),
              ])),
            ],
            const SizedBox(height: 22),
            const Text('LEVEL COLLECTION', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            const Text('Every rank has its own glass material, edge light and visual identity.', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 12),
            for (final row in _levels) _levelTile(row),
          ])),
    );
  }

  Widget _levelTile(Map<String, dynamic> row) {
    final level = (row['level'] as num?)?.toInt() ?? 1;
    final exp = (row['required_exp'] as num?)?.toInt() ?? 0;
    final reached = level <= _level, selected = level == _level;
    final color = _rankColor(level);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: _glass(
      accent: selected ? color : (reached ? color.withOpacity(.6) : Colors.white24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(reached ? .42 : .12), const Color(0xFF12131A)]),
          border: Border.all(color: color.withOpacity(reached ? .85 : .25), width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(.3), blurRadius: 15)] : []),
          child: Center(child: Text('$level', style: TextStyle(color: reached ? Colors.white : Colors.white38, fontSize: 17, fontWeight: FontWeight.w900)))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row['level_name']?.toString() ?? 'Level $level', style: TextStyle(color: reached ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$exp EXP required', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
        if (selected) Icon(Icons.stars_rounded, color: color, size: 23)
        else if (reached) Icon(Icons.check_circle_rounded, color: color, size: 20)
        else const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 19),
      ]),
    ));
  }
}
