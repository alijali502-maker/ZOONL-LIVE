import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupVaultScreen extends StatefulWidget {
  const BackupVaultScreen({super.key});

  @override
  State<BackupVaultScreen> createState() => _BackupVaultScreenState();
}

class _BackupVaultScreenState extends State<BackupVaultScreen> {
  final _client = Supabase.instance.client;
  late Future<Map<String, dynamic>> _future;
  final _ownerLookup = TextEditingController();
  bool _isOwner = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    try {
      final value = await _client.rpc('is_zoonl_owner');
      if (mounted) setState(() => _isOwner = value == true);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _load([String? targetUserId]) async {
    final result = await _client.rpc('zoonl_backup_vault', params: targetUserId == null
        ? <String, dynamic>{}
        : <String, dynamic>{'p_user_id': targetUserId});
    if (result is! Map) throw const FormatException('Backup response is invalid.');
    return Map<String, dynamic>.from(result);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Widget _section(String title, IconData icon, List<Map<String, dynamic>> items,
      {String empty = 'Nothing saved in this section yet.'}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12101E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x665E4A85)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFFE6C47A), size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: const TextStyle(
            color: Color(0xFFE6C47A), fontWeight: FontWeight.w800, letterSpacing: .7))),
          Text('${items.length}', style: const TextStyle(color: Colors.white60)),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(empty, style: const TextStyle(color: Colors.white54, fontSize: 12)))
        else
          ...items.map((item) {
            final name = (item['name'] ?? item['title'] ?? item['code'] ??
                item['tier_name'] ?? item['item_type'] ?? 'Saved item').toString();
            final media = (item['media_url'] ?? '').toString();
            final expires = item['expires_at']?.toString();
            final equipped = item['equipped'] == true || item['is_active'] == true ||
                item['is_enabled'] == true;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF241A38),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x66E6C47A)),
                ),
                clipBehavior: Clip.antiAlias,
                child: media.startsWith('http')
                    ? Image.network(media, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: Color(0xFFE6C47A)))
                    : const Icon(Icons.inventory_2_outlined, color: Color(0xFFE6C47A)),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(expires == null ? 'Stored in your account backup' : 'Expiry: $expires',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: equipped
                  ? const Text('ACTIVE', style: TextStyle(color: Color(0xFF8ED7B5), fontSize: 10, fontWeight: FontWeight.bold))
                  : const Icon(Icons.cloud_done_outlined, color: Colors.white38, size: 18),
            );
          }),
      ]),
    );
  }

  @override
  void dispose() {
    _ownerLookup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080611),
      appBar: AppBar(
        backgroundColor: const Color(0xFF100C1D),
        title: const Text('MY BACKUP VAULT', style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [IconButton(
          onPressed: () => setState(() => _future = _load()),
          icon: const Icon(Icons.refresh, color: Color(0xFFB88AFF)),
        )],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE6C47A)));
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, color: Colors.white54, size: 36),
                const SizedBox(height: 12),
                const Text('Backup could not be loaded.', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(snapshot.error.toString(), textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                TextButton(onPressed: () => setState(() => _future = _load()),
                  child: const Text('TRY AGAIN')),
              ]),
            ));
          }
          final data = snapshot.data!;
          final profile = data['profile'] is Map
              ? Map<String, dynamic>.from(data['profile'] as Map)
              : <String, dynamic>{};
          final profileItems = _items(data, 'profile_items');
          final dp = _items(data, 'dp');
          final entry = _items(data, 'entry');
          final prime = _items(data, 'prime');
          final frames = _items(data, 'frames');
          final visuals = _items(data, 'visuals');
          final other = _items(data, 'other_items');
          final profileSummary = <Map<String, dynamic>>[
            if ((profile['profile_background_url'] ?? '').toString().isNotEmpty)
              {'title': 'Profile Background', 'media_url': profile['profile_background_url']},
            if ((profile['display_name'] ?? '').toString().isNotEmpty)
              {'title': 'Display Name', 'name': profile['display_name']},
            if ((profile['bio'] ?? '').toString().isNotEmpty)
              {'title': 'Bio', 'name': profile['bio']},
            ...profileItems,
          ];
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_isOwner) Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12101E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x66E6C47A)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('OWNER BACKUP LOOKUP', style: TextStyle(
                    color: Color(0xFFE6C47A), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _ownerLookup,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter user ZOONL ID',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                      ),
                    )),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFFE6C47A)),
                      onPressed: () async {
                        final zid = _ownerLookup.text.trim();
                        if (zid.isEmpty) return;
                        try {
                          final row = await _client.from('user_public_profiles')
                              .select('user_id').eq('zoonl_id', zid).maybeSingle();
                          final target = row?['user_id']?.toString();
                          if (target == null || target.isEmpty) {
                            setState(() => _lookupError = 'User ID not found.');
                            return;
                          }
                          setState(() {
                            _lookupError = null;
                            _future = _load(target);
                          });
                        } catch (e) {
                          setState(() => _lookupError = 'Backup lookup failed: $e');
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'My backup',
                      icon: const Icon(Icons.person, color: Colors.white70),
                      onPressed: () => setState(() {
                        _lookupError = null;
                        _ownerLookup.clear();
                        _future = _load();
                      }),
                    ),
                  ]),
                  if (_lookupError != null) Text(_lookupError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF24183A), Color(0xFF11101D)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x77E6C47A)),
                ),
                child: Row(children: [
                  const Icon(Icons.cloud_done, color: Color(0xFFE6C47A), size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AUTOMATIC ACCOUNT VAULT', style: TextStyle(
                      color: Color(0xFFE6C47A), fontWeight: FontWeight.w900, letterSpacing: .6)),
                    const SizedBox(height: 4),
                    Text('Account: ${profile['display_name'] ?? profile['username'] ?? 'ZOONL User'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const Text('Live records from your original Supabase inventory',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ])),
                ]),
              ),
              _section('DP / PROFILE PHOTO', Icons.account_circle_outlined, dp),
              _section('PROFILE & BACKGROUNDS', Icons.wallpaper, profileSummary),
              _section('FRAMES & VISUAL EFFECTS', Icons.auto_awesome, [...frames, ...visuals]),
              _section('LIVE ENTRY EFFECTS', Icons.flash_on, entry),
              _section('PRIME MEMBERSHIP', Icons.workspace_premium, prime),
              _section('OTHER OWNED ITEMS', Icons.inventory_2_outlined, other),
            ],
          );
        },
      ),
    );
  }
}
