
import 'dart:math';

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

            // Owner status is checked asynchronously by the trusted
            // Supabase function. Never grant Owner from a client-editable ID.
            return FutureBuilder<bool>(
              future: _loadOwnerStatus(),
              builder: (context, ownerSnapshot) {
                if (ownerSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final bool isOwner = ownerSnapshot.data == true;

                // Owner's canonical ZOONL ID is 10001, but the Owner role
                // itself comes only from the trusted Supabase RPC.
                final String profileUserId =
                    (profile['username'] ?? '').toString().trim();
                final String userId = isOwner ? '10001' : profileUserId;

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

                zoonl.ZoonlStore.instance.currentUser = {
                  'id': userId,
                  'name': (profile['display_name'] ?? '').toString(),
                  'isOwner': isOwner,
                  'trustedRole': isOwner ? 'OWNER' : 'USER',
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
      },
    );
  }

  Future<bool> _loadOwnerStatus() async {
    try {
      final dynamic result =
          await Backend.client.rpc('is_zoonl_owner');
      return result == true;
    } catch (_) {
      // Fail closed: an RPC/schema error must never grant Owner.
      return false;
    }
  }

  static const String _profileColumns =
      'id, username, display_name, avatar_url, country, '
      'language, bio, is_verified, user_level';

  String _newZoonlId() {
    // Numeric public ID only. This value never grants Owner/Admin access.
    return (Random.secure().nextInt(90000000) + 10000000).toString();
  }

  Future<Map<String, dynamic>?> _loadProfile(
    String authUserId,
  ) async {
    final client = Backend.client;

    Map<String, dynamic>? profile = await client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', authUserId)
        .maybeSingle();

    // A profile trigger may not have created the row. Try creating only
    // this authenticated user's own profile, without changing DB policies.
    if (profile == null) {
      final String candidateId = _newZoonlId();
      final metadataName =
          Backend.currentUser?.userMetadata?['display_name']?.toString() ??
              '';

      try {
        profile = await client
            .from('profiles')
            .insert({
              'id': authUserId,
              'username': candidateId,
              'display_name': metadataName,
            })
            .select(_profileColumns)
            .maybeSingle();
      } on PostgrestException {
        // If an Auth trigger created the row at the same time, read it again.
        profile = await client
            .from('profiles')
            .select(_profileColumns)
            .eq('id', authUserId)
            .maybeSingle();

        if (profile == null) rethrow;
      }
    }

    if (profile == null) {
      throw StateError(
        'Profile row create/read failed. Check the profiles table policy.',
      );
    }

    final existingId = profile['username']?.toString().trim() ?? '';
    if (existingId.isNotEmpty) return profile;

    // Existing accounts with an empty username receive a numeric ZOONL ID.
    // A unique-constraint collision is retried with another candidate.
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidateId = _newZoonlId();

      try {
        final updated = await client
            .from('profiles')
            .update({'username': candidateId})
            .eq('id', authUserId)
            .select(_profileColumns)
            .maybeSingle();

        if (updated != null &&
            (updated['username']?.toString().trim().isNotEmpty ?? false)) {
          return updated;
        }

        throw StateError(
          'ZOONL ID update returned no profile row. Check profile update policy.',
        );
      } on PostgrestException catch (error) {
        if (error.code == '23505') continue;
        rethrow;
      }
    }

    throw StateError(
      'Unique ZOONL ID could not be assigned after several attempts.',
    );
  }
}
