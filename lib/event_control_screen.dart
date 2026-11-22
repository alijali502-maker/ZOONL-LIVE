import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/zoonl_theme.dart';

class EventControlScreen extends StatefulWidget {
  const EventControlScreen({super.key});

  @override
  State<EventControlScreen> createState() => _EventControlScreenState();
}

class _EventControlScreenState extends State<EventControlScreen> {
  final SupabaseClient _db = Supabase.instance.client;
  bool _checking = true;
  bool _owner = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _rewards =
      <String, List<Map<String, dynamic>>>{};

  @override
  void initState() {
    super.initState();
    _verifyOwner();
  }

  Future<void> _verifyOwner() async {
    try {
      final result = await _db.rpc('is_zoonl_owner');
      if (!mounted) return;
      setState(() {
        _owner = result == true;
        _checking = false;
      });
      if (_owner) await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _owner = false;
        _error = 'Owner verification failed: $error';
      });
    }
  }

  Future<void> _load() async {
    if (!_owner) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _db
          .from('live_events')
          .select('id,title,description,event_type,starts_at,ends_at,status,created_at')
          .order('starts_at', ascending: false)
          .limit(100);
      final events = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final ids = events.map((event) => event['id'].toString()).toList();
      final rewardMap = <String, List<Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final rewardRows = await _db
            .from('event_rewards')
            .select('id,event_id,rank_position,reward_name,reward_description,reward_coins')
            .inFilter('event_id', ids)
            .order('rank_position');
        for (final raw in rewardRows as List) {
          final reward = Map<String, dynamic>.from(raw as Map);
          (rewardMap[reward['event_id'].toString()] ??=
                  <Map<String, dynamic>>[])
              .add(reward);
        }
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _rewards
          ..clear()
          ..addAll(rewardMap);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<DateTime?> _chooseDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: ZoonlTheme.champagne,
            surface: ZoonlTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: ZoonlTheme.champagne,
            surface: ZoonlTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _createEvent() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String type = 'special';
    DateTime start = DateTime.now().add(const Duration(hours: 1));
    DateTime end = start.add(const Duration(days: 1));
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          backgroundColor: ZoonlTheme.surface,
          title: const Text('Create live event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Event title')),
                const SizedBox(height: 10),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Event cycle'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'special', child: Text('Special event')),
                  ],
                  onChanged: (value) => refresh(() => type = value ?? 'special'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(start.toLocal().toString().substring(0, 16)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final value = await _chooseDateTime(start);
                    if (value != null) refresh(() => start = value);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle: Text(end.toLocal().toString().substring(0, 16)),
                  trailing: const Icon(Icons.event_available),
                  onTap: () async {
                    final value = await _chooseDateTime(end);
                    if (value != null) refresh(() => end = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (title.text.trim().isEmpty || !end.isAfter(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a title and a valid event time range.')),
                  );
                  return;
                }
                refresh(() => saving = true);
                try {
                  await _db.from('live_events').insert({
                    'title': title.text.trim(),
                    'description': description.text.trim(),
                    'event_type': type,
                    'starts_at': start.toUtc().toIso8601String(),
                    'ends_at': end.toUtc().toIso8601String(),
                    'status': 'upcoming',
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _load();
                } catch (error) {
                  refresh(() => saving = false);
                  if (mounted) _notice('Event was not saved: $error');
                }
              },
              child: Text(saving ? 'SAVING…' : 'CREATE EVENT'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
  }

  Future<void> _addReward(Map<String, dynamic> event) async {
    final name = TextEditingController();
    final detail = TextEditingController();
    final coins = TextEditingController(text: '0');
    final rank = TextEditingController(
      text: ((_rewards[event['id'].toString()]?.length ?? 0) + 1).toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ZoonlTheme.surface,
        title: const Text('Add event reward'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: rank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rank position')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Reward name')),
            TextField(controller: detail, maxLines: 2, decoration: const InputDecoration(labelText: 'Reward details')),
            TextField(controller: coins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reward coins (0 if non-coin reward)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              final rankValue = int.tryParse(rank.text);
              final coinValue = int.tryParse(coins.text);
              if (name.text.trim().isEmpty || rankValue == null || rankValue < 1 || coinValue == null || coinValue < 0) {
                _notice('Check reward name, rank and coin value.');
                return;
              }
              try {
                await _db.from('event_rewards').insert({
                  'event_id': event['id'],
                  'rank_position': rankValue,
                  'reward_name': name.text.trim(),
                  'reward_description': detail.text.trim(),
                  'reward_coins': coinValue,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (error) {
                _notice('Reward was not saved: $error');
              }
            },
            child: const Text('SAVE REWARD'),
          ),
        ],
      ),
    );
    name.dispose();
    detail.dispose();
    coins.dispose();
    rank.dispose();
  }

  Future<void> _setStatus(Map<String, dynamic> event, String status) async {
    try {
      await _db.from('live_events').update({'status': status}).eq('id', event['id']);
      await _load();
    } catch (error) {
      _notice('Event status was not changed: $error');
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Event Control')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Owner permission is required. This panel is not available to public accounts or Admin accounts.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE EVENT CONTROL'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createEvent,
        icon: const Icon(Icons.add),
        label: const Text('CREATE EVENT'),
      ),
      body: _loading && _events.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!)))
              : _events.isEmpty
                  ? const Center(child: Text('No events have been created yet. Use Create Event to publish the first schedule.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final id = event['id'].toString();
                          final rewards = _rewards[id] ?? const <Map<String, dynamic>>[];
                          final status = event['status'].toString();
                          return Card(
                            color: ZoonlTheme.surface,
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(event['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                                  _statusChip(status),
                                ]),
                                const SizedBox(height: 6),
                                Text(event['description']?.toString() ?? '', style: const TextStyle(color: ZoonlTheme.textSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                  '${event['event_type'].toString().toUpperCase()} • ${DateTime.parse(event['starts_at'].toString()).toLocal()}',
                                  style: const TextStyle(color: ZoonlTheme.champagneLight, fontSize: 11),
                                ),
                                const Divider(height: 20),
                                Row(children: [
                                  const Expanded(child: Text('REWARD LADDER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                                  TextButton.icon(
                                    onPressed: () => _addReward(event),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('ADD REWARD'),
                                  ),
                                ]),
                                if (rewards.isEmpty)
                                  const Text('No rewards configured for this event.', style: TextStyle(color: ZoonlTheme.textSecondary, fontSize: 12))
                                else
                                  for (final reward in rewards)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: ZoonlTheme.champagne.withOpacity(.16),
                                        child: Text(reward['rank_position'].toString(), style: const TextStyle(color: ZoonlTheme.champagne)),
                                      ),
                                      title: Text(reward['reward_name'].toString()),
                                      subtitle: Text(reward['reward_description']?.toString() ?? ''),
                                      trailing: Text('${reward['reward_coins']} coins', style: const TextStyle(color: ZoonlTheme.textSecondary, fontSize: 11)),
                                    ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, runSpacing: 6, children: [
                                  if (status == 'upcoming')
                                    OutlinedButton(onPressed: () => _setStatus(event, 'active'), child: const Text('START')),
                                  if (status == 'active')
                                    OutlinedButton(onPressed: () => _setStatus(event, 'completed'), child: const Text('COMPLETE')),
                                  if (status != 'cancelled' && status != 'completed')
                                    TextButton(onPressed: () => _setStatus(event, 'cancelled'), child: const Text('CANCEL EVENT')),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _statusChip(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: ZoonlTheme.champagne.withOpacity(.13),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: ZoonlTheme.champagne.withOpacity(.45)),
    ),
    child: Text(status.toUpperCase(), style: const TextStyle(color: ZoonlTheme.champagne, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}
