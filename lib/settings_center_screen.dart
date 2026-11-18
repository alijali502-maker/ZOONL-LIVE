import 'package:flutter/material.dart';

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
              Icons.people_outline,
              'Friends and followers',
              'Friend list visibility and social connections',
              () => _showDetails(
                context,
                'Friends and followers',
                'Friend-list visibility is currently shown in your profile settings. Persistent privacy controls will be connected to the verified account settings service before they are presented as saved.',
              ),
            ),
            _SettingItem(
              Icons.block_outlined,
              'Blocked users',
              'Review accounts you have blocked',
              () => _showDetails(
                context,
                'Blocked users',
                'The blocked-user management screen requires the account safety records to be connected. No blocked-user data is fabricated here.',
              ),
            ),
            _SettingItem(
              Icons.report_gmailerrorred_outlined,
              'Report a problem',
              'Safety, abuse and technical support',
              () => _showDetails(
                context,
                'Report a problem',
                'The support submission workflow will be connected to the official ZOONL support service.',
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
              'Live, messages, gifts and account alerts',
              () => _showDetails(
                context,
                'Notifications',
                'Notification preferences will be saved when the push-notification settings service is connected.',
              ),
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
