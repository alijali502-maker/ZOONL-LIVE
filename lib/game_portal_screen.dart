import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamePortalScreen extends StatefulWidget {
  const GamePortalScreen({
    super.key,
    this.zoonlId = '10001',
    this.playerName = 'ZOONL Player',
    this.initialCoins = 1000,
    this.isOwner = true,
  });

  final String zoonlId;
  final String playerName;
  final int initialCoins;
  final bool isOwner;

  @override
  State<GamePortalScreen> createState() => _GamePortalScreenState();
}

class _GamePortalScreenState extends State<GamePortalScreen> {
  static const Color _bg = Color(0xFF070B12);
  static const Color _cardBg = Color(0xFF121C28);
  static const Color _cardAlt = Color(0xFF1A2838);
  static const Color _gold = Color(0xFFF5C85C);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFF43F5E);
  static const Color _muted = Color(0xFFAAB5BE);

  final math.Random _rng = math.Random();
  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  late int _coins;
  int _bet = 100;
  String _game = 'teen_patti';
  bool _isBusy = false;
  String? _statusMsg;
  bool _statusWon = true;

  int _potA = 450;
  int _potB = 380;
  int _potC = 220;
  int _potMid = 1050;

  List<String> _rhythm = ['LOW', 'LOW', 'MID', 'HIGH', 'LOW', 'HIGH', 'LOW', 'MID'];
  int _beatIndex = 0;

  final List> _rounds = [];

  bool get _canSeeOwner => widget.isOwner && widget.zoonlId.trim() == '10001';

  @override
  void initState() {
    super.initState();
    _coins = widget.initialCoins;
    _loadFromSupabase();
  }

  String get _currentBeat => _rhythm[_beatIndex % _rhythm.length];

  void _showMsg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadFromSupabase() async {
    final db = _db;
    if (db == null) return;
    try {
      final cfg = await db.from('game_config').select().eq('id', 1).maybeSingle();
      if (cfg != null && mounted) {
        setState(() {
          _potA = (cfg['pot_a'] as num?)?.toInt() ?? _potA;
          _potB = (cfg['pot_b'] as num?)?.toInt() ?? _potB;
          _potC = (cfg['pot_c'] as num?)?.toInt() ?? _potC;
          _potMid = (cfg['pot_mid'] as num?)?.toInt() ?? _potMid;
          _beatIndex = (cfg['beat_index'] as num?)?.toInt() ?? _beatIndex;
          if (cfg['rhythm'] is List) {
            final list = (cfg['rhythm'] as List).map((e) => e.toString()).toList();
            if (list.isNotEmpty) _rhythm = list;
          }
        });
      }

      final prof = await db
          .from('profiles')
          .select('coins')
          .eq('zoonl_id', widget.zoonlId.trim())
          .maybeSingle();
      if (prof != null && prof['coins'] != null && mounted) {
        setState(() => _coins = (prof['coins'] as num).toInt());
      }

      final historyRows = await db
          .from('game_rounds')
          .select()
          .order('id', ascending: false)
          .limit(15);
      if (mounted) {
        setState(() {
          _rounds
            ..clear()
            ..addAll(List>.from(historyRows));
        });
      }
    } catch (_) {}
  }

  Future<void> _playRound({
    required String gameTitle,
    required String pick,
    required String potTag,
    required bool won,
    required double multiplier,
  }) async {
    if (_isBusy) return;
    if (_coins < _bet) {
      _showMsg('Coins kam hain ($_bet chahiye).');
      return;
    }

    setState(() => _isBusy = true);
    final db = _db;

    if (db != null) {
      try {
        final res = await db.rpc(
          'play_game_round',
          params: {
            'p_zoonl_id': widget.zoonlId.trim(),
            'p_game_name': gameTitle,
            'p_pick': '$pick ($potTag)',
            'p_won': won,
            'p_bet': _bet,
            'p_multiplier': multiplier,
          },
        );

        if (res is Map && res['ok'] == true) {
          final nextCoins = (res['coins'] as num?)?.toInt() ?? _coins;
          final payout = (res['payout'] as num?)?.toInt() ?? 0;
          final playerDelta = (res['player_delta'] as num?)?.toInt() ?? (nextCoins - _coins);
          final ownerDelta = (res['owner_delta'] as num?)?.toInt() ?? 0;

          if (mounted) {
            setState(() {
              _coins = nextCoins;
              _potMid += _bet;
              if (potTag == 'A') _potA += _bet;
              if (potTag == 'B') _potB += _bet;
              if (potTag == 'C') _potC += _bet;
              _beatIndex += 1;
              _statusWon = won;
              _statusMsg = won
                  ? '$gameTitle • $pick WIN (+$payout Coins)'
                  : '$gameTitle • $pick LOSS (-$_bet Coins)';
              _rounds.insert(0, {
                'zoonl_id': widget.zoonlId.trim(),
                'game_name': gameTitle,
                'pick': '$pick ($potTag)',
                'won': won,
                'bet_amount': _bet,
                'payout_amount': payout,
                'player_delta': playerDelta,
                'owner_delta': ownerDelta,
              });
              _isBusy = false;
            });
          }
          return;
        } else if (res is Map && res['error'] != null) {
          _showMsg(res['error'].toString());
          if (mounted) setState(() => _isBusy = false);
          return;
        }
      } catch (e) {
        _showMsg('Supabase sync issue: $e');
      }
    }

    final payout = won ? (_bet * multiplier).round() : 0;
    final nextCoins = _coins - _bet + payout;
    final playerDelta = nextCoins - _coins;
    final ownerDelta = won ? -(payout - _bet) : _bet;

    if (mounted) {
      setState(() {
        _coins = nextCoins;
        _potMid += _bet;
        if (potTag == 'A') _potA += _bet;
        if (potTag == 'B') _potB += _bet;
        if (potTag == 'C') _potC += _bet;
        _beatIndex += 1;
        _statusWon = won;
        _statusMsg = won
            ? '$gameTitle • $pick WIN (+$payout Coins)'
            : '$gameTitle • $pick LOSS (-$_bet Coins)';
        _rounds.insert(0, {
          'zoonl_id': widget.zoonlId.trim(),
          'game_name': gameTitle,
          'pick': '$pick ($potTag)',
          'won': won,
          'bet_amount': _bet,
          'payout_amount': payout,
          'player_delta': playerDelta,
          'owner_delta': ownerDelta,
        });
        _isBusy = false;
      });
    }
  }

  void _triggerGameAction(String label, String pot, double mult) {
    final beat = _currentBeat;
    final winChance = beat == 'HIGH' ? 65 : (beat == 'MID' ? 48 : 35);
    final won = _rng.nextInt(100) < winChance;

    String title = 'Teen Patti Duel';
    if (_game == 'color_rush') title = 'Color Rush';
    if (_game == 'dragon_tiger') title = 'Dragon vs Tiger';
    if (_game == 'lucky_dice') title = 'Lucky Dice 7';
    if (_game == 'royal_wheel') title = 'Royal Wheel';

    _playRound(gameTitle: title, pick: label, potTag: pot, won: won, multiplier: mult);
  }

  Future<void> _updateOwnerRhythm(List<String> nextRhythm) async {
    if (!_canSeeOwner) return;
    setState(() {
      _rhythm = nextRhythm;
      _beatIndex = 0;
    });
    final db = _db;
    if (db != null) {
      try {
        await db.from('game_config').update({
          'rhythm': nextRhythm,
          'beat_index': 0,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', 1);
      } catch (_) {}
    }
  }

  Widget _box({required Widget child, EdgeInsets pad = const EdgeInsets.all(12)}) {
    return Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }

  Widget _buildGameButtons() {
    switch (_game) {
      case 'color_rush':
        return Row(
          children: [
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _red), onPressed: () => _triggerGameAction('RED', 'A', 1.9), child: const Text('RED'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('GREEN', 'B', 1.9), child: const Text('GREEN'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('VIOLET', 'C', 4.5), child: const Text('VIOLET'))),
          ],
        );
      case 'dragon_tiger':
        return Row(
          children: [
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _red), onPressed: () => _triggerGameAction('DRAGON', 'A', 1.9), child: const Text('DRAGON'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('TIGER', 'B', 1.9), child: const Text('TIGER'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('TIE', 'C', 8.0), child: const Text('TIE'))),
          ],
        );
      case 'lucky_dice':
        return Row(
          children: [
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('< 7', 'A', 1.85), child: const Text('< 7'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('= 7', 'C', 5.0), child: const Text('= 7'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('> 7', 'B', 1.85), child: const Text('> 7'))),
          ],
        );
      case 'royal_wheel':
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: () => _triggerGameAction('SPIN WHEEL', 'C', 2.5),
            child: Text('SPIN ROYAL WHEEL • BET $_bet'),
          ),
        );
      case 'teen_patti':
      default:
        return Row(
          children: [
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('Seat A', 'A', 1.95), child: const Text('Seat A'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('Seat B', 'B', 1.95), child: const Text('Seat B'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black), onPressed: () => _triggerGameAction('Seat C', 'C', 3.0), child: const Text('Seat C'))),
          ],
        );
    }
  }

  Widget _buildOwnerBox() {
    if (!_canSeeOwner) return const SizedBox.shrink();

    int ownerNet = 0;
    for (final r in _rounds) {
      ownerNet += ((r['owner_delta'] ?? r['ownerDelta'] ?? 0) as num).toInt();
    }

    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('OWNER PANEL (ID 10001)', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              Text('Net: ${ownerNet >= 0 ? '+$ownerNet' : '$ownerNet'}', style: TextStyle(color: ownerNet >= 0 ? _green : _red, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Next Beat: $_currentBeat • ${_rhythm.join(' -> ')}', style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _updateOwnerRhythm(['LOW', 'LOW', 'LOW', 'MID', 'HIGH', 'LOW', 'HIGH', 'MID']),
                child: const Text('Balanced', style: TextStyle(color: _green, fontSize: 11)),
              ),
              OutlinedButton(
                onPressed: () => _updateOwnerRhythm(['HIGH', 'MID', 'HIGH', 'LOW', 'HIGH', 'MID', 'HIGH', 'LOW']),
                child: const Text('High Boost', style: TextStyle(color: _gold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('ZOONL 5-GAME PORTAL', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          IconButton(
            onPressed: _loadFromSupabase,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _box(
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: _gold, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${widget.playerName} (ID: ${widget.zoonlId})', style: const TextStyle(color: _muted, fontSize: 11)),
                      Text('$_coins Coins', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (_isBusy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [50, 100, 250, 500, 1000].map((v) {
              final active = _bet == v;
              return ChoiceChip(
                selected: active,
                selectedColor: _green,
                backgroundColor: _cardAlt,
                label: Text('$v', style: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.w800)),
                onSelected: (_) => setState(() => _bet = v),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(selected: _game == 'teen_patti', selectedColor: _gold, backgroundColor: _cardAlt, label: const Text('Teen Patti'), onSelected: (_) => setState(() => _game = 'teen_patti')),
              ChoiceChip(selected: _game == 'color_rush', selectedColor: _gold, backgroundColor: _cardAlt, label: const Text('Color Rush'), onSelected: (_) => setState(() => _game = 'color_rush')),
              ChoiceChip(selected: _game == 'dragon_tiger', selectedColor: _gold, backgroundColor: _cardAlt, label: const Text('Dragon Tiger'), onSelected: (_) => setState(() => _game = 'dragon_tiger')),
              ChoiceChip(selected: _game == 'lucky_dice', selectedColor: _gold, backgroundColor: _cardAlt, label: const Text('Lucky Dice 7'), onSelected: (_) => setState(() => _game = 'lucky_dice')),
              ChoiceChip(selected: _game == 'royal_wheel', selectedColor: _gold, backgroundColor: _cardAlt, label: const Text('Royal Wheel'), onSelected: (_) => setState(() => _game = 'royal_wheel')),
            ],
          ),
          const SizedBox(height: 10),
          _box(
            child: Row(
              children: [
                Expanded(child: Text('Pot A: $_potA', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(child: Text('Pot B: $_potB', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(child: Text('Pot C: $_potC', style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(child: Text('Mid: $_potMid', style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _box(child: _buildGameButtons()),
          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            _box(
              child: Text(
                _statusMsg!,
                style: TextStyle(color: _statusWon ? _green : _red, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
          if (_canSeeOwner) ...[
            const SizedBox(height: 10),
            _buildOwnerBox(),
          ],
          const SizedBox(height: 10),
          _box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECENT ROUNDS', style: TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 8),
                if (_rounds.isEmpty)
                  const Text('Abhi koi round nahi khela gaya.', style: TextStyle(color: _muted, fontSize: 11))
                else
                  ..._rounds.take(6).map((r) {
                    final delta = ((r['player_delta'] ?? r['playerDelta'] ?? 0) as num).toInt();
                    final gName = (r['game_name'] ?? r['game'] ?? 'Game').toString();
                    final pick = (r['pick'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('$gName • $pick', style: const TextStyle(color: Colors.white, fontSize: 11))),
                          Text(delta >= 0 ? '+$delta' : '$delta', style: TextStyle(color: delta >= 0 ? _green : _red, fontWeight: FontWeight.w800, fontSize: 11)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
