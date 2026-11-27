import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LevelBadgeData {
  final int level, exp, currentExp, nextExp;
  final String title, motif, colorTier, chatTheme, chatBg;
  final Color border, chatBorder;
  final List<Color> gradient, chatGradient;

  const _LevelBadgeData({
    required this.level, required this.exp, required this.currentExp,
    required this.nextExp, required this.title, required this.motif,
    required this.colorTier, required this.chatTheme, required this.chatBg,
    required this.border, required this.chatBorder, required this.gradient,
    required this.chatGradient,
  });
}

class ZoonlMiniLevelBadge extends StatefulWidget {
  final VoidCallback? onTap;
  const ZoonlMiniLevelBadge({super.key, this.onTap});
  @override
  State<ZoonlMiniLevelBadge> createState() => _ZoonlMiniLevelBadgeState();
}

class _ZoonlMiniLevelBadgeState extends State<ZoonlMiniLevelBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2600),
  )..repeat();
  late Future<_LevelBadgeData> _future;
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

  Color _hex(String? raw, [Color fallback = const Color(0xFFD6B46A)]) {
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (match == null) return fallback;
    final value = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  List<Color> _gradient(String? raw, List<Color> fallback) {
    final values = RegExp(r'#[0-9a-fA-F]{6}').allMatches(raw ?? '')
        .map((m) => _hex(m.group(0))).toList();
    return values.length >= 2 ? values : fallback;
  }

  Future<_LevelBadgeData> _load() async {
    final db = Supabase.instance.client;
    if (db.auth.currentUser == null) {
      return const _LevelBadgeData(
        level: 1, exp: 0, currentExp: 0, nextExp: 0,
        title: 'Bronze Initiate', motif: 'lion', colorTier: 'Bronze',
        chatTheme: 'Chat Ribbon', chatBg: '',
        border: Color(0xFFD6B46A), chatBorder: Color(0xFF22D3EE),
        gradient: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
        chatGradient: [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF06B6D4)],
      );
    }
    final values = await Future.wait<dynamic>([
      db.rpc('zoonl_my_level'),
      db.rpc('zoonl_my_lifetime_gift_exp'),
    ]);
    final level = ((values[0] as num?)?.toInt() ?? 1).clamp(1, 100).toInt();
    final exp = (values[1] as num?)?.toInt() ?? 0;
    final row = await db.from('wealth_levels')
        .select('level,title,tier_name,required_exp,badge_gradient,badge_border,motif,color_tier,chat_ribbon_theme,chat_ribbon_bg,chat_ribbon_border')
        .eq('level', level).maybeSingle();
    final next = level >= 100 ? null : await db.from('wealth_levels')
        .select('required_exp').eq('level', level + 1).maybeSingle();
    return _LevelBadgeData(
      level: level, exp: exp,
      currentExp: (row?['required_exp'] as num?)?.toInt() ?? 0,
      nextExp: (next?['required_exp'] as num?)?.toInt() ?? 0,
      title: (row?['title'] ?? row?['tier_name'] ?? 'Level $level').toString(),
      motif: (row?['motif'] ?? '').toString(),
      colorTier: (row?['color_tier'] ?? '').toString(),
      chatTheme: (row?['chat_ribbon_theme'] ?? 'Chat Ribbon').toString(),
      chatBg: (row?['chat_ribbon_bg'] ?? '').toString(),
      border: _hex(row?['badge_border']?.toString()),
      chatBorder: _hex(row?['chat_ribbon_border']?.toString(), const Color(0xFF22D3EE)),
      gradient: _gradient(row?['badge_gradient']?.toString(),
          const [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)]),
      chatGradient: _gradient(row?['chat_ribbon_bg']?.toString(),
          const [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF06B6D4)]),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LevelBadgeData>(
    future: _future,
    builder: (context, snapshot) {
      final d = snapshot.data ?? const _LevelBadgeData(
        level: 1, exp: 0, currentExp: 0, nextExp: 0,
        title: 'Bronze Initiate', motif: 'lion', colorTier: 'Bronze',
        chatTheme: 'Chat Ribbon', chatBg: '',
        border: Color(0xFFD6B46A), chatBorder: Color(0xFF22D3EE),
        gradient: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
        chatGradient: [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF06B6D4)],
      );
      final icon = d.motif.toLowerCase().contains('lion') ? Icons.pets
          : d.motif.toLowerCase().contains('tiger') ? Icons.cruelty_free
          : d.motif.toLowerCase().contains('crown') ? Icons.workspace_premium
          : d.motif.toLowerCase().contains('wing') ? Icons.air
          : d.motif.toLowerCase().contains('orbit') ? Icons.public
          : Icons.stars;
      return GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(message: 'User Level ${d.level} • ${d.title} • EXP ${d.exp}',
          child: Container(
            width: 104, height: 27,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [d.border, d.gradient.first, d.border]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: d.border.withOpacity(.42), blurRadius: 8, spreadRadius: .4)],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [d.gradient.last.withOpacity(.98), d.gradient.first.withOpacity(.98)]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(.38), width: .6),
              ),
              child: Stack(children: [
                Positioned(left: 3, right: 3, top: 2,
                  child: Container(height: 1, color: Colors.white.withOpacity(.5))),
                Positioned(right: 3, top: 3, bottom: 3,
                  child: Icon(Icons.diamond, size: 10, color: d.border.withOpacity(.9))),
                Row(children: [
                  const SizedBox(width: 3),
                  Container(width: 19, height: 19,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [d.border, d.gradient.first]),
                      border: Border.all(color: Colors.white.withOpacity(.85), width: 1),
                      boxShadow: [BoxShadow(color: d.border.withOpacity(.6), blurRadius: 4)],
                    ),
                    child: Icon(icon, size: 12, color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('USER LV ${d.level}',
                    maxLines: 1, overflow: TextOverflow.clip,
                    style: const TextStyle(color: Colors.white, fontSize: 9.5,
                      height: 1, fontWeight: FontWeight.w900, letterSpacing: .25))),
                ]),
              ]),
            ),
          ),
        ),
      );
    },
  );
}

