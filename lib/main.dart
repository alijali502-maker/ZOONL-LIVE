import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'core/app_config.dart';
import 'core/backend.dart';
import 'login_screen.dart';
import 'features/zoonl_feature_hub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await Backend.initialize(
    supabaseUrl: AppConfig.supabaseUrl,
    supabaseAnonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ZoonlApp());
}

const Color bg = Color(0xFF080611);
const Color panel = Color(0xFF171126);
const Color panel2 = Color(0xFF211735);
const Color purple = Color(0xFF9360F5);
const Color purple2 = Color(0xFF542CA0);
const Color gold = Color(0xFFE6C47A);
const Color muted = Color(0xFFAAA1BC);
const Color pink = Color(0xFFDA65C8);

class ZoonlApp extends StatelessWidget {
  const ZoonlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Supabase.instance.client;
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (db.auth.currentSession == null) {
            return const LoginScreen();
          }
          return MainScreen(
            key: ValueKey(db.auth.currentUser?.id),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SupabaseClient db = Supabase.instance.client;
  final AudioPlayer audioPlayer = AudioPlayer();

  int tab = 0;
  bool loading = true;
  bool sendingGift = false;
  bool isOwner = false;
  bool canManageTopups = false;
  int adminCoinLimit = 0;
  int adminCoinsUsed = 0;
  String activeEntryEffect = 'Standard Entry';
  String activeVipFrame = 'Royal Frame';

  Map<String, dynamic> profile = {};
  Map<String, dynamic> publicProfile = {};
  Map<String, dynamic> wallet = {};

  List> rooms = [];
  List> gifts = [];
  List> transactions = [];
  List> memberships = [];
  List> agencyApplications = [];
  List> adminLimits = [];

  String? loadError;

  String get userId => db.auth.currentUser?.id ?? '';
  String get zoonlId => publicProfile['zoonl_id']?.toString() ?? '';
  int get userLevel => number(profile['user_level'], fallback: 1);

  int get coins => number(wallet['coins']);
  int get diamonds => number(wallet['diamonds']);

  static const List> coinPackages = [
    {'usd': 10, 'coins': 30000},
    {'usd': 20, 'coins': 60000},
    {'usd': 30, 'coins': 90000},
    {'usd': 40, 'coins': 120000},
    {'usd': 50, 'coins': 150000},
    {'usd': 60, 'coins': 180000},
  ];

  static const List> agencyPaidPlans = [
    {'plan': 'Starter Agency', 'fee_coins': 50000, 'max_hosts': 15},
    {'plan': 'Pro Agency', 'fee_coins': 120000, 'max_hosts': 50},
    {'plan': 'Elite Agency', 'fee_coins': 250000, 'max_hosts': 200},
  ];

  int number(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String value(dynamic input, [String fallback = 'Not available']) {
    if (input == null || input.toString().trim().isEmpty) {
      return fallback;
    }
    return input.toString();
  }

  Color get levelAccentColor {
    if (isOwner || zoonlId == '10001') return gold;
    if (userLevel >= 70) return const Color(0xFFFF4D6D);
    if (userLevel >= 40) return pink;
    if (userLevel >= 20) return purple;
    if (userLevel >= 10) return const Color(0xFF4CC9F0);
    return const Color(0xFF6DDBA5);
  }

  Color get levelSurfaceColor {
    if (isOwner || zoonlId == '10001') return const Color(0xFF3A2810);
    if (userLevel >= 70) return const Color(0xFF331022);
    if (userLevel >= 40) return const Color(0xFF2E1236);
    if (userLevel >= 20) return const Color(0xFF211735);
    return panel;
  }

  String get levelBadgeLabel {
    if (isOwner || zoonlId == '10001') return 'OWNER VIP • LV.$userLevel';
    if (userLevel >= 70) return 'MYTHIC ID • LV.$userLevel';
    if (userLevel >= 40) return 'ROYAL ID • LV.$userLevel';
    if (userLevel >= 20) return 'PRO ID • LV.$userLevel';
    return 'STAR ID • LV.$userLevel';
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (userId.isEmpty) return;

    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }

    await Future.wait([
      loadProfile(),
      loadPublicProfile(),
      loadWallet(),
      loadRooms(),
      loadGifts(),
      loadTransactions(),
      loadMemberships(),
    ]);

    await loadPermissions();
    await loadAgencyApplications();
    await loadAdminLimits();

    if (isOwner || zoonlId == '10001') {
      activeEntryEffect = 'OWNER SOVEREIGN ENTRY';
      activeVipFrame = 'OWNER SUPREME VIP FRAME';
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> loadPermissions() async {
    isOwner = false;
    canManageTopups = false;
    adminCoinLimit = 0;
    adminCoinsUsed = 0;

    try {
      final result = await db.rpc('is_zoonl_owner');
      isOwner = (result == true) || zoonlId == '10001';

      if (isOwner) {
        canManageTopups = true;
        adminCoinLimit = 999999999;
        return;
      }

      final rows = await db
          .from('owner_admin_permissions')
          .select('id, coin_limit, coins_used')
          .eq('admin_user_id', userId)
          .eq('permission_key', 'manage_topups')
          .eq('is_allowed', true)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        canManageTopups = true;
        final row = Map<String, dynamic>.from(rows.first as Map);
        adminCoinLimit = number(row['coin_limit']);
        adminCoinsUsed = number(row['coins_used']);
      }
    } catch (_) {
      isOwner = zoonlId == '10001';
      canManageTopups = isOwner;
    }
  }

  Future<void> loadAdminLimits() async {
    if (!isOwner) {
      adminLimits = [];
      return;
    }
    try {
      final rows = await db
          .from('owner_admin_permissions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      adminLimits = List>.from(rows as List);
    } catch (_) {
      adminLimits = [];
    }
  }

  Future<void> loadProfile() async {
    try {
      profile = await db
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle() ??
          {};
    } catch (_) {
      profile = {};
    }
  }

  Future<void> loadPublicProfile() async {
    try {
      publicProfile = await db
              .from('user_public_profiles')
              .select()
              .eq('user_id', userId)
              .maybeSingle() ??
          {};
    } catch (_) {
      publicProfile = {};
    }
  }

  Future<void> loadWallet() async {
    try {
      wallet = await db
              .from('wallets')
              .select()
              .eq('user_id', userId)
              .maybeSingle() ??
          {};
    } catch (e) {
      wallet = {};
      loadError = e.toString();
    }
  }

  Future<void> loadRooms() async {
    try {
      final result = await db
          .from('live_rooms')
          .select()
          .eq('is_live', true)
          .order('created_at', ascending: false)
          .limit(50);
      rooms = List>.from(result as List);
    } catch (_) {
      rooms = [];
    }
  }

  Future<void> loadGifts() async {
    try {
      final result = await db
          .from('gifts')
          .select()
          .eq('is_active', true)
          .order('coin_price')
          .limit(100);
      gifts = List>.from(result as List);
    } catch (_) {
      gifts = [];
    }
  }

  Future<void> loadTransactions() async {
    try {
      final result = await db
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      transactions = List>.from(result as List);
    } catch (_) {
      transactions = [];
    }
  }

  Future<void> loadMemberships() async {
    try {
      final result = await db
          .from('user_prime_memberships')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(10);
      memberships = List>.from(result as List);
    } catch (_) {
      memberships = [];
    }
  }

  Future<void> loadAgencyApplications() async {
    if (!isOwner) {
      agencyApplications = [];
      return;
    }
    try {
      final result = await db
          .from('agency_applications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      agencyApplications = List>.from(result as List);
    } catch (_) {
      agencyApplications = [];
    }
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: panel2,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String friendlyError(Object error) {
    final e = error.toString().toUpperCase();

    if (e.contains('TOPUP_PERMISSION_DENIED')) {
      return 'Owner ने Top-up की अनुमति नहीं दी है।';
    }
    if (e.contains('ADMIN_COIN_LIMIT_EXCEEDED')) {
      return 'Admin Coin Limit पूरी हो चुकी है। Owner से limit बढ़वाएं।';
    }
    if (e.contains('TARGET_USER_NOT_FOUND')) {
      return 'यह ZOONL ID नहीं मिली।';
    }
    if (e.contains('INVALID_COIN_AMOUNT')) {
      return 'Coins की संख्या सही नहीं है।';
    }
    if (e.contains('OWNER_ONLY')) {
      return 'यह काम केवल Owner कर सकता है।';
    }
    if (e.contains('INSUFFICIENT_COINS')) {
      return 'आपके पास पर्याप्त Coins नहीं हैं।';
    }
    return 'अनुरोध पूरा नहीं हुआ: $error';
  }

  Future<void> openTopupDialog() async {
    if (!canManageTopups) {
      message('आपको Top-up की अनुमति नहीं है।');
      return;
    }

    final remainingLimit =
        isOwner ? 999999999 : (adminCoinLimit - adminCoinsUsed);
    if (!isOwner && remainingLimit <= 0) {
      message('आपकी Admin Coin Limit खत्म हो गई है।');
      return;
    }

    final idController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: panel,
              title: Text(
                isOwner
                    ? 'ADD COINS (OWNER)'
                    : 'ADD COINS (LIMIT LEFT: $remainingLimit)',
                style: const TextStyle(color: gold, fontSize: 15),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target ZOONL ID',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Coins Amount',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final targetId = idController.text.trim();
                          final amount =
                              int.tryParse(amountController.text.trim());

                          if (!RegExp(r'^[0-9]+$').hasMatch(targetId)) {
                            message('सही ZOONL ID लिखें।');
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            message('सही Coins संख्या लिखें।');
                            return;
                          }
                          if (!isOwner && amount > remainingLimit) {
                            message(
                                'आप अधिकतम $remainingLimit Coins ही दे सकते हैं।');
                            return;
                          }

                          setDialogState(() => busy = true);
                          try {
                            final response = await db.rpc(
                              'add_zoonl_coins',
                              params: {
                                'p_zoonl_id': targetId,
                                'p_amount': amount,
                                'p_description':
                                    descriptionController.text.trim().isEmpty
                                        ? null
                                        : descriptionController.text.trim(),
                              },
                            );

                            final result =
                                Map<String, dynamic>.from(response as Map);
                            if (result['success'] != true) {
                              throw Exception('TOPUP_FAILED');
                            }

                            if (!isOwner) {
                              await db.from('owner_admin_permissions').update({
                                'coins_used': adminCoinsUsed + amount,
                              }).eq('admin_user_id', userId);
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            await loadData();
                            message(
                              '$targetId में $amount Coins जोड़ दिए गए।',
                            );
                          } catch (e) {
                            setDialogState(() => busy = false);
                            message(friendlyError(e));
                          }
                        },
                  child: busy
                      ? const CircularProgressIndicator()
                      : const Text('ADD COINS'),
                ),
              ],
            );
          },
        );
      },
    );

