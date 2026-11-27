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
        .select('id, room_name, room_type, country, poster_url')
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

                final poster = (room['poster_url'] ?? '').toString();
                return InkWell(
                  onTap: () => _open(room['id'].toString()),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 112,
                    decoration: BoxDecoration(
                      color: const Color(0xFF241630),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x665F3A88)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(children: [
                      SizedBox(
                        width: 126,
                        height: double.infinity,
                        child: poster.isNotEmpty
                            ? Image.network(poster, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFF302044),
                                  child: Icon(Icons.live_tv, color: Color(0xFFE5BD70), size: 36),
                                ))
                            : const ColoredBox(
                                color: Color(0xFF302044),
                                child: Icon(Icons.live_tv, color: Color(0xFFE5BD70), size: 36),
                              ),
                      ),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Row(children: [
                            const Icon(Icons.circle, color: Colors.red, size: 9),
                            const SizedBox(width: 6),
                            const Text('LIVE NOW', style: TextStyle(color: Color(0xFFFF7777), fontSize: 9, fontWeight: FontWeight.w900)),
                          ]),
                          const SizedBox(height: 6),
                          Text((room['room_name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 5),
                          Text((room['country'] ?? room['room_type'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ]),
                      )),
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(Icons.chevron_right, color: Color(0xFFE5BD70)),
                      ),
                    ]),
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
