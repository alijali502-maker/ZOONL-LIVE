import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PkMode { random, friend, group }

class PkBattleScreen extends StatefulWidget {
  final String currentUserName;
  final String currentUserId;
  const PkBattleScreen({super.key, required this.currentUserName, required this.currentUserId});
  @override
  State<PkBattleScreen> createState() => _PkBattleScreenState();
}

class _PkBattleScreenState extends State<PkBattleScreen> {
  final SupabaseClient db = Supabase.instance.client;
  final TextEditingController target = TextEditingController();
  PkMode mode = PkMode.random;
  int groupSize = 4;
  int duration = 5;
  int? battleId;
  Map<String, dynamic>? battle;
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> invitations = [];
  Timer? poller;
  bool busy = false;
  bool queued = false;
  String statusMessage = '';

  String get uid => db.auth.currentUser?.id ?? '';
  bool get creator => battle?['created_by']?.toString() == uid;
  int get maxPlayers => (battle?['max_participants'] as num?)?.toInt() ?? 0;
  int get remaining {
    if (battle?['battle_status'] != 'active') return 0;
    final start = DateTime.tryParse('${battle?['started_at'] ?? ''}');
    final mins = (battle?['duration_minutes'] as num?)?.toInt() ?? 5;
    if (start == null) return mins * 60;
    return (mins * 60 - DateTime.now().difference(start).inSeconds).clamp(0, mins * 60);
  }
  String get clock => '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    refreshInvitations();
    poller = Timer.periodic(const Duration(seconds: 3), (_) => poll());
  }

  Future<void> poll() async {
    if (!mounted || busy) return;
    if (queued) {
      try {
        final result = await db.rpc('pk_join_random_queue');
        final id = (result as num?)?.toInt();
        if (id != null && mounted) {
          setState(() { queued = false; battleId = id; statusMessage = 'Opponent found.'; });
          await refreshBattle();
        }
      } catch (e) { setState(() => statusMessage = 'Matchmaking error: $e'); }
    } else if (battleId != null) {
      await refreshBattle();
    } else {
      await refreshInvitations();
    }
  }

  Future<void> refreshInvitations() async {
    if (uid.isEmpty) return;
    try {
      final rows = await db.from('pk_invitations')
          .select('id,battle_id,inviter_id,invited_user_id,invitation_status,created_at')
          .eq('invited_user_id', uid).eq('invitation_status', 'pending')
          .order('created_at', ascending: false);
      if (mounted) setState(() => invitations = (rows as List).map((e) => Map<String,dynamic>.from(e)).toList());
    } catch (e) { if (mounted) setState(() => statusMessage = 'Invitations: $e'); }
  }

  Future<void> refreshBattle() async {
    final id = battleId;
    if (id == null) return;
    try {
      final raw = await db.from('pk_battles')
          .select('id,battle_type,battle_status,duration_minutes,max_participants,created_by,started_at,ended_at,winner_user_id')
          .eq('id', id).maybeSingle();
      if (raw == null) return;
      final rows = await db.from('pk_participants')
          .select('user_id,team_number,score,status,joined_at')
          .eq('battle_id', id).order('joined_at');
      final list = (rows as List).map((e) => Map<String,dynamic>.from(e)).toList();
      final ids = list.map((e) => e['user_id'].toString()).toList();
      if (ids.isNotEmpty) {
        final publicRows = await db.from('user_public_profiles')
            .select('user_id,zoonl_id').inFilter('user_id', ids);
        final map = <String,String>{for (final row in publicRows as List) row['user_id'].toString(): row['zoonl_id'].toString()};
        for (final row in list) {
          row['zoonl_id'] = map[row['user_id'].toString()] ?? 'Member';
          row['is_me'] = row['user_id'].toString() == uid;
        }
      }
      if (!mounted) return;
      setState(() { battle = Map<String,dynamic>.from(raw); players = list; });
      if (battle?['battle_status'] == 'active' && remaining == 0 && creator) {
        await finishBattle();
      }
    } catch (e) { if (mounted) setState(() => statusMessage = 'PK refresh failed: $e'); }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); }
    catch (e) { if (mounted) setState(() => statusMessage = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> findRandom() => run(() async {
    final result = await db.rpc('pk_join_random_queue');
    final id = (result as num?)?.toInt();
    if (!mounted) return;
    if (id == null) {
      setState(() { queued = true; statusMessage = 'Searching for another live host...'; });
    } else {
      setState(() { battleId = id; queued = false; });
      await refreshBattle();
    }
  });

  Future<void> cancelQueue() => run(() async {
    await db.rpc('pk_leave_random_queue');
    if (mounted) setState(() { queued = false; statusMessage = 'Search cancelled.'; });
  });

  Future<void> createBattle(String type, int seats) => run(() async {
    final publicId = target.text.trim();
    if (publicId.isEmpty) throw StateError('Enter a participant ZOONL ID.');
    final result = await db.rpc('pk_create_battle', params: {
      'p_battle_type': type, 'p_max_participants': seats, 'p_duration_minutes': duration,
    });
    final id = (result as num).toInt();
    await inviteTo(id, publicId);
    target.clear();
    if (!mounted) return;
    setState(() { battleId = id; statusMessage = 'PK invitation sent.'; });
    await refreshBattle();
  });

  Future<void> inviteTo(int id, String publicId) async {
    await db.rpc('pk_invite_user', params: {'p_battle_id': id, 'p_target_zoonl_id': publicId});
  }

  Future<void> inviteMore() => run(() async {
    if (battleId == null || target.text.trim().isEmpty) throw StateError('Enter a participant ZOONL ID.');
    await inviteTo(battleId!, target.text.trim());
    target.clear();
    if (mounted) setState(() => statusMessage = 'Invitation sent.');
  });

  Future<void> respond(Map<String,dynamic> invitation, bool accept) => run(() async {
    final result = await db.rpc('pk_respond_invitation', params: {
      'p_invitation_id': invitation['id'], 'p_accept': accept,
    });
    if (accept) {
      if (!mounted) return;
      setState(() { battleId = (result as num).toInt(); invitations = []; });
      await refreshBattle();
    } else {
      await refreshInvitations();
    }
  });

  Future<void> startBattle() => run(() async {
    final result = await db.rpc('pk_start_battle', params: {'p_battle_id': battleId});
    if (mounted) setState(() => statusMessage = result.toString());
    await refreshBattle();
  });

  Future<void> finishBattle() async {
    if (battleId == null || !creator) return;
    try {
      final result = await db.rpc('pk_finish_battle', params: {'p_battle_id': battleId});
      if (mounted) setState(() => statusMessage = result.toString());
      await refreshBattle();
    } catch (e) { if (mounted) setState(() => statusMessage = 'Finish failed: $e'); }
  }

  void reset() {
    setState(() { battleId = null; battle = null; players = []; statusMessage = ''; });
    refreshInvitations();
  }

  @override
  void dispose() {
    poller?.cancel();
    if (queued) unawaited(db.rpc('pk_leave_random_queue').catchError((_) => false));
    target.dispose();
    super.dispose();
  }

  Widget panel(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xFF21152F), borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF6C4A82))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 10), child,
    ]),
  );

  Widget teams() {
    Widget team(String title, int number) {
      final members = players.where((p) => (p['team_number'] as num?)?.toInt() == number).toList();
      final score = members.fold<int>(0, (sum,p) => sum + ((p['score'] as num?)?.toInt() ?? 0));
      return Expanded(child: Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF30203F), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(title, style: const TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold)),
          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ...members.map((p) => Text(p['is_me'] == true ? 'You' : 'ID ${p['zoonl_id']}',
              style: const TextStyle(color: Colors.white70))),
        ]),
      ));
    }
    return Row(children: [team('TEAM 1',1), const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('VS', style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold))), team('TEAM 2',2)]);
  }

  @override
  Widget build(BuildContext context) {
    final state = (battle?['battle_status'] ?? '').toString();
    final isWaiting = state == 'waiting';
    final isActive = state == 'active';
    final isComplete = state == 'completed';
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(backgroundColor: const Color(0xFF1B1225), title: const Text('ZOONL PK BATTLE',
        style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(14), children: [
        panel('PK BATTLE ARENA', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.currentUserName} • ZOONL ID ${widget.currentUserId}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          SegmentedButton<PkMode>(
            segments: const [
              ButtonSegment(value: PkMode.random, label: Text('Random 1v1')),
              ButtonSegment(value: PkMode.friend, label: Text('Friend 1v1')),
              ButtonSegment(value: PkMode.group, label: Text('Group')),
            ],
            selected: {mode},
            onSelectionChanged: battleId != null || queued ? null : (s) => setState(() => mode = s.first),
          ),
          if (mode == PkMode.group) ...[
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 4, label: Text('4 Players')), ButtonSegment(value: 6, label: Text('6 Players'))],
              selected: {groupSize}, onSelectionChanged: (s) => setState(() => groupSize = s.first),
            ),
          ],
          if (mode != PkMode.random) ...[
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 5, label: Text('5 min')), ButtonSegment(value: 10, label: Text('10 min'))],
              selected: {duration}, onSelectionChanged: (s) => setState(() => duration = s.first),
            ),
          ],
        ])),
        if (battleId == null && !queued) panel('Create or Find Battle', Column(children: [
          if (mode != PkMode.random) TextField(controller: target, keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Participant ZOONL ID')),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: busy ? null : mode == PkMode.random ? findRandom :
              mode == PkMode.friend ? () => createBattle('friend',2) : () => createBattle('multi',groupSize),
            child: Text(mode == PkMode.random ? 'Find Random Opponent' : mode == PkMode.friend ? 'Create Friend PK' : 'Create Group PK'),
          )),
        ])),
        if (queued) panel('Matchmaking', Column(children: [
          const CircularProgressIndicator(), const SizedBox(height: 10),
          const Text('Searching for another available host...', style: TextStyle(color: Colors.white70)),
          OutlinedButton(onPressed: busy ? null : cancelQueue, child: const Text('Cancel Search')),
        ])),
        if (invitations.isNotEmpty && battleId == null) panel('Incoming PK Invitations', Column(
          children: invitations.map((inv) => ListTile(
            title: Text('Battle #${inv['battle_id']}', style: const TextStyle(color: Colors.white)),
            subtitle: Text('Invitation #${inv['id']}', style: const TextStyle(color: Colors.white60)),
            trailing: Wrap(children: [
              IconButton(onPressed: busy ? null : () => respond(inv,true), icon: const Icon(Icons.check,color: Colors.greenAccent)),
              IconButton(onPressed: busy ? null : () => respond(inv,false), icon: const Icon(Icons.close,color: Colors.redAccent)),
            ]),
          )).toList(),
        )),
        if (battleId != null) panel('Battle #$battleId • ${state.toUpperCase()}', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Players: ${players.length} / ${battle?['max_participants'] ?? 0}', style: const TextStyle(color: Colors.white70)),
          if (isActive) Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(clock,
            style: const TextStyle(color: Color(0xFFE5BD70), fontSize: 36, fontWeight: FontWeight.bold)))),
          if (players.isNotEmpty) teams(),
          if (isWaiting && creator) ...[
            if (battle?['battle_type'] == 'multi') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: target, keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Add ZOONL ID', isDense: true))),
                IconButton(onPressed: busy ? null : inviteMore, icon: const Icon(Icons.person_add,color: Color(0xFFE5BD70))),
              ]),
            ],
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: busy || players.length != maxPlayers ? null : startBattle,
              child: Text(players.length == maxPlayers ? 'Start PK Battle' : 'Waiting for ${maxPlayers - players.length} player(s)'),
            )),
          ],
          if (isComplete) ...[
            const SizedBox(height: 10),
            Text(battle?['winner_user_id'] == null ? 'Battle ended in a tie.' : 'Battle completed.',
              style: const TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold)),
            OutlinedButton(onPressed: reset, child: const Text('New PK Battle')),
          ],
        ])),
        if (statusMessage.isNotEmpty) panel('Status', Text(statusMessage, style: const TextStyle(color: Colors.white70))),
        if (busy) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      ])),
    );
  }
}
