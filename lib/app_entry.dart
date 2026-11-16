
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/backend.dart';
import 'login_screen.dart';
import 'main.dart' as zoonl;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Backend.initialize(
    supabaseUrl: AppConfig.supabaseUrl,
    supabaseAnonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ZoonlEntryApp());
}

class ZoonlEntryApp extends StatelessWidget {
  const ZoonlEntryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ZoonlAuthGate(),
    );
  }
}

class ZoonlAuthGate extends StatelessWidget {
  const ZoonlAuthGate({super.key});

  const ZoonlAuthGate._();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Backend.authChanges,
      builder: (context, snapshot) {
        final user = Backend.currentUser;

        if (user == null) {
          return LoginScreen(
            onAuthenticated: () {},
          );
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _loadProfile(user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (profileSnapshot.hasError ||
                profileSnapshot.data == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Profile not found. Please contact support.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: Backend.logout,
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data!;
            final userId =
                (profile['username'] ?? '').toString().trim();

            if (userId.isEmpty) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('User ID is not assigned yet.'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: Backend.logout,
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Never grant Owner authority using a public username or ID.
            // Owner access must be verified by a trusted server-side role.
            const bool isOwner = false;

            zoonl.ZoonlStore.instance.currentUser = {
              'id': userId,
              'name': (profile['display_name'] ?? '').toString(),
              'isOwner': isOwner,
              'isVerifiedStreamer': profile['is_verified'] == true,
              'level': profile['user_level'] ?? 1,

              // Wallet values are not loaded from a verified ledger here.
              'coins': 0,
              'diamonds': 0,
              'sentCoins': 0,
              'walletBalance': 0.0,

              'vipTier': 'NONE',
              'isNewId': false,
              'trialExpiresAt': null,
              'friendListPublic': true,
              'linkedAccounts': ['Email Auth'],
              'payoutLocked': true,
              'payoutMethod': '',
              'payoutAccount': '',
              'registrationType': 'USER',
              'approved': false,
              'isLive': false,
              'offlineSince': null,
              'avatarUrl': profile['avatar_url'],
              'country': profile['country'],
              'language': profile['language'],
              'bio': profile['bio'],
            };

            return const zoonl.ZoonlMainShell();
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadProfile(
    String authUserId,
  ) async {
    return Backend.client
        .from('profiles')
        .select(
          'id, username, display_name, avatar_url, country, '
          'language, bio, is_verified, user_level',
        )
        .eq('id', authUserId)
        .maybeSingle();
  }
}
