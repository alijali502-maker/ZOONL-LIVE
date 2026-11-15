
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'login_screen.dart';
import 'main.dart' as zoonl;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
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

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;

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
                body: Center(child: CircularProgressIndicator()),
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
                          onPressed: () => client.auth.signOut(),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data!;
            final userId = (profile['username'] ?? '').toString();

            if (userId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('User ID is not assigned yet.'),
                ),
              );
            }

            final isOwner = userId == zoonl.ZoonlStore.ownerId;

            zoonl.ZoonlStore.instance.currentUser = {
              'id': userId,
              'name': (profile['display_name'] ?? '').toString(),
              'isOwner': isOwner,
              'isVerifiedStreamer': profile['is_verified'] == true,
              'level': profile['user_level'] ?? 1,
              'coins': 0,
              'diamonds': 0,
              'sentCoins': 0,
              'walletBalance': 0.0,
              'vipTier': 'NONE',
              'isNewId': false,
              'trialExpiresAt': null,
              'friendListPublic': true,
              'linkedAccounts': ['Email Auth'],
              'payoutLocked': !isOwner,
              'payoutMethod': '',
              'payoutAccount': '',
              'registrationType': isOwner ? 'OWNER' : 'USER',
              'approved': true,
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

  Future<Map<String, dynamic>?> _loadProfile(String authUserId) async {
    final result = await Supabase.instance.client
        .from('profiles')
        .select(
          'id, username, display_name, avatar_url, country, language, bio, is_verified, user_level',
        )
        .eq('id', authUserId)
        .maybeSingle();

    return result;
  }
}
