import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressionCenterScreen extends StatefulWidget {
  final int initialTab;
  const ProgressionCenterScreen({super.key, this.initialTab = 0});
  @override
  State<ProgressionCenterScreen> createState() => _ProgressionCenterScreenState();
}

class _ProgressionCenterScreenState extends State<ProgressionCenterScreen> {
  late Future<_ProgressionData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressionData> _load() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final values = await Future.wait<dynamic>([
      db.from('profiles')
          .select('wealth_exp,wealth_level,talent_exp,talent_level')
          .eq('id', user.id).maybeSingle(),
      db.from('wealth_levels')
          .select('level,tier,tier_bracket,tier_name,title,required_exp,required_coins,coin_price,is_milestone,frame_name,asset_url,motif,color_tier,glow_primary,glow_core,glow_accent,badge_gradient,badge_border,badge_glow,chat_ribbon_theme,chat_ribbon_bg,chat_ribbon_border,chat_ribbon_shadow,unlocked_perk')
          .order('level'),
      db.from('talent_levels')
          .select('level,tier,required_exp,required_coins')
          .order('level'),
      db.from('gift_sends')
          .select('id,sender_id,receiver_id,total_coins,quantity,gift_id,created_at')
          .eq('sender_id', user.id).order('created_at', ascending: false),
      db.from('gift_sends')
          .select('id,sender_id,receiver_id,total_coins,quantity,gift_id,created_at')
          .eq('receiver_id', user.id).order('created_at', ascending: false),
    ]);

