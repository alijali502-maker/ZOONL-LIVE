import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_screen.dart';

// List of rooms that are live right now. Tap one to watch.
class LiveRoomsScreen extends StatefulWidget {
  final String userName;
  final String userId;

  const LiveRoomsScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<LiveRoomsScreen> createState() => _LiveRoomsScreenState();
}

class _LiveRoomsScreenState extends State<LiveRoomsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final me = _supabase.auth.currentUser?.id;

    final base = _supabase
        .from('live_rooms')
        .select('id, room_name, room_type, country')
        .eq('is_live', true);

    final filtered = me == null ? base : base.neq('owner_id', me);

    final rows = await filtered.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _open(String roomId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => LiveScreen(
              userName: widget.userName,
              userId: widget.userId,
              joinRoomId: roomId,
            ),
          ),
        )
        .then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1225),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'LIVE NOW',
          style: TextStyle(
            color: Color(0xFFE5BD70),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE5BD70),
                ),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'List नहीं खुली: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            final rooms = snapshot.data ?? [];

            if (rooms.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'अभी कोई Live चालू नहीं है।\nनीचे खींचकर refresh करें।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final room = rooms[index];

                return ListTile(
                  onTap: () => _open(room['id'].toString()),
                  tileColor: const Color(0xFF241630),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(
                    Icons.circle,
                    color: Colors.red,
                    size: 14,
                  ),
                  title: Text(
                    (room['room_name'] ?? '').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    (room['country'] ?? room['room_type'] ?? '')
                        .toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFE5BD70),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
