import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PkBroadcastScreen extends StatefulWidget {
  const PkBroadcastScreen({super.key});

  @override
  State<PkBroadcastScreen> createState() => _PkBroadcastScreenState();
}

class _PkBroadcastScreenState extends State<PkBroadcastScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _battles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_db.auth.currentUser == null) {
        throw StateError('Please sign in to view live PK broadcasts.');
      }
      final rawBattles = await _db
          .from('pk_battles')
          .select('id,battle_type,battle_status,duration_minutes,max_participants,started_at,created_by')
          .eq('battle_status', 'active')
          .order('started_at', ascending: false)
          .limit(30);
      final battles = (rawBattles as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (battles.isEmpty) {
        if (mounted) setState(() {
          _battles = [];
          _loading = false;
        });
        return;
      }

      final battleIds = battles.map((row) => row['id']).toList();
      final rawPlayers = await _db
          .from('pk_participants')
          .select('battle_id,user_id,team_number,score,status,joined_at')
          .inFilter('battle_id', battleIds)
          .order('joined_at', ascending: true);
      final players = (rawPlayers as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final userIds = players.map((row) => row['user_id'].toString()).toSet().toList();
      final idByUser = <String, String>{};
      if (userIds.isNotEmpty) {
        final publicProfiles = await _db
            .from('user_public_profiles')
            .select('user_id,zoonl_id')
            .inFilter('user_id', userIds);
        for (final row in publicProfiles as List) {
          idByUser[row['user_id'].toString()] =
              row['zoonl_id']?.toString() ?? 'Member';
        }
      }
      for (final player in players) {
        player['zoonl_id'] = idByUser[player['user_id'].toString()] ?? 'Member';
      }
      for (final battle in battles) {
        final id = battle['id'];
        battle['players'] = players
            .where((player) => player['battle_id'] == id)
            .toList();
      }
      if (mounted) setState(() {
        _battles = battles;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Widget _player(Map<String, dynamic> player) {
    final team = (player['team_number'] as num?)?.toInt() ?? 0;
    final score = (player['score'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF211735),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: team == 1
                ? const Color(0xFF594078)
                : const Color(0xFF31566A),
            child: Text('$team', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'ZOONL ID ' + (player['zoonl_id'] ?? 'Member').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              color: Color(0xFFE5BD70),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _battleCard(Map<String, dynamic> battle) {
    final players = (battle['players'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final type = (battle['battle_type'] ?? 'PK').toString().toUpperCase();
    final started = DateTime.tryParse('${battle['started_at'] ?? ''}')?.toLocal();
    final startLabel = started == null
        ? 'Live now'
        : 'Started ' + started.hour.toString().padLeft(2, '0') +
            ':' + started.minute.toString().padLeft(2, '0');
    final teamOne = players.where((p) => (p['team_number'] as num?)?.toInt() == 1).toList();
    final teamTwo = players.where((p) => (p['team_number'] as num?)?.toInt() == 2).toList();
    final scoreOne = teamOne.fold<int>(0, (sum, p) => sum + ((p['score'] as num?)?.toInt() ?? 0));
    final scoreTwo = teamTwo.fold<int>(0, (sum, p) => sum + ((p['score'] as num?)?.toInt() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF21152F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C4A82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Colors.redAccent, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  type + ' PK • #' + battle['id'].toString(),
                  style: const TextStyle(
                    color: Color(0xFFE5BD70),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(startLabel, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _scoreBox('TEAM 1', scoreOne)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('VS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: _scoreBox('TEAM 2', scoreTwo)),
            ],
          ),
          const SizedBox(height: 8),
          ...players.map(_player),
          if (players.isEmpty)
            const Text('Waiting for player details…', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF30203F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          Text('$score', style: const TextStyle(color: Color(0xFFE5BD70), fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        title: const Text(
          'LIVE PK BROADCASTS',
          style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE5BD70)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: _load, child: const Text('RETRY')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _battles.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 130),
                            Icon(Icons.sports_esports_outlined, color: Color(0xFFE5BD70), size: 48),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'No active PK broadcast right now.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(14),
                          children: [
                            const Text(
                              'Active matches only. PK setup and invitations are available to hosts from their live room controls.',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            ..._battles.map(_battleCard),
                          ],
                        ),
                ),
    );
  }
}
