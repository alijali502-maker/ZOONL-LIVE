
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/backend.dart';
import 'core/zoonl_theme.dart';
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
      theme: ZoonlTheme.dark,
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
                        Text(
                          profileSnapshot.hasError
                              ? 'Profile setup failed: ${profileSnapshot.error}'
                              : 'Profile record नहीं मिली। कृपया दोबारा Login करें।',
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
            int serverLevel = (profile['user_level'] as num?)?.toInt() ?? 1;
            try {
              final dynamic resolvedLevel = await Backend.client.rpc('zoonl_my_level');
              if (resolvedLevel is num) serverLevel = resolvedLevel.toInt();
            } catch (_) {
              // Keep the stored profile level if the trusted level RPC is unavailable.
            }

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
                    (profile['zoonl_id'] ?? '').toString().trim();
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

                return FutureBuilder<_HomeData>(
                  future: _loadHomeData(user.id),
                  builder: (context, homeSnapshot) {
                    if (homeSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final home = homeSnapshot.data ?? _HomeData.empty();
                    zoonl.ZoonlStore.instance.currentUser = {
                      'id': userId,
                      'name': (profile['display_name'] ?? '').toString(),
                      'isOwner': isOwner,
                      'trustedRole': isOwner ? 'OWNER' : 'USER',
                      'isVerifiedStreamer': profile['is_verified'] == true,
                      'level': serverLevel,
                      'coins': (home.wallet['coins'] as num?)?.toInt() ?? 0,
                      'diamonds': (home.wallet['diamonds'] as num?)?.toInt() ?? 0,
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
                      'profileBackgroundUrl': profile['profile_background_url'],
                      'country': profile['country'],
                      'language': profile['language'],
                      'bio': profile['bio'],
                    };

                    final appStore = zoonl.ZoonlStore.instance;
                    appStore.setAppMode(zoonl.ZoonlAppMode.live);
                    appStore.memberships = home.memberships;
                    appStore.walletTransactions = home.walletTransactions;
                    appStore.agencyApplications = home.agencyApplications;
                    appStore.giftCatalog = home.gifts;
                    appStore.cosmeticsCatalog = home.cosmetics;
                    appStore.primeTiers = home.primeTiers;
                    appStore.userBaggage = home.baggage;
                    appStore.userTrial = home.userTrial;
                    appStore.backupStore
                      ..clear()
                      ..addAll(home.baggage.where((item) {
                        final expiry = DateTime.tryParse(item['expires_at']?.toString() ?? '');
                        return item['acquired_via'] == 'NEW_ID_TRIAL' &&
                            expiry != null && expiry.isBefore(DateTime.now());
                      }));
                    appStore.streamers
                      ..clear()
                      ..addAll(home.rooms.map((room) => <String, dynamic>{
                        'roomId': room['id'],
                        'userId': room['owner_id'],
                        'name': room['room_name'] ?? 'ZOONL LIVE Host',
                        'mode': (room['room_type'] ?? 'VIDEO').toString().toUpperCase(),
                        'isLive': room['is_live'] == true,
                        'viewerCount': room['viewer_count'] ?? 0,
                        'receivedCoins': 0,
                        'giftersHistory': <dynamic>[],
                        'videoCallOpen': false,
                        'isPrivate': room['is_private'] == true,
                        'isLocked': room['is_locked'] == true,
                      }));

                    return const zoonl.ZoonlMainShell();
                  },
                );

              },
            );
          },
        );
      },
    );
  }

  Future<_HomeData> _loadHomeData(String authUserId) async {
    Map<String, dynamic> wallet = <String, dynamic>{};
    List<Map<String, dynamic>> rooms = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> memberships = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> agencyApplications = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> gifts = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> cosmetics = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> primeTiers = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> baggage = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> walletTransactions = <Map<String, dynamic>>[];
    Map<String, dynamic> userTrial = <String, dynamic>{};

    try {
      await Backend.client.rpc('expire_zoonl_user_trial');
    } catch (_) {}

    try {
      final trial = await Backend.client
          .from('zoonl_user_trials')
          .select('started_at, expires_at, trial_status, svip_active')
          .eq('user_id', authUserId)
          .maybeSingle();
      if (trial != null) userTrial = Map<String, dynamic>.from(trial);
    } catch (_) {
      userTrial = <String, dynamic>{};
    }

    try {
      wallet = await Backend.client
          .from('wallets')
          .select('coins, diamonds')
          .eq('user_id', authUserId)
          .maybeSingle() ?? <String, dynamic>{};
    } catch (_) {
      // Never invent balances when the wallet cannot be read.
    }

    try {
      final result = await Backend.client
          .from('live_rooms')
          .select('id, owner_id, room_name, room_type, is_live, is_private, is_locked, viewer_count')
          .eq('is_live', true)
          .order('created_at', ascending: false);
      rooms = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      rooms = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('user_prime_memberships')
          .select('id, prime_tier_id, started_at, expires_at, is_active')
          .eq('user_id', authUserId)
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('started_at', ascending: false);
      memberships = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      memberships = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('agency_applications')
          .select('id, proposed_name, contact_details, application_status, reviewed_at, created_at')
          .eq('applicant_id', authUserId)
          .order('created_at', ascending: false);
      agencyApplications = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      agencyApplications = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('gifts')
          .select('id, gift_name, image_url, animation_url, animation_3d_url, sound_url, preview_url, coin_price, diamond_value, category, gift_config')
          .eq('is_active', true)
          .order('coin_price', ascending: true);
      gifts = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      gifts = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('zoonl_live_cosmetics')
          .select('id, zoonl_item_code, zoonl_item_name, item_type, media_url, sound_fx, color_theme_hex, duration_sec, min_level_req, coin_price, reward_points')
          .eq('project_name', 'ZOONL LIVE')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      cosmetics = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      cosmetics = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('prime_tiers')
          .select('id, tier_name, benefits')
          .eq('is_active', true)
          .order('id', ascending: true);
      primeTiers = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      primeTiers = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('wallet_transactions')
          .select('id, transaction_type, currency, amount, description, created_at')
          .eq('user_id', authUserId)
          .order('created_at', ascending: false)
          .limit(30);
      walletTransactions = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      walletTransactions = <Map<String, dynamic>>[];
    }

    try {
      final rows = await Backend.client
          .from('zoonl_live_user_baggage')
          .select('id, zoonl_item_code, item_type, is_equipped, acquired_via, expires_at, created_at')
          .eq('project_name', 'ZOONL LIVE')
          .eq('user_id', authUserId)
          .order('created_at', ascending: false);
      baggage = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      baggage = <Map<String, dynamic>>[];
    }

    return _HomeData(
      wallet: wallet,
      rooms: rooms,
      memberships: memberships,
      agencyApplications: agencyApplications,
      gifts: gifts,
      cosmetics: cosmetics,
      primeTiers: primeTiers,
      baggage: baggage,
      walletTransactions: walletTransactions,
      userTrial: userTrial,
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
      'id, username, display_name, avatar_url, profile_background_url, country, '
      'language, bio, is_verified, user_level';

  Future<Map<String, dynamic>?> _loadProfile(
    String authUserId,
  ) async {
    final client = Backend.client;

    Map<String, dynamic>? profile = await client
        .from('profiles')
        .select(_profileColumns)
        .eq('id', authUserId)
        .maybeSingle();

    if (profile == null) {
      final metadataName =
          Backend.currentUser?.userMetadata?['display_name']?.toString() ?? '';
      try {
        profile = await client
            .from('profiles')
            .insert({
              'id': authUserId,
              'display_name': metadataName,
            })
            .select(_profileColumns)
            .maybeSingle();
      } on PostgrestException {
        // An auth trigger may have inserted the row concurrently.
        profile = await client
            .from('profiles')
            .select(_profileColumns)
            .eq('id', authUserId)
            .maybeSingle();
        if (profile == null) rethrow;
      }
    }

    if (profile == null) {
      throw StateError('Profile row create/read failed. Check profiles RLS.');
    }

    // The numeric public ZOONL ID belongs to user_public_profiles. Never
    // mint a random ID into profiles.username or use it as authorization.
    final publicProfile = await client
        .from('user_public_profiles')
        .select('zoonl_id')
        .eq('user_id', authUserId)
        .maybeSingle();

    final zoonlId = publicProfile?['zoonl_id']?.toString().trim() ?? '';
    if (zoonlId.isEmpty) {
      throw StateError(
        'ZOONL ID is missing from user_public_profiles for this account.',
      );
    }

    return <String, dynamic>{
      ...profile,
      'zoonl_id': zoonlId,
    };
  }
}

class _HomeData {
  final Map<String, dynamic> wallet;
  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> memberships;
  final List<Map<String, dynamic>> agencyApplications;
  final List<Map<String, dynamic>> gifts;
  final List<Map<String, dynamic>> cosmetics;
  final List<Map<String, dynamic>> primeTiers;
  final List<Map<String, dynamic>> baggage;
  final List<Map<String, dynamic>> walletTransactions;
  final Map<String, dynamic> userTrial;

  const _HomeData({
    required this.wallet,
    required this.rooms,
    required this.memberships,
    required this.agencyApplications,
    required this.gifts,
    required this.cosmetics,
    required this.primeTiers,
    required this.baggage,
    required this.walletTransactions,
    required this.userTrial,
  });

  factory _HomeData.empty() => const _HomeData(
    wallet: <String, dynamic>{},
    rooms: <Map<String, dynamic>>[],
    memberships: <Map<String, dynamic>>[],
    agencyApplications: <Map<String, dynamic>>[],
    gifts: <Map<String, dynamic>>[],
    cosmetics: <Map<String, dynamic>>[],
    primeTiers: <Map<String, dynamic>>[],
    baggage: <Map<String, dynamic>>[],
    walletTransactions: <Map<String, dynamic>>[],
    userTrial: <String, dynamic>{},
  );
}