    final profile = values[0] as Map<String, dynamic>? ?? <String, dynamic>{};
    List<Map<String, dynamic>> maps(dynamic value) =>
        (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return _ProgressionData(
      wealthExp: (profile['wealth_exp'] as num?)?.toInt() ?? 0,
      wealthLevel: (profile['wealth_level'] as num?)?.toInt() ?? 1,
      talentExp: (profile['talent_exp'] as num?)?.toInt() ?? 0,
      talentLevel: (profile['talent_level'] as num?)?.toInt() ?? 1,
      wealthRows: maps(values[1]),
      talentRows: maps(values[2]),
      sentHistory: maps(values[3]),
      receivedHistory: maps(values[4]),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
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
                child: Text('Supabase progression data could not load: ${snapshot.error ?? 'No data'}'),
              ));
            }
            final data = snapshot.data!;
            return TabBarView(children: [
              _progressPage(
                data: data,
                isWealth: true,
                level: data.wealthLevel,
                exp: data.wealthExp,
                rows: data.wealthRows,
                history: data.sentHistory,
              ),
              _progressPage(
                data: data,
                isWealth: false,
                level: data.talentLevel,
                exp: data.talentExp,
                rows: data.talentRows,
                history: data.receivedHistory,
              ),
            ]);
          },
        ),
      ),
    );
  }

  Color _hex(String? raw, [Color fallback = const Color(0xFFE6C47A)]) {
    final match = RegExp(r'#[0-9a-fA-F]{6}').firstMatch(raw ?? '');
    if (match == null) return fallback;
    final value = int.tryParse(match.group(0)!.substring(1), radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  List<Color> _gradient(String? raw, {Color fallback = const Color(0xFF7655A0)}) {
    final colors = RegExp(r'#[0-9a-fA-F]{6}')
        .allMatches(raw ?? '')
        .map((m) => _hex(m.group(0), fallback))
        .toList();
    return colors.length >= 2 ? colors : [fallback, fallback.withOpacity(.65)];
  }

  List<Map<String, dynamic>> _orderedTierStyles(_ProgressionData data) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in data.wealthRows) {
      final key = (row['tier_bracket'] ?? '').toString();
      if (key.isNotEmpty && seen.add(key)) result.add(row);
    }
    return result;
  }

  Map<String, dynamic>? _currentRow(List<Map<String, dynamic>> rows, int level) {
    for (final row in rows) {
      if ((row['level'] as num?)?.toInt() == level) return row;
    }
    return null;
  }

  Widget _progressPage({
    required _ProgressionData data,
    required bool isWealth,
    required int level,
    required int exp,
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> history,
  }) {
    final current = _currentRow(rows, level) ?? (rows.isNotEmpty ? rows.first : <String, dynamic>{});
    Map<String, dynamic>? next;
    for (final row in rows) {
      if (((row['level'] as num?)?.toInt() ?? 0) > level) {
        next = row;
        break;
      }
    }
    final currentExp = (current['required_exp'] as num?)?.toInt() ?? 0;
    final nextExp = (next?['required_exp'] as num?)?.toInt() ?? currentExp;
    final progress = next == null || nextExp <= currentExp
        ? 1.0
        : ((exp - currentExp) / (nextExp - currentExp)).clamp(0.0, 1.0).toDouble();
    final tierStyles = _orderedTierStyles(data);
    final currentTier = (current['tier'] as num?)?.toInt() ?? 1;
    final crownStyle = !isWealth && tierStyles.isNotEmpty
        ? tierStyles[(currentTier - 1).clamp(0, tierStyles.length - 1).toInt()]
        : current;
    final colors = _gradient(crownStyle['badge_gradient']?.toString(),
        fallback: isWealth ? const Color(0xFF7655A0) : const Color(0xFF8E4568));
    final border = _hex(crownStyle['badge_border']?.toString());
    final ranges = isWealth ? <int>[20, 40, 60, 80, 100] : <int>[10, 20, 30, 40, 50];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [BoxShadow(color: border.withOpacity(.25), blurRadius: 16)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isWealth ? 'WEALTH / USER LEVEL' : 'CROWN / DEMON TALENT LEVEL',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 7),
            Text('LEVEL $level', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            if (isWealth) ...[
              Text((current['title'] ?? current['tier_name'] ?? '').toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text((current['tier_name'] ?? '').toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ] else
              Text('TIER $currentTier', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${exp.toString()} EXP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            if (!isWealth) ...[
              const SizedBox(height: 5),
              Text('Crown level coin requirement: ${(current['required_coins'] as num?)?.toInt() ?? 0} Coins',
                style: const TextStyle(color: Color(0xFFFFE4A0), fontSize: 12, fontWeight: FontWeight.w900)),
              if (next != null)
                Text('Next Crown level (${next['level']}): ${(next['required_coins'] as num?)?.toInt() ?? 0} Coins',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 9, value: progress,
                backgroundColor: Colors.black38,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFE4A0)),
              ),
            ),
            const SizedBox(height: 7),
            Text(next == null ? 'MAXIMUM LEVEL REACHED' :
              '${(nextExp - exp).clamp(0, 1 << 62)} EXP TO LEVEL ${next['level']}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        _infoCard(
          isWealth ? 'HOW USER LEVEL GROWS' : 'HOW CROWN / DEMON GROWS',
          isWealth
            ? 'Every successful gift sent adds its total coin value to the sender Wealth EXP. This is separate from receiver progression.'
            : 'Every successful gift received adds its total coin value to receiver Talent EXP. This is separate from sender Wealth Level.',
        ),
        _sectionTitle(isWealth ? 'COMPLETE GIFT SENDING HISTORY' : 'COMPLETE GIFT RECEIVING HISTORY'),
        _historyList(history, isWealth),
        if (isWealth) ...[
          _sectionTitle('PROFILE FRAME UNLOCKS'),
          _frameList(rows, level),
        ],
        _sectionTitle(isWealth ? 'ALL 100 USER LEVELS • EXP / COINS / COLORS' : 'ALL 50 CROWN / DEMON LEVELS • REQUIRED COINS / EXP / TIER'),
        for (int start = 1; start <= rows.length; start += 5)
          Card(
            color: const Color(0xFF171126),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text('LEVELS $start–${(start + 4).clamp(1, rows.length)}',
                  style: const TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.w900)),
              children: rows.where((r) {
                final n = (r['level'] as num).toInt();
                return n >= start && n < start + 5;
              }).map((row) => SizedBox(width: (MediaQuery.of(context).size.width - 58) / 2, child: _levelRow(row, rows, level, isWealth, data))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _infoCard(String title, String body) => Card(
    color: const Color(0xFF211735),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 5),
        Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
      ]),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 15, bottom: 7),
    child: Text(title, style: const TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.w900, letterSpacing: .5, fontSize: 12)),
  );

  Widget _historyList(List<Map<String, dynamic>> history, bool sent) {
    if (history.isEmpty) {
      return const Card(
        color: Color(0xFF211735),
        child: Padding(padding: EdgeInsets.all(14),
          child: Text('No gift transactions recorded for this account yet.', style: TextStyle(color: Colors.white54, fontSize: 11))),
      );
    }
    return Card(
      color: const Color(0xFF211735),
      child: Column(children: history.map((item) {
        final date = DateTime.tryParse(item['created_at']?.toString() ?? '')?.toLocal();
        final dateText = date == null ? 'Date unavailable' :
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        final coins = (item['total_coins'] as num?)?.toInt() ?? 0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final otherId = (sent ? item['receiver_id'] : item['sender_id'])?.toString() ?? '';
        return ListTile(
          dense: true,
          leading: Icon(sent ? Icons.card_giftcard : Icons.redeem, color: const Color(0xFFFFD77A)),
          title: Text('$coins Coins • x$qty', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          subtitle: Text('${sent ? 'Receiver' : 'Sender'}: ${otherId.isEmpty ? 'Unavailable' : otherId}\n$dateText',
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
          isThreeLine: true,
        );
      }).toList()),
    );
  }

  Widget _frameList(List<Map<String, dynamic>> rows, int level) {
    final frames = rows.where((r) => r['frame_name'] != null).toList();
    return Card(
      color: const Color(0xFF211735),
      child: Column(children: frames.map((row) {
        final n = (row['level'] as num).toInt();
        final unlocked = level >= n;
        final c = _hex(row['badge_border']?.toString());
        return ListTile(
          dense: true,
          leading: Icon(Icons.crop_portrait, color: unlocked ? c : Colors.white30),
          title: Text(row['frame_name'].toString(),
            style: TextStyle(color: unlocked ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: Text('Level $n • ${row['color_tier'] ?? row['tier_name'] ?? ''} • ${row['motif'] ?? ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
          trailing: Icon(unlocked ? Icons.lock_open : Icons.lock_outline,
            color: unlocked ? const Color(0xFFFFD77A) : Colors.white30, size: 17),
        );
      }).toList()),
    );
  }

  Widget _levelRow(Map<String, dynamic> row, List<Map<String, dynamic>> rows,
      int currentLevel, bool wealth, _ProgressionData data) {
    final n = (row['level'] as num).toInt();
    final requiredExp = (row['required_exp'] as num?)?.toInt() ?? 0;
    final active = n == currentLevel;
    final unlocked = n <= currentLevel;
    final tier = (row['tier'] as num?)?.toInt() ?? 1;
    final tierStyles = _orderedTierStyles(data);
    final style = wealth ? row : (tierStyles.isEmpty ? row : tierStyles[(tier - 1).clamp(0, tierStyles.length - 1).toInt()]);
    final colors = _gradient(style['badge_gradient']?.toString(),
        fallback: wealth ? const Color(0xFF7655A0) : const Color(0xFF8E4568));
    final border = _hex(style['badge_border']?.toString());
    final framePrice = (row['coin_price'] as num?)?.toInt() ?? 0;
    final requiredCoins = (row['required_coins'] as num?)?.toInt() ?? 0;
    final assetUrl = (style['asset_url'] ?? '').toString().trim();
    final motif = (style['motif'] ?? style['frame_name'] ?? style['color_tier'] ?? '').toString();
    final motifIcon = motif.toLowerCase().contains('crown') ? Icons.workspace_premium
        : motif.toLowerCase().contains('diamond') ? Icons.diamond
        : motif.toLowerCase().contains('fire') ? Icons.local_fire_department
        : motif.toLowerCase().contains('star') ? Icons.stars
        : wealth ? Icons.pets_rounded : Icons.workspace_premium;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171D35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? border : border.withOpacity(.30), width: active ? 1.5 : .7),
        boxShadow: active ? [BoxShadow(color: border.withOpacity(.28), blurRadius: 12, spreadRadius: 1)] : null,
      ),
      child: Stack(children: [
        if (wealth && assetUrl.isNotEmpty)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Opacity(
                opacity: unlocked ? .30 : .12,
                child: Image.network(assetUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          ),
        if (wealth)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [colors.first.withOpacity(.32), colors.last.withOpacity(.12), const Color(0xFF171D35).withOpacity(.94)],
                ),
              ),
            ),
          ),
        Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(children: [
            Container(width: 20, height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(.22), border: Border.all(color: Colors.white70)),
              child: Icon(n % 5 == 0 ? Icons.workspace_premium : Icons.star, size: 12, color: Colors.white)),
            const SizedBox(width: 5),
            Expanded(child: Text('Lv$n', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10))),
            Icon(active ? Icons.check_circle : unlocked ? Icons.check : Icons.diamond, size: 12, color: Colors.white),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Exp: $requiredExp', textAlign: TextAlign.center,
          style: TextStyle(color: active ? const Color(0xFFFFE3A0) : Colors.white70, fontSize: 10, fontWeight: FontWeight.w900)),
        if (wealth && framePrice > 0)
          Text('Frame: $framePrice Coins', style: const TextStyle(color: Colors.white54, fontSize: 8)),
        if (!wealth) ...[
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.monetization_on, size: 11, color: Color(0xFFFFD77A)),
            const SizedBox(width: 3),
            Flexible(child: Text('$requiredCoins Coins required',
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFE3A0), fontSize: 9, fontWeight: FontWeight.w900))),
          ]),
          Text('Tier $tier', style: const TextStyle(color: Colors.white54, fontSize: 8)),
        ],
        if (wealth && motif.isNotEmpty)
          Text(motif, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w700)),
        if (wealth && (row['unlocked_perk'] ?? '').toString().isNotEmpty)
          Text(row['unlocked_perk'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 8)),
        if (!unlocked)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline, size: 10, color: Colors.white54),
              SizedBox(width: 3),
              Text('LOCKED', style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
      ]),
    );
  }
}

class _ProgressionData {
  final int wealthExp, wealthLevel, talentExp, talentLevel;
  final List<Map<String, dynamic>> wealthRows, talentRows, sentHistory, receivedHistory;
  const _ProgressionData({
    required this.wealthExp,
    required this.wealthLevel,
    required this.talentExp,
    required this.talentLevel,
    required this.wealthRows,
    required this.talentRows,
    required this.sentHistory,
    required this.receivedHistory,
  });
}
