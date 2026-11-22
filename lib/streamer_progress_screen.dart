import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/zoonl_theme.dart';

class StreamerProgressScreen extends StatefulWidget {
  const StreamerProgressScreen({super.key});
  @override
  State<StreamerProgressScreen> createState() => _StreamerProgressScreenState();
}

class _StreamerProgressScreenState extends State<StreamerProgressScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String _period = 'Daily';
  int _dailyCoins = 0, _weeklyCoins = 0, _monthlyCoins = 0;
  String _serverStarRank = 'NO STAR';
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  static const List<int> _starThresholds = [10000, 50000, 300000, 600000, 1000000];

  @override
  void initState() { super.initState(); _load(); }

  DateTime _periodStart(DateTime now) {
    if (_period == 'Weekly') {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    }
    if (_period == 'Monthly') return DateTime(now.year, now.month);
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      setState(() { _loading = false; _error = 'Please sign in to view streamer progress.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final summary = await _db.from('streamer_gifting_summary')
          .select('daily_coins,weekly_coins,monthly_coins,star_rank')
          .eq('streamer_id', user.id).maybeSingle();
      final start = _periodStart(DateTime.now()).toUtc().toIso8601String();
      final history = await _db.from('streamer_gifting_history')
          .select('sender_id,sender_name,coins_sent,sent_at')
          .eq('streamer_id', user.id).gte('sent_at', start)
          .order('sent_at', ascending: false).limit(100);
      if (!mounted) return;
      setState(() {
        _dailyCoins = (summary?['daily_coins'] as num?)?.toInt() ?? 0;
        _weeklyCoins = (summary?['weekly_coins'] as num?)?.toInt() ?? 0;
        _monthlyCoins = (summary?['monthly_coins'] as num?)?.toInt() ?? 0;
        _serverStarRank = summary?['star_rank']?.toString() ?? 'NO STAR';
        _history = (history as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  int get _currentStars {
    var stars = 0;
    for (final threshold in _starThresholds) {
      if (_dailyCoins >= threshold) { stars++; } else { break; }
    }
    return stars;
  }

  @override
  Widget build(BuildContext context) {
    final next = _starThresholds.firstWhere((value) => _dailyCoins < value, orElse: () => _starThresholds.last);
    final previous = _currentStars == 0 ? 0 : _starThresholds[_currentStars - 1];
    final progress = _currentStars == 5 ? 1.0 : ((_dailyCoins - previous) / (next - previous)).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('STREAMER PROGRESS'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF29365E), Color(0xFF141E35)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ZoonlTheme.champagne.withOpacity(.5)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TODAY’S STREAMER STAR', style: TextStyle(color: ZoonlTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('$_currentStars', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ZoonlTheme.champagne)),
                      const SizedBox(width: 8),
                      const Text('★', style: TextStyle(fontSize: 30, color: Color(0xFF8CEBFF))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_currentStars} STAR${_currentStars == 1 ? '' : 'S'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    ]),
                    Text('Daily gifts: $_dailyCoins coins • Server rank: $_serverStarRank',
                      style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(ZoonlTheme.champagne))),
                    const SizedBox(height: 7),
                    Text(_currentStars == 5 ? 'Five-star daily target reached.'
                      : '${(next - _dailyCoins).clamp(0, next)} coins to the next star',
                      style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('STEP-BY-STEP STAR LADDER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
                const SizedBox(height: 8),
                for (int i = 0; i < _starThresholds.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(color: ZoonlTheme.surface, borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: i < _currentStars ? ZoonlTheme.champagne : ZoonlTheme.border)),
                    child: Row(children: [
                      Icon(i < _currentStars ? Icons.stars : Icons.star_border,
                        color: i < _currentStars ? ZoonlTheme.champagne : ZoonlTheme.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${i + 1} STAR', style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${_starThresholds[i]} coins / day', style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 11)),
                      if (i < _currentStars) const Padding(padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle, color: ZoonlTheme.teal, size: 17)),
                    ]),
                  ),
                const SizedBox(height: 14),
                const Text('GIFTING TOTALS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
                const SizedBox(height: 8),
                Row(children: [
                  _totalCard('DAILY', _dailyCoins), const SizedBox(width: 8),
                  _totalCard('WEEKLY', _weeklyCoins), const SizedBox(width: 8),
                  _totalCard('MONTHLY', _monthlyCoins),
                ]),
                const SizedBox(height: 18),
                const Text('GIFTER HISTORY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
                const SizedBox(height: 8),
                Wrap(spacing: 7, children: ['Daily', 'Weekly', 'Monthly'].map((period) => ChoiceChip(
                  label: Text(period), selected: _period == period,
                  onSelected: (_) { setState(() => _period = period); _load(); },
                )).toList()),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Padding(padding: EdgeInsets.all(18),
                    child: Text('No gift history in this period yet.', textAlign: TextAlign.center,
                      style: TextStyle(color: ZoonlTheme.textSecondary)))
                else
                  for (final item in _history)
                    Card(color: ZoonlTheme.surface, child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF29365D),
                        child: Icon(Icons.card_giftcard, color: ZoonlTheme.champagne)),
                      title: Text(item['sender_name']?.toString() ?? 'Viewer'),
                      subtitle: Text(DateTime.parse(item['sent_at'].toString()).toLocal().toString().substring(0, 16)),
                      trailing: Text('${item['coins_sent'] ?? 0} coins',
                        style: const TextStyle(color: ZoonlTheme.champagne, fontWeight: FontWeight.w800)),
                    )),
              ]),
            ),
    );
  }

  Widget _totalCard(String label, int value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      decoration: BoxDecoration(color: ZoonlTheme.surface, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ZoonlTheme.border)),
      child: Column(children: [
        Text(label, style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ]),
    ),
  );
}
