import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/backend.dart';
import 'profile_edit_screen.dart';

class SettingsCenterScreen extends StatelessWidget {
  const SettingsCenterScreen({super.key});

  static const Color _gold = Color(0xFFD6B46A);
  static const Color _panel = Color(0xFF17232E);
  static const Color _muted = Color(0xFFAAB5BE);

  void _showDetails(BuildContext context, String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17232E),
        title: Text(title, style: const TextStyle(color: _gold)),
        content: Text(detail, style: const TextStyle(color: _muted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ProfileEditScreen(),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use ZOONL LIVE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await Backend.logout();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $error')),
      );
    }
  }

  Widget _section(
    BuildContext context,
    String title,
    List<_SettingItem> items,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF354653)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 5),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(items[i].icon, color: _gold),
              title: Text(
                items[i].title,
                style: const TextStyle(
                  color: Color(0xFFF4F1E9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                items[i].subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: _muted),
              onTap: items[i].onTap,
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: Color(0xFF354653)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D14),
      appBar: AppBar(
        title: const Text('Settings Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF293B49), Color(0xFF17232E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withOpacity(.55)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZOONL LIVE',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Account, privacy and application preferences',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
              ],
            ),
          ),
          _section(context, 'Account', [
            _SettingItem(
              Icons.person_outline,
              'Profile information',
              'Photo, display name, country and bio',
              () => _openProfile(context),
            ),
            _SettingItem(
              Icons.link,
              'Linked accounts',
              'Review sign-in providers connected to this account',
              () => _showDetails(
                context,
                'Linked accounts',
                'Your current sign-in session is managed securely by Supabase Authentication. Account linking and unlinking require a verified provider flow and are not changed from this screen.',
              ),
            ),
            _SettingItem(
              Icons.lock_outline,
              'Password and security',
              'Sign-in protection and account access',
              () => _showDetails(
                context,
                'Password and security',
                'Use the Forgot Password option on the sign-in screen to request a secure password reset. This screen does not change your password or security credentials.',
              ),
            ),
          ]),
          _section(context, 'Privacy and safety', [
            _SettingItem(
              Icons.mark_chat_read_outlined,
              'Message privacy',
              'Choose who can send you messages',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const MessagePrivacyScreen(),
              )),
            ),
            _SettingItem(
              Icons.block_outlined,
              'Blocked users',
              'Review and unblock accounts you blocked',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const BlockedUsersScreen(),
              )),
            ),
            _SettingItem(
              Icons.notifications_active_outlined,
              'In-app notifications',
              'Read and mark account alerts as seen',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const InAppNotificationsScreen(),
              )),
            ),
            _SettingItem(
              Icons.report_gmailerrorred_outlined,
              'Report a problem',
              'Support contact and safety guidance',
              () => _showDetails(
                context,
                'Report a problem',
                'For urgent account or safety concerns, use the official ZOONL support contact published by the app owner. This client does not claim to submit a report until a verified support endpoint is connected.',
              ),
            ),
          ]),
          _section(context, 'Application preferences', [
            _SettingItem(
              Icons.palette_outlined,
              'Appearance',
              'Premium Obsidian and Champagne theme',
              () => _showDetails(
                context,
                'Appearance',
                'The current application theme is Premium Obsidian with Champagne Gold and Teal accents.',
              ),
            ),
            _SettingItem(
              Icons.notifications_none,
              'Notifications',
              'View your in-app notification inbox',
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const InAppNotificationsScreen(),
              )),
            ),
            _SettingItem(
              Icons.language,
              'Language',
              'Application language preferences',
              () => _showDetails(
                context,
                'Language',
                'Language selection will be connected to the application localization settings.',
              ),
            ),
          ]),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('LOG OUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE47777),
              side: const BorderSide(color: Color(0xFF8A4C52)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'ZOONL LIVE • Account Settings',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingItem(this.icon, this.title, this.subtitle, this.onTap);
}


class MessagePrivacyScreen extends StatefulWidget {
  const MessagePrivacyScreen({super.key});
  @override
  State<MessagePrivacyScreen> createState() => _MessagePrivacyScreenState();
}

class _MessagePrivacyScreenState extends State<MessagePrivacyScreen> {
  final _db = Supabase.instance.client;
  String _value = 'everyone';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw StateError('Login required.');
      final row = await _db.from('messaging_preferences')
          .select('allow_messages_from').eq('user_id', uid).maybeSingle();
      if (mounted) setState(() {
        _value = (row?['allow_messages_from'] ?? 'everyone').toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save(String value) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _db.from('messaging_preferences').upsert({
        'user_id': uid,
        'allow_messages_from': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      if (mounted) setState(() => _value = value);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Message Privacy')),
    backgroundColor: const Color(0xFF080D14),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(16), children: [
        const Text('WHO CAN MESSAGE YOU?', style: TextStyle(color: _gold, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        RadioListTile<String>(
          value: 'everyone', groupValue: _value, onChanged: _saving ? null : (v) { if (v != null) _save(v); },
          title: const Text('Everyone'), subtitle: const Text('Anyone can send you a message'),
        ),
        RadioListTile<String>(
          value: 'friends_only', groupValue: _value, onChanged: _saving ? null : (v) { if (v != null) _save(v); },
          title: const Text('Friends only'), subtitle: const Text('Only accepted friends can message you'),
        ),
        if (_saving) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        const Text('This setting is saved to your account messaging preferences.', style: TextStyle(color: _muted, fontSize: 12)),
      ]),
  );
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw StateError('Login required.');
      final raw = await _db.from('user_blocks').select('id,blocked_id,created_at')
          .eq('blocker_id', uid).order('created_at', ascending: false);
      final rows = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final ids = rows.map((e) => e['blocked_id'].toString()).toSet().toList();
      if (ids.isNotEmpty) {
        final profiles = await _db.from('profiles').select('id,display_name,avatar_url').inFilter('id', ids);
        final byId = {for (final p in profiles as List) p['id'].toString(): Map<String,dynamic>.from(p as Map)};
        for (final row in rows) { row['profile'] = byId[row['blocked_id'].toString()] ?? {}; }
      }
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _unblock(Map<String, dynamic> row) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw StateError('Login required.');
      await _db.from('user_blocks').delete()
          .eq('id', row['id']).eq('blocker_id', uid);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unblock failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked Users')),
    backgroundColor: const Color(0xFF080D14),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
      : _rows.isEmpty ? const Center(child: Text('You have not blocked anyone.', style: TextStyle(color: _muted)))
      : ListView.builder(itemCount: _rows.length, itemBuilder: (context, i) {
        final row = _rows[i];
        final profile = row['profile'] as Map<String, dynamic>? ?? {};
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (profile['avatar_url'] ?? '').toString().startsWith('http')
                ? NetworkImage(profile['avatar_url'].toString()) : null,
            child: (profile['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text((profile['display_name'] ?? 'ZOONL User').toString()),
          subtitle: Text(row['blocked_id'].toString(), style: const TextStyle(color: _muted, fontSize: 10)),
          trailing: TextButton(onPressed: () => _unblock(row), child: const Text('UNBLOCK')),
        );
      }),
  );
}

class InAppNotificationsScreen extends StatefulWidget {
  const InAppNotificationsScreen({super.key});
  @override
  State<InAppNotificationsScreen> createState() => _InAppNotificationsScreenState();
}

class _InAppNotificationsScreenState extends State<InAppNotificationsScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) throw StateError('Login required.');
      final raw = await _db.from('user_notifications').select(
        'id,title,body,notification_type,related_id,is_read,created_at')
        .eq('user_id', uid).order('created_at', ascending: false).limit(100);
      if (mounted) setState(() {
        _rows = (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('user_notifications').update({'is_read': true})
          .eq('id', row['id']).eq('user_id', uid);
      if (mounted) setState(() => row['is_read'] = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not mark notification read: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    backgroundColor: const Color(0xFF080D14),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
      : _rows.isEmpty ? const Center(child: Text('No notifications yet.', style: TextStyle(color: _muted)))
      : RefreshIndicator(onRefresh: _load, child: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final row = _rows[i];
          final read = row['is_read'] == true;
          return ListTile(
            leading: Icon(read ? Icons.notifications_none : Icons.notifications_active, color: read ? _muted : _gold),
            title: Text((row['title'] ?? 'ZOONL LIVE').toString()),
            subtitle: Text((row['body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: read ? null : TextButton(onPressed: () => _markRead(row), child: const Text('READ')),
          );
        },
      )),
  );
}