/// Separate chat-name ribbon. Its palette and label come from the current
/// wealth_levels row, independently of the User Level badge.
class ZoonlChatRibbonBadge extends StatefulWidget {
  const ZoonlChatRibbonBadge({super.key});
  @override
  State<ZoonlChatRibbonBadge> createState() => _ZoonlChatRibbonBadgeState();
}

class _ZoonlChatRibbonBadgeState extends State<ZoonlChatRibbonBadge> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<Map<String, dynamic>> _load() async {
    final db = Supabase.instance.client;
    final level = ((await db.rpc('zoonl_my_level')) as num?)?.toInt() ?? 1;
    return await db.from('wealth_levels')
        .select('level,chat_ribbon_theme,chat_ribbon_bg,chat_ribbon_border')
        .eq('level', level).maybeSingle() ?? <String, dynamic>{};
  }

  Color _hex(String? raw) {
    final m = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (m == null) return const Color(0xFF22D3EE);
    return Color(0xFF000000 | int.parse(m.group(0)!.substring(1), radix: 16));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      final row = snapshot.data ?? const <String, dynamic>{};
      final raw = (row['chat_ribbon_bg'] ?? '').toString();
      final colors = RegExp(r'#[0-9a-fA-F]{6}').allMatches(raw)
          .map((m) => _hex(m.group(0))).toList();
      final palette = colors.length >= 2 ? colors :
          const [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF06B6D4)];
      final border = _hex(row['chat_ribbon_border']?.toString());
      final label = (row['chat_ribbon_theme'] ?? 'CHAT RIBBON').toString();
      return Container(
        width: 104, height: 19,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: palette),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border, width: 1),
          boxShadow: [BoxShadow(color: border.withOpacity(.35), blurRadius: 6)],
        ),
        child: Row(children: [
          const Icon(Icons.chat_bubble, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Expanded(child: Text(label.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 7,
              fontWeight: FontWeight.w900, letterSpacing: .25))),
        ]),
      );
    },
  );
}
