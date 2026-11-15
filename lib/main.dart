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