    idController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }

  Future<void> openAdminPermissionDialog() async {
    if (!isOwner) return;

    final idController = TextEditingController();
    final limitController = TextEditingController(text: '100000');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save(bool allowed) async {
              final adminId = idController.text.trim();
              final limitVal =
                  int.tryParse(limitController.text.trim()) ?? 0;

              if (!RegExp(r'^[0-9]+$').hasMatch(adminId)) {
                message('Admin का सही ZOONL ID लिखें।');
                return;
              }
              if (allowed && limitVal <= 0) {
                message('Admin Coin Limit 0 से ज़्यादा रखें।');
                return;
              }

              setDialogState(() => busy = true);
              try {
                await db.rpc(
                  'owner_set_admin_topup_permission',
                  params: {
                    'p_admin_zoonl_id': adminId,
                    'p_allowed': allowed,
                  },
                );

                await db.from('owner_admin_permissions').upsert({
                  'admin_zoonl_id': adminId,
                  'permission_key': 'manage_topups',
                  'is_allowed': allowed,
                  'coin_limit': allowed ? limitVal : 0,
                  'coins_used': 0,
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await loadPermissions();
                await loadAdminLimits();
                message(allowed
                    ? 'Admin को $limitVal Coins Limit के साथ अनुमति दी गई।'
                    : 'Admin की Top-up अनुमति हटा दी गई।');
              } catch (e) {
                setDialogState(() => busy = false);
                message(friendlyError(e));
              }
            }

            return AlertDialog(
              backgroundColor: panel,
              title: const Text('ADMIN ACCESS & COIN LIMIT',
                  style: TextStyle(color: gold, fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Admin ZOONL ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Coin Limit for Admin',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: busy ? null : () => save(false),
                  child: const Text('REVOKE',
                      style: TextStyle(color: pink)),
                ),
                FilledButton(
                  onPressed: busy ? null : () => save(true),
                  child: const Text('SAVE LIMIT'),
                ),
              ],
            );
          },
        );
      },
    );
    idController.dispose();
    limitController.dispose();
  }

  Future<void> openGrantEntryDialog() async {
    if (!isOwner && !canManageTopups) {
      message('Entry reward/grant केवल Owner या Authorized Admin कर सकता है।');
      return;
    }

    final targetIdController = TextEditingController();
    String selectedEntry = 'VIP Dragon Entry';
    String selectedFrame = 'Gold Sovereign Frame';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: panel,
              title: const Text('GRANT ENTRY & REWARD',
                  style: TextStyle(color: gold, fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: targetIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target User ZOONL ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedEntry,
                    dropdownColor: panel2,
                    decoration: const InputDecoration(
                      labelText: 'Entry Effect Reward',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'VIP Dragon Entry',
                        child: Text('VIP Dragon Entry'),
                      ),
                      DropdownMenuItem(
                        value: 'Phoenix Golden Entry',
                        child: Text('Phoenix Golden Entry'),
                      ),
                      DropdownMenuItem(
                        value: 'Streamer Star Entry',
                        child: Text('Streamer Star Entry'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedEntry = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFrame,
                    dropdownColor: panel2,
                    decoration: const InputDecoration(
                      labelText: 'Profile Frame',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Gold Sovereign Frame',
                        child: Text('Gold Sovereign Frame'),
                      ),
                      DropdownMenuItem(
                        value: 'Neon Star Frame',
                        child: Text('Neon Star Frame'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedFrame = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final targetId = targetIdController.text.trim();
                          if (!RegExp(r'^[0-9]+$').hasMatch(targetId)) {
                            message('सही Target ZOONL ID लिखें।');
                            return;
                          }
                          setDialogState(() => busy = true);
                          try {
                            await db.from('zoonl_user_cosmetics').upsert({
                              'user_id': targetId,
                              'item_code': selectedEntry,
                              'frame_code': selectedFrame,
                              'is_equipped': true,
                              'granted_by': isOwner ? 'OWNER' : 'ADMIN',
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            message(
                              '$targetId को $selectedEntry reward दे दिया गया।',
                            );
                          } catch (e) {
                            setDialogState(() => busy = false);
                            message('Entry grant नहीं हो सका: $e');
                          }
                        },
                  child: const Text('GRANT REWARD'),
                ),
              ],
            );
          },
        );
      },
    );

    targetIdController.dispose();
  }

  Future<void> applyForAgency() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    Map<String, dynamic> chosenPlan = agencyPaidPlans.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final fee = number(chosenPlan['fee_coins']);
            return AlertDialog(
              backgroundColor: panel,
              title: const Text('PAID AGENCY PORTAL',
                  style: TextStyle(color: gold, fontSize: 15)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Proposed Agency Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Contact Details',
                        hintText: 'Phone, email or WhatsApp',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField>(
                      value: chosenPlan,
                      dropdownColor: panel2,
                      decoration: const InputDecoration(
                        labelText: 'Agency Portal Plan (Paid)',
                      ),
                      items: agencyPaidPlans.map((plan) {
                        return DropdownMenuItem>(
                          value: plan,
                          child: Text(
                            '${plan['plan']} (${plan['fee_coins']} Coins)',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => chosenPlan = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Portal Fee: $fee Coins • Your Balance: $coins Coins',
                      style: TextStyle(
                        color: coins >= fee ? gold : pink,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            message('Agency का नाम लिखें।');
                            return;
                          }
                          if (coins < fee) {
                            message('Agency Portal के लिए पर्याप्त Coins नहीं हैं।');
                            return;
                          }
                          setDialogState(() => busy = true);
                          try {
                            await db.from('agency_applications').insert({
                              'applicant_id': userId,
                              'proposed_name': name,
                              'portal_plan': chosenPlan['plan'],
                              'portal_fee_coins': fee,
                              'contact_details': {
                                'contact': contactController.text.trim(),
                              },
                              'application_status': 'pending_paid',
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            message(
                                'Paid Agency Application ($fee Coins) भेज दी गई।');
                            await loadData();
                          } catch (e) {
                            setDialogState(() => busy = false);
                            message('Application भेजी नहीं जा सकी: $e');
                          }
                        },
                  child: busy
                      ? const CircularProgressIndicator()
                      : const Text('PAY & SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    contactController.dispose();
  }

  Future<void> sendGift(Map<String, dynamic> gift) async {
    if (sendingGift) return;

    final availableRooms = rooms
        .where((r) => r['owner_id']?.toString() != userId)
        .toList();

    if (availableRooms.isEmpty) {
      message('अभी कोई दूसरा Active Live Room नहीं मिला।');
      return;
    }

    final giftId = gift['id']?.toString();
    if (giftId == null || giftId.isEmpty) return;

    String? roomId = availableRooms.first['id'].toString();
    int quantity = 1;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: panel,
              title: const Text('SEND GIFT',
                  style: TextStyle(color: gold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  giftImage(gift, 75),
                  Text(value(gift['gift_name'], 'Gift')),
                  DropdownButtonFormField<String>(
                    value: roomId,
                    dropdownColor: panel2,
                    items: availableRooms.map((r) {
                      return DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text(value(r['room_name'], 'Live Room')),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setDialogState(() => roomId = v),
                  ),
                  DropdownButtonFormField<int>(
                    value: quantity,
                    dropdownColor: panel2,
                    items: [1, 5, 10, 20, 50].map((n) {
                      return DropdownMenuItem(
                        value: n,
                        child: Text('$n'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => quantity = v);
                      }
                    },
                  ),
                  Text(
                    'Total: ${number(gift['coin_price']) * quantity} Coins',
                    style: const TextStyle(color: gold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (roomId == null) return;
                    setState(() => sendingGift = true);
                    try {
                      final response = await db.rpc(
                        'send_live_gift',
                        params: {
                          'p_gift_id': giftId,
                          'p_room_id': roomId,
                          'p_quantity': quantity,
                        },
                      );
                      final result =
                          Map<String, dynamic>.from(response as Map);
                      if (result['success'] != true) {
                        throw Exception('GIFT_SEND_FAILED');
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      final sound = gift['sound_url']?.toString() ?? '';
                      if (sound.isNotEmpty) {
                        try {
                          await audioPlayer.stop();
                          await audioPlayer.setUrl(sound);
                          await audioPlayer.play();
                        } catch (_) {}
                      }
                      await loadData();
                      message('Gift सफलतापूर्वक भेज दिया गया।');
                    } catch (e) {
                      message(friendlyError(e));
                    } finally {
                      if (mounted) {
                        setState(() => sendingGift = false);
                      }
                    }
                  },
                  child: const Text('SEND'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showControl = isOwner || canManageTopups;

    final pages = <Widget>[
      homePage(),
      livePage(),
      walletPage(),
      giftsPage(),
      profilePage(),
      agencyPage(),
      ZoonlFeatureHub(
        isOwner: isOwner,
        isAdmin: !isOwner && canManageTopups,
      ),
      if (showControl) controlPage(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home, color: gold),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.live_tv_outlined),
        selectedIcon: Icon(Icons.live_tv, color: gold),
        label: 'Live',
      ),
      const NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet, color: gold),
        label: 'Wallet',
      ),
      const NavigationDestination(
        icon: Icon(Icons.card_giftcard_outlined),
        selectedIcon: Icon(Icons.card_giftcard, color: gold),
        label: 'Gifts',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person, color: gold),
        label: 'Profile',
      ),
      const NavigationDestination(
        icon: Icon(Icons.business_outlined),
        selectedIcon: Icon(Icons.business, color: gold),
        label: 'Agency',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view, color: gold),
        label: 'Features',
      ),
      if (showControl)
        NavigationDestination(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: const Icon(
            Icons.admin_panel_settings,
            color: gold,
          ),
          label: isOwner ? 'Owner' : 'Admin',
        ),
    ];

    final safeTab = tab >= pages.length ? 0 : tab;

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isOwner ? const Color(0xFF3A2510) : const Color(0xFF21143A),
              bg,
            ],
          ),
        ),
        child: SafeArea(child: pages[safeTab]),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF110D1C),
        indicatorColor: levelAccentColor.withOpacity(0.25),
        selectedIndex: safeTab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: destinations,
      ),
    );
  }

  Widget idBadgeWithNumberWidget() {
    final displayId = zoonlId.isEmpty ? 'Not available' : zoonlId;
    final specialOwner = isOwner || zoonlId == '10001';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: specialOwner
            ? const LinearGradient(
                colors: [Color(0xFF7A5216), Color(0xFF2B1B08)],
              )
            : LinearGradient(
                colors: [
                  levelAccentColor.withOpacity(0.28),
                  levelSurfaceColor,
                ],
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: specialOwner ? gold : levelAccentColor,
          width: specialOwner ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            specialOwner ? Icons.workspace_premium : Icons.verified,
            color: specialOwner ? gold : levelAccentColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: levelAccentColor.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              levelBadgeLabel,
              style: TextStyle(
                color: specialOwner ? gold : levelAccentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ID: $displayId',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: specialOwner ? 15 : 13,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget chatStripWidget({required String senderName, required String chatText}) {
    final specialOwner = isOwner || zoonlId == '10001';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: specialOwner
              ? [const Color(0xFF6B4814), const Color(0xFF241709)]
              : [
                  levelAccentColor.withOpacity(0.24),
                  levelSurfaceColor,
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelAccentColor.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(
            specialOwner ? Icons.workspace_premium : Icons.shield,
            size: 16,
            color: levelAccentColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$senderName: ',
            style: TextStyle(
              color: levelAccentColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              chatText,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget header(String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [levelAccentColor, purple2],
            ),
          ),
          child: const Icon(Icons.bolt, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 1,
                    )),
            ],
          ),
        ),
        IconButton(
          onPressed: loadData,
          icon: const Icon(Icons.refresh, color: gold),
        ),
      ],
    );
  }

  Widget heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }

  Widget empty(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: gold, size: 34),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget metric(String title, String amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 23),
          const SizedBox(height: 7),
          Text(amount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              )),
          Text(title,
              style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget feature(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: levelAccentColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: gold, size: 24),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                )),
            Text(subtitle,
                style: const TextStyle(color: muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget homePage() {
    final name = value(
      profile['display_name'],
      value(profile['username'], 'ZOONL Member'),
    );
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('ZOONL LIVE',
              subtitle: 'WELCOME TO YOUR LIVE WORLD'),
          const SizedBox(height: 20),
          Text('Welcome, $name',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              )),
          idBadgeWithNumberWidget(),
          if (isOwner || zoonlId == '10001') ownerIdentityCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: metric('Coins', '$coins', Icons.monetization_on)),
              const SizedBox(width: 10),
              Expanded(child: metric('Diamonds', '$diamonds', Icons.diamond)),
              const SizedBox(width: 10),
              Expanded(child: metric('Live Rooms', '${rooms.length}', Icons.live_tv)),
            ],
          ),
          const SizedBox(height: 23),
          heading('Explore ZOONL', 'Your live social world'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: feature(Icons.live_tv, 'LIVE ROOMS',
                  'Watch creators', () => setState(() => tab = 1))),
              const SizedBox(width: 10),
              Expanded(child: feature(Icons.card_giftcard, 'GIFT CENTER',
                  'Send virtual gifts', () => setState(() => tab = 3))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: feature(Icons.account_balance_wallet,
                  'MY WALLET', 'Coins and Diamonds',
                  () => setState(() => tab = 2))),
              const SizedBox(width: 10),
              Expanded(child: feature(Icons.grid_view, 'FEATURE HUB',
                  'Entry, VIP & Admin',
                  () => setState(() => tab = 6))),
            ],
          ),
          const SizedBox(height: 22),
          heading('Live Now', 'Rooms currently broadcasting'),
          const SizedBox(height: 10),
          if (rooms.isEmpty)
            empty('No Active Live Rooms', 'Live Rooms यहाँ दिखाई देंगे।')
          else
            ...rooms.take(3).map(roomCard),
        ],
      ),
    );
  }

  Widget ownerIdentityCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7A5216), Color(0xFF2B180A), Color(0xFF171126)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold),
                ),
                child: const Icon(Icons.workspace_premium,
                    color: gold, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OFFICIAL ZOONL OWNER VIP',
                        style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        )),
                    Text('ZOONL ID 10001 • PRE-SET VIP FRAME',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Special Entry: $activeEntryEffect',
            style: const TextStyle(color: gold, fontSize: 12),
          ),
          Text(
            'Active Frame: $activeVipFrame',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget livePage() {
    final name = value(
      profile['display_name'],
      value(profile['username'], 'ZOONL Member'),
    );
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('LIVE ROOMS', subtitle: 'DISCOVER LIVE CREATORS'),
          const SizedBox(height: 14),
          chatStripWidget(
            senderName: name,
            chatText: 'Entered Live • $activeEntryEffect',
          ),
          const SizedBox(height: 10),
          heading('LIVE NOW', '${rooms.length} active rooms'),
          const SizedBox(height: 12),
          if (rooms.isEmpty)
            empty('No Live Rooms Found',
                'जब कोई Host Live होगा, Room यहाँ आएगा।')
          else
            ...rooms.map(roomCard),
        ],
      ),
    );
  }

  Widget roomCard(Map<String, dynamic> room) {
    final mine = room['owner_id']?.toString() == userId;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: levelAccentColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.live_tv, color: gold, size: 35),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value(room['room_name'], 'ZOONL Live Room'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${value(room['room_type'], 'Live')} • '
                  '${number(room['viewer_count'])} viewers',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!mine)
            FilledButton(
              onPressed: gifts.isEmpty ? null : () => sendGift(gifts.first),
              style: FilledButton.styleFrom(backgroundColor: purple),
              child: const Text('Gift'),
            )
          else
            const Text('YOUR ROOM',
                style: TextStyle(color: gold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget walletPage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('MY WALLET', subtitle: 'COINS AND DIAMONDS'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF6840A7), Color(0xFF211735)],
              ),
              border: Border.all(color: gold.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                    )),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: gold, size: 29),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('$coins',
                            style: const TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                            ))),
                    const Text('COINS', style: TextStyle(color: gold)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 30),
                Row(
                  children: [
                    const Icon(Icons.diamond, color: pink, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('$diamonds',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ))),
                    const Text('DIAMONDS', style: TextStyle(color: pink)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          heading('DIRECT TOP-UP', 'Buy Coins directly from ZOONL LIVE'),
          const SizedBox(height: 5),
          const Text('USD 1 = 3,000 Coins • No bonus',
              style: TextStyle(color: gold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: coinPackages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final p = coinPackages[index];
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: purple.withOpacity(0.45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('\$${p['usd']}',
                        style: const TextStyle(
                          color: gold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        )),
                    Text('${p['coins']} Coins',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Direct package',
                        style: TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
          if (canManageTopups) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: openTopupDialog,
              icon: const Icon(Icons.add),
              label: Text(
                isOwner
                    ? 'ADD COINS TO USER'
                    : 'ADD COINS (LIMIT LEFT: ${adminCoinLimit - adminCoinsUsed})',
              ),
              style: FilledButton.styleFrom(backgroundColor: purple),
            ),
          ],
          const SizedBox(height: 22),
          heading('Wallet History', 'Your latest transactions'),
          const SizedBox(height: 10),
          if (transactions.isEmpty)
            empty('No Transactions',
                'आपकी Wallet History यहाँ दिखाई देगी।')
          else
            ...transactions.map(transactionCard),
        ],
      ),
    );
  }

  Widget transactionCard(Map<String, dynamic> row) {
    final amount = number(row['amount']);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            amount < 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: amount < 0 ? pink : const Color(0xFF6DDBA5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value(row['transaction_type'], 'Transaction'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(value(row['description'], 'Wallet transaction'),
                    style: const TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
          Text('${row['amount']} ${value(row['currency'], '')}',
              style: TextStyle(
                color: amount < 0 ? pink : const Color(0xFF6DDBA5),
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget giftsPage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('GIFT CENTER', subtitle: 'SEND GIFTS TO LIVE CREATORS'),
          const SizedBox(height: 20),
          heading('Gift Collection', '${gifts.length} available gifts'),
          const SizedBox(height: 12),
          if (gifts.isEmpty)
            empty('No Gifts Available', 'Active Gifts यहाँ दिखाई देंगे।')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) => giftCard(gifts[index]),
            ),
        ],
      ),
    );
  }

  Widget giftCard(Map<String, dynamic> gift) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: giftImage(gift, 95))),
          Text(value(gift['gift_name'], 'Gift'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('${number(gift['coin_price'])} Coins',
              style: const TextStyle(color: gold)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: sendingGift ? null : () => sendGift(gift),
              style: FilledButton.styleFrom(backgroundColor: purple),
              child: const Text('SEND'),
            ),
          ),
        ],
      ),
    );
  }

  Widget giftImage(Map<String, dynamic> gift, double size) {
    final animation = gift['animation_url']?.toString() ?? '';
    final image = gift['image_url']?.toString() ?? '';
    final url = animation.isNotEmpty ? animation : image;
    if (url.isEmpty) {
      return Icon(Icons.card_giftcard,
          size: size * 0.65, color: gold);
    }
    return Image.network(
      url,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.card_giftcard,
        size: size * 0.65,
        color: gold,
      ),
    );
  }

  Widget profilePage() {
    final name = value(
      profile['display_name'],
      value(profile['username'], 'ZOONL Member'),
    );
    final specialOwner = isOwner || zoonlId == '10001';

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header('MY PROFILE', subtitle: 'PREMIUM ZOONL IDENTITY'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: specialOwner
                  ? [const Color(0xFF7A5216), const Color(0xFF231508)]
                  : [levelSurfaceColor, panel],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: specialOwner ? gold : levelAccentColor,
              width: specialOwner ? 2.0 : 1.4,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: specialOwner ? gold : levelAccentColor,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: purple2,
                  child: Icon(
                    specialOwner ? Icons.workspace_premium : Icons.person,
                    size: 43,
                    color: gold,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  )),
              idBadgeWithNumberWidget(),
              const SizedBox(height: 10),
              Text('Frame: $activeVipFrame',
                  style: TextStyle(color: levelAccentColor, fontSize: 12)),
              const SizedBox(height: 6),
              Text(db.auth.currentUser?.email ?? '',
                  style: const TextStyle(color: muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        profileInfo('ID Badge & Level', levelBadgeLabel),
        profileInfo('Entry Effect', activeEntryEffect),
        profileInfo('Country', value(profile['country'])),
        profileInfo('Verified',
            profile['is_verified'] == true ? 'Yes' : 'No'),
        profileInfo('PRIME Memberships', '${memberships.length}'),
        const SizedBox(height: 10),
        ListTile(
          tileColor: panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: const Icon(Icons.grid_view, color: gold),
          title: const Text('Open Feature Hub (Entry, VIP, Hosts)'),
          onTap: () => setState(() => tab = 6),
        ),
        if (isOwner || canManageTopups) ...[
          const SizedBox(height: 8),
          ListTile(
            tileColor: panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.admin_panel_settings, color: gold),
            title: Text(
                isOwner ? 'Owner VIP Dashboard' : 'Admin Control Dashboard'),
            onTap: () => setState(() => tab = 7),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => db.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('SIGN OUT'),
          style: OutlinedButton.styleFrom(
            foregroundColor: pink,
            side: const BorderSide(color: pink),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget profileInfo(String title, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: levelAccentColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title,
              style: const TextStyle(color: muted))),
          Text(text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: levelAccentColor,
              )),
        ],
      ),
    );
  }

  Widget agencyPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header('AGENCY PORTAL', subtitle: 'PAID ZOONL AGENCY NETWORK'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.business, color: gold, size: 34),
              SizedBox(height: 10),
              Text('PAID AGENCY PORTAL ACCESS',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                  )),
              SizedBox(height: 7),
              Text(
                'Agency Portal free नहीं है। Plan चुनकर Coins payment के साथ '
                'application submit करें।',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: applyForAgency,
          icon: const Icon(Icons.payments),
          label: const Text('PAY COINS & APPLY FOR AGENCY'),
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            padding: const EdgeInsets.all(15),
          ),
        ),
        const SizedBox(height: 20),
        heading('My Application', 'Your submitted agency requests'),
        const SizedBox(height: 10),
        FutureBuilder<List>>(
          future: db
              .from('agency_applications')
              .select()
              .eq('applicant_id', userId)
              .order('created_at', ascending: false)
              .then((r) => List>.from(r as List)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return empty('No Application',
                  'आपकी Agency Application यहाँ दिखाई देगी।');
            }
            return Column(
              children: rows.map((row) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(value(row['proposed_name'], 'Agency')),
                    subtitle: Text(
                      'Plan: ${value(row['portal_plan'], 'Standard')} • '
                      'Status: ${value(row['application_status'])}',
                      style: const TextStyle(color: gold),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget controlPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header(
          isOwner ? 'OWNER VIP DASHBOARD' : 'ADMIN DASHBOARD',
          subtitle: 'ZOONL MANAGEMENT CONTROL',
        ),
        const SizedBox(height: 18),
        if (isOwner || zoonlId == '10001') ownerIdentityCard(),
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isOwner ? Icons.workspace_premium : Icons.admin_panel_settings,
                color: gold,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                isOwner
                    ? 'OFFICIAL OWNER VIP ACCESS'
                    : 'AUTHORIZED ADMIN ACCESS',
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isOwner
                    ? 'Owner ID 10001 • Admin Coin Limits, Entry Rewards & Paid Agency Control.'
                    : 'Coin Limit Left: ${adminCoinLimit - adminCoinsUsed} Coins',
                style: const TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: openTopupDialog,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('ADD COINS TO USER'),
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: openGrantEntryDialog,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('GRANT ENTRY EFFECT / REWARD'),
          style: OutlinedButton.styleFrom(
            foregroundColor: gold,
            side: const BorderSide(color: gold),
            padding: const EdgeInsets.all(16),
          ),
        ),
        if (isOwner) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: openAdminPermissionDialog,
            icon: const Icon(Icons.manage_accounts),
            label: const Text('SET ADMIN COIN LIMIT & ACCESS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              side: const BorderSide(color: gold),
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),
          heading('ADMIN COIN LIMITS', '${adminLimits.length} configured'),
          const SizedBox(height: 10),
          if (adminLimits.isEmpty)
            empty('No Admin Limits Set',
                'Owner यहाँ Admin की Coin Limit set कर सकता है।')
          else
            ...adminLimits.map((row) {
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admin ID: ${value(row['admin_zoonl_id'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Limit: ${number(row['coin_limit'])}',
                      style: const TextStyle(color: gold),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          heading('AGENCY APPLICATIONS',
              '${agencyApplications.length} requests'),
          const SizedBox(height: 10),
          if (agencyApplications.isEmpty)
            empty('No Agency Applications',
                'नई applications यहाँ दिखाई देंगी।')
          else
            ...agencyApplications.map((row) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value(row['proposed_name'], 'Agency'),
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 5),
                    Text(
                      'Plan: ${value(row['portal_plan'])} • '
                      'Fee: ${number(row['portal_fee_coins'])} Coins',
                      style: const TextStyle(color: gold, fontSize: 12),
                    ),
                    Text('Applicant: ${value(row['applicant_id'])}',
                        style: const TextStyle(color: muted)),
                    Text('Status: ${value(row['application_status'])}',
                        style: const TextStyle(color: muted)),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}
