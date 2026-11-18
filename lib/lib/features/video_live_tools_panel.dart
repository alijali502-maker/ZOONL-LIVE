import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/backend.dart';

class VideoLiveToolsPanel extends StatefulWidget {
  final String roomId;
  final String ownerId;
  final bool isHost;
  const VideoLiveToolsPanel({super.key, required this.roomId, required this.ownerId, required this.isHost});

  @override
  State<VideoLiveToolsPanel> createState() => _VideoLiveToolsPanelState();
}

class _VideoLiveToolsPanelState extends State<VideoLiveToolsPanel> {
  final _db = Supabase.instance.client;
  bool _sending = false;
  String? _notice;

  Future<List<Map<String, dynamic>>> _rows(String table, {String? order}) async {
    dynamic q = _db.from(table).select();
    if (table == 'zoonl_live_gifts') {
      q = q.eq('project_name', 'ZOONL LIVE').eq('is_active', true);
    } else if (table == 'live_room_members' || table == 'room_live_sessions' ||
        table == 'room_display_settings' || table == 'room_access_logs') {
      q = q.eq('room_id', widget.roomId);
    } else if (table == 'pk_battles') {
      q = q.eq('battle_status', 'active');
    }
    if (order != null) q = q.order(order, ascending: false);
    final data = await q.limit(80);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _sendGift(Map<String, dynamic> gift) async {
    if (_sending) return;
    setState(() { _sending = true; _notice = null; });
    try {
      await Backend.sendZoonlLiveGift(roomId: widget.roomId, giftId: gift['id'].toString());
      if (mounted) setState(() => _notice = '${gift['zoonl_gift_name']} भेज दिया गया।');
    } catch (e) {
      if (mounted) setState(() => _notice = 'Gift नहीं भेजा गया: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _section(String title, Future<List<Map<String, dynamic>>> future,
      Widget Function(Map<String, dynamic>) tile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('डेटा लोड नहीं हुआ: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return Center(child: Text('$title अभी उपलब्ध नहीं है।', style: const TextStyle(color: Colors.white70)));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) => tile(rows[i]),
        );
      },
    );
  }

  Widget _tile(IconData icon, String title, String subtitle) => ListTile(
    leading: Icon(icon, color: const Color(0xFFE5BD70)),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .78,
      decoration: const BoxDecoration(
        color: Color(0xFF171020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 5,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(8))),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('VIDEO LIVE CONTROL CENTER', style: TextStyle(color: Color(0xFFE5BD70), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const TabBar(
            isScrollable: true,
            labelColor: Color(0xFFE5BD70),
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.card_giftcard), text: 'Gifts'),
              Tab(icon: Icon(Icons.people), text: 'Viewers'),
              Tab(icon: Icon(Icons.history), text: 'History'),
              Tab(icon: Icon(Icons.tune), text: 'Settings'),
              Tab(icon: Icon(Icons.sports_kabaddi), text: 'PK'),
            ],
          ),
          if (_notice != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_notice!, style: const TextStyle(color: Color(0xFFE5BD70)))),
          Expanded(child: TabBarView(children: [
            _section('Gifts', _rows('zoonl_live_gifts', order: 'sort_order'), (g) => Card(
              color: const Color(0xFF251A32),
              child: ListTile(
                leading: const Icon(Icons.card_giftcard, color: Color(0xFFE5BD70)),
                title: Text('${g['zoonl_gift_name'] ?? 'Gift'}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('${g['coin_price'] ?? 0} coins', style: const TextStyle(color: Colors.white60)),
                trailing: widget.isHost ? const Text('Host', style: TextStyle(color: Colors.white38)) :
                  TextButton(onPressed: _sending ? null : () => _sendGift(g), child: Text(_sending ? 'Sending' : 'Send')),
              ),
            )),
            _section('Viewers', _rows('live_room_members', order: 'joined_at'), (m) =>
              _tile(Icons.person, 'Viewer ${(m['user_id'] ?? '').toString().substring(0, 8)}', '${m['member_role'] ?? 'viewer'} • ${m['joined_at'] ?? ''}')),
            _section('History', _rows('room_live_sessions', order: 'created_at'), (s) =>
              _tile(Icons.history, '${s['stream_type'] ?? 'Live'} • ${s['session_status'] ?? 'session'}', 'Start: ${s['started_at'] ?? 'not recorded'}  End: ${s['ended_at'] ?? 'ongoing'}')),
            _section('Settings', _rows('room_display_settings', order: 'updated_at'), (s) =>
              _tile(Icons.settings, '${s['display_type'] ?? 'Room display'}', (s['display_config'] ?? {}).toString())),
            _section('PK', _rows('pk_battles', order: 'started_at'), (b) =>
              _tile(Icons.sports_kabaddi, 'Battle #${b['id']} • ${b['battle_type'] ?? 'PK'}', '${b['battle_status']} • ${b['duration_minutes'] ?? 0} min')),
          ])),
        ]),
      ),
    );
  }
}
