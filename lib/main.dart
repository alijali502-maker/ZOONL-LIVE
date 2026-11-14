
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'core/app_config.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
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

  Map<String, dynamic> profile = {};
  Map<String, dynamic> publicProfile = {};
  Map<String, dynamic> wallet = {};

  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> gifts = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> memberships = [];
  List<Map<String, dynamic>> agencyApplications = [];

  String? loadError;

  String get userId => db.auth.currentUser?.id ?? '';
  String get zoonlId => publicProfile['zoonl_id']?.toString() ?? '';

  int get coins => number(wallet['coins']);
  int get diamonds => number(wallet['diamonds']);

  static const List<Map<String, dynamic>> coinPackages = [
    {'usd': 10, 'coins': 30000},
    {'usd': 20, 'coins': 60000},
    {'usd': 30, 'coins': 90000},
    {'usd': 40, 'coins': 120000},
    {'usd': 50, 'coins': 150000},
    {'usd': 60, 'coins': 180000},
  ];

  int number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String value(dynamic input, [String fallback = 'Not available']) {
    if (input == null || input.toString().trim().isEmpty) {
      return fallback;
    }
    return input.toString();
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

    setState(() {
      loading = true;
      loadError = null;
    });

    await Future.wait([
      loadProfile(),
      loadPublicProfile(),
      loadWallet(),
      loadRooms(),
      loadGifts(),
      loadTransactions(),
      loadMemberships(),
      loadPermissions(),
      loadAgencyApplications(),
    ]);

    if (mounted) setState(() => loading = false);
  }

  Future<void> loadPermissions() async {
    isOwner = false;
    canManageTopups = false;

    try {
      final result = await db.rpc('is_zoonl_owner');
      isOwner = result == true;

      if (isOwner) {
        canManageTopups = true;
        return;
      }

      final rows = await db
          .from('owner_admin_permissions')
          .select('id')
          .eq('admin_user_id', userId)
          .eq('permission_key', 'manage_topups')
          .eq('is_allowed', true)
          .limit(1);

      canManageTopups = (rows as List).isNotEmpty;
    } catch (_) {
      isOwner = false;
      canManageTopups = false;
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
      rooms = List<Map<String, dynamic>>.from(result);
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
      gifts = List<Map<String, dynamic>>.from(result);
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
      transactions = List<Map<String, dynamic>>.from(result);
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
      memberships = List<Map<String, dynamic>>.from(result);
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
      agencyApplications =
          List<Map<String, dynamic>>.from(result);
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
              title: const Text('ADD COINS',
                  style: TextStyle(color: gold)),
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
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(dialogContext),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save(bool allowed) async {
              final adminId = idController.text.trim();
              if (!RegExp(r'^[0-9]+$').hasMatch(adminId)) {
                message('Admin का सही ZOONL ID लिखें।');
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
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await loadPermissions();
                message(allowed
                    ? 'Admin को Top-up अनुमति दी गई।'
                    : 'Admin की Top-up अनुमति हटा दी गई।');
              } catch (e) {
                setDialogState(() => busy = false);
                message(friendlyError(e));
              }
            }

            return AlertDialog(
              backgroundColor: panel,
              title: const Text('ADMIN TOP-UP ACCESS',
                  style: TextStyle(color: gold)),
              content: TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Admin ZOONL ID',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: busy ? null : () => save(false),
                  child: const Text('REVOKE',
                      style: TextStyle(color: pink)),
                ),
                FilledButton(
                  onPressed: busy ? null : () => save(true),
                  child: const Text('GRANT'),
                ),
              ],
            );
          },
        );
      },
    );
    idController.dispose();
  }

  Future<void> applyForAgency() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: panel,
              title: const Text('AGENCY APPLICATION',
                  style: TextStyle(color: gold)),
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
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Contact Details',
                        hintText: 'Phone, email or other contact',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(dialogContext),
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
                          setDialogState(() => busy = true);
                          try {
                            await db.from('agency_applications').insert({
                              'applicant_id': userId,
                              'proposed_name': name,
                              'contact_details': {
                                'contact': contactController.text.trim(),
                              },
                              'application_status': 'pending',
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            message('Agency Application भेज दी गई।');
                            await loadData();
                          } catch (e) {
                            setDialogState(() => busy = false);
                            message('Application भेजी नहीं जा सकी: $e');
                          }
                        },
                  child: busy
                      ? const CircularProgressIndicator()
                      : const Text('SUBMIT APPLICATION'),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF21143A), bg],
          ),
        ),
        child: SafeArea(child: pages[safeTab]),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF110D1C),
        indicatorColor: purple.withOpacity(0.25),
        selectedIndex: safeTab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: destinations,
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
            gradient: const LinearGradient(
              colors: [purple, purple2],
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
          border: Border.all(color: purple.withOpacity(0.35)),
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
          const SizedBox(height: 23),
          Text('Welcome, $name',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 5),
          Text(
            'ZOONL ID: ${zoonlId.isEmpty ? 'Not available' : zoonlId}',
            style: const TextStyle(color: gold),
          ),
          if (isOwner) ownerIdentityCard(),
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
                  'Send virtual gifts', () => setState(() => tab = 3)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: feature(Icons.account_balance_wallet,
                  'MY WALLET', 'Coins and Diamonds',
                  () => setState(() => tab = 2))),
              const SizedBox(width: 10),
              Expanded(child: feature(Icons.business, 'AGENCY',
                  'Agency application', () => setState(() => tab = 5))),
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
          colors: [Color(0xFF684A20), Color(0xFF211735)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, color: gold, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OFFICIAL ZOONL OWNER',
                    style: TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w900,
                    )),
                Text('ZOONL ID 10001',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget livePage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('LIVE ROOMS', subtitle: 'DISCOVER LIVE CREATORS'),
          const SizedBox(height: 20),
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
        border: Border.all(color: purple.withOpacity(0.25)),
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
                    Expanded(child: Text('$coins',
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
                    Expanded(child: Text('$diamonds',
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
          const SizedBox(height: 12),
          const Text(
            'Payment checkout अभी connect नहीं है। Package selection से '
            'अपने आप Coins add नहीं होंगे।',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          if (canManageTopups) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: openTopupDialog,
              icon: const Icon(Icons.add),
              label: const Text('MANUAL ADD COINS TO USER'),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header('MY PROFILE', subtitle: 'YOUR ZOONL IDENTITY'),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isOwner ? gold : purple),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: purple2,
                child: Icon(
                  isOwner ? Icons.verified_user : Icons.person,
                  size: 43,
                  color: gold,
                ),
              ),
              const SizedBox(height: 13),
              Text(name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 7),
              Text('ZOONL ID: ${zoonlId.isEmpty ? 'Not available' : zoonlId}',
                  style: const TextStyle(color: gold, letterSpacing: 1)),
              if (isOwner) ...[
                const SizedBox(height: 8),
                const Text('OFFICIAL OWNER • ID 10001',
                    style: TextStyle(color: gold)),
              ],
              const SizedBox(height: 10),
              Text(db.auth.currentUser?.email ?? '',
                  style: const TextStyle(color: muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        profileInfo('User Level', value(profile['user_level'], '1')),
        profileInfo('Country', value(profile['country'])),
        profileInfo('Verified',
            profile['is_verified'] == true ? 'Yes' : 'No'),
        profileInfo('PRIME Memberships', '${memberships.length}'),
        if (isOwner || canManageTopups)
          ListTile(
            tileColor: panel,
            leading: const Icon(Icons.admin_panel_settings, color: gold),
            title: Text(isOwner ? 'Owner Dashboard' : 'Admin Dashboard'),
            onTap: () => setState(() => tab = 6),
          ),
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
      ),
      child: Row(
        children: [
          Expanded(child: Text(title,
              style: const TextStyle(color: muted))),
          Text(text,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget agencyPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header('AGENCY CENTER', subtitle: 'ZOONL AGENCY NETWORK'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: purple.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.business, color: gold, size: 34),
              SizedBox(height: 10),
              Text('BECOME A ZOONL AGENCY',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                  )),
              SizedBox(height: 7),
              Text(
                'Agency application भेजें। Owner द्वारा review के बाद '
                'approval status यहाँ manage किया जाएगा।',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: applyForAgency,
          icon: const Icon(Icons.send),
          label: const Text('APPLY FOR AGENCY'),
          style: FilledButton.styleFrom(
            backgroundColor: purple,
            padding: const EdgeInsets.all(15),
          ),
        ),
        const SizedBox(height: 20),
        heading('My Application', 'Your submitted agency requests'),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: db
              .from('agency_applications')
              .select()
              .eq('applicant_id', userId)
              .order('created_at', ascending: false)
              .then((r) => List<Map<String, dynamic>>.from(r)),
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
          isOwner ? 'OWNER DASHBOARD' : 'ADMIN DASHBOARD',
          subtitle: 'ZOONL MANAGEMENT CONTROL',
        ),
        const SizedBox(height: 18),
        if (isOwner) ownerIdentityCard(),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isOwner ? Icons.verified_user : Icons.admin_panel_settings,
                color: gold,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                isOwner ? 'OFFICIAL OWNER ACCESS' : 'AUTHORIZED ADMIN ACCESS',
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isOwner
                    ? 'Owner identity: ZOONL ID 10001. Owner controls the existing Top-up permission.'
                    : 'आपका Top-up access Owner की अनुमति पर निर्भर है।',
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
        if (isOwner) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: openAdminPermissionDialog,
            icon: const Icon(Icons.manage_accounts),
            label: const Text('GRANT / REVOKE ADMIN TOP-UP'),
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              side: const BorderSide(color: gold),
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
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
                    Text('Applicant: ${value(row['applicant_id'])}',
                        style: const TextStyle(color: muted)),
                    Text('Status: ${value(row['application_status'])}',
                        style: const TextStyle(color: muted)),
                    Text(
                      'Application ID: ${value(row['id'])}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}
