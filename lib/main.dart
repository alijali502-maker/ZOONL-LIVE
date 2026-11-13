
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

const bg = Color(0xFF080611);
const panel = Color(0xFF171126);
const panel2 = Color(0xFF211735);
const purple = Color(0xFF9360F5);
const purple2 = Color(0xFF542CA0);
const gold = Color(0xFFE6C47A);
const muted = Color(0xFFAAA1BC);
const pink = Color(0xFFDA65C8);
const cyan = Color(0xFF55C9E8);

class AppSection {
  final String title;
  final String subtitle;
  final String table;
  final IconData icon;

  const AppSection(this.title, this.subtitle, this.table, this.icon);
}

const sections = <AppSection>[
  AppSection('Profiles', 'User accounts and profiles', 'profiles', Icons.people),
  AppSection('Public Profiles', 'ZOONL public identity', 'user_public_profiles', Icons.badge),
  AppSection('Live Rooms', 'Active live rooms', 'live_rooms', Icons.live_tv),
  AppSection('Room Members', 'Live room participants', 'live_room_members', Icons.groups),
  AppSection('Gift Catalog', 'Available gifts', 'gifts', Icons.card_giftcard),
  AppSection('Gift Categories', 'Gift categories', 'gift_categories', Icons.category),
  AppSection('Gift Assets', 'Gift animations and media', 'gift_assets', Icons.animation),
  AppSection('Gift Favorites', 'Saved favorite gifts', 'gift_favorites', Icons.favorite),
  AppSection('Gift Sends', 'Gift sending records', 'gift_sends', Icons.redeem),
  AppSection('Gift History', 'Gift transaction history', 'gift_send_history', Icons.history),
  AppSection('Wallet', 'Original wallet balance', 'wallets', Icons.account_balance_wallet),
  AppSection('Wallet Transactions', 'Coin transaction records', 'wallet_transactions', Icons.receipt_long),
  AppSection('Levels', 'Level definitions', 'level_definitions', Icons.stars),
  AppSection('PRIME Tiers', 'PRIME membership plans', 'prime_tiers', Icons.workspace_premium),
  AppSection('PRIME Memberships', 'User PRIME membership', 'user_prime_memberships', Icons.diamond),
  AppSection('Rewards', 'Available rewards', 'reward_catalog', Icons.emoji_events),
  AppSection('Reward Claims', 'Claim history', 'reward_claims', Icons.card_giftcard),
  AppSection('Admin Permissions', 'Authorized admin controls', 'admin_permissions', Icons.admin_panel_settings),
  AppSection('Agencies', 'Agency records', 'agencies', Icons.business),
  AppSection('Agency Applications', 'Agency approval records', 'agency_applications', Icons.assignment),
  AppSection('Host Applications', 'Host applications', 'host_applications', Icons.person_add_alt_1),
];

class ZoonlApp extends StatelessWidget {
  const ZoonlApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (Supabase.instance.client.auth.currentSession == null) {
            return const LoginScreen();
          }
          return const MainScreen();
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

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int tab = 0;
  int slide = 0;
  int backgroundChoice = 0;
  bool loading = true;
  Timer? timer;

  String? connectionError;
  String? selectedTable;

  final Map<String, List<Map<String, dynamic>>> data = {};
  final Map<String, String> errors = {};

  final banners = const [
    ('WELCOME TO ZOONL LIVE', 'Your world. Your stage.', Icons.public),
    ('GO LIVE. BE SEEN.', 'Connect with the world.', Icons.live_tv),
    ('SEND LOVE', 'Discover gifts and animations.', Icons.card_giftcard),
    ('LEVEL UP', 'Every moment brings a milestone.', Icons.stars),
    ('ENTER PRIME', 'Explore premium experiences.', Icons.diamond),
  ];

  final backgrounds = const [
    [Color(0xFF29164B), Color(0xFF090713)],
    [Color(0xFF182A4B), Color(0xFF090713)],
    [Color(0xFF481D43), Color(0xFF090713)],
    [Color(0xFF263B39), Color(0xFF090713)],
  ];

  @override
  void initState() {
    super.initState();
    loadData();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => slide = (slide + 1) % banners.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      connectionError = null;
      data.clear();
      errors.clear();
    });

    try {
      await Future.wait(sections.map((section) async {
        try {
          final result = await Supabase.instance.client
              .from(section.table)
              .select()
              .limit(50)
              .timeout(const Duration(seconds: 12));
          data[section.table] =
              List<Map<String, dynamic>>.from(result);
        } catch (e) {
          errors[section.table] = e.toString();
        }
      })).timeout(const Duration(seconds: 25));
    } catch (e) {
      connectionError = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  int count(String table) => data[table]?.length ?? 0;

  int number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  dynamic firstValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row[key] != null) return row[key];
    }
    return null;
  }

  String display(dynamic value) {
    if (value == null) return 'Not available';
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }

  int get total => data.values.fold(0, (sum, rows) => sum + rows.length);

  List<Map<String, dynamic>> get walletRows => data['wallets'] ?? [];

  Map<String, dynamic> get currentWallet {
    final user = Supabase.instance.client.auth.currentUser;
    final rows = walletRows;
    if (user != null) {
      for (final row in rows) {
        if (row['user_id']?.toString() == user.id) return row;
      }
    }
    return rows.isNotEmpty ? rows.first : {};
  }

  dynamic get coinBalance => firstValue(currentWallet, [
    'coins',
    'coin_balance',
    'available_coins',
    'balance',
    'total_coins',
  ]);

  Map<String, dynamic> get myProfile {
    final user = Supabase.instance.client.auth.currentUser;
    final rows = data['profiles'] ?? [];
    if (user != null) {
      for (final row in rows) {
        if (row['id']?.toString() == user.id ||
            row['user_id']?.toString() == user.id) {
          return row;
        }
      }
    }
    return rows.isNotEmpty ? rows.first : {};
  }

  void openSection(String table) {
    setState(() {
      selectedTable = table;
      tab = 4;
    });
  }

  void openTab(int value) {
    setState(() {
      selectedTable = null;
      tab = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      homePage(),
      livePage(),
      walletPage(),
      giftsPage(),
      selectedTable != null ? tablePage(selectedTable!) : profilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backgrounds[backgroundChoice],
          ),
        ),
        child: SafeArea(child: pages[tab]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF110D1C).withOpacity(0.97),
          border: const Border(top: BorderSide(color: Colors.white12)),
        ),
        child: NavigationBar(
          height: 66,
          backgroundColor: Colors.transparent,
          indicatorColor: purple.withOpacity(0.25),
          selectedIndex: tab,
          onDestinationSelected: openTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: gold),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.live_tv_outlined),
              selectedIcon: Icon(Icons.live_tv, color: gold),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: gold),
              label: 'Wallet',
            ),
            NavigationDestination(
              icon: Icon(Icons.card_giftcard_outlined),
              selectedIcon: Icon(Icons.card_giftcard, color: gold),
              label: 'Gifts',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: gold),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget topBar() {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [purple, purple2]),
            boxShadow: [
              BoxShadow(
                color: purple.withOpacity(0.35),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(Icons.bolt, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZOONL LIVE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'LIVE SOCIAL WORLD',
                style: TextStyle(
                  color: gold,
                  fontSize: 8,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: loading ? null : loadData,
          icon: const Icon(Icons.refresh, color: gold),
        ),
        IconButton(
          onPressed: () => openSection('wallet_transactions'),
          icon: const Icon(Icons.notifications_none, color: Colors.white70),
        ),
      ],
    );
  }

  Widget homePage() {
    final banner = banners[slide];

    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
        children: [
          topBar(),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 650),
            transitionBuilder: (child, animation) =>
                FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child: Container(
              key: ValueKey(slide),
              height: 205,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7445B8),
                    Color(0xFF351C59),
                    Color(0xFF171126),
                  ],
                ),
                border: Border.all(color: gold.withOpacity(0.65)),
                boxShadow: [
                  BoxShadow(
                    color: purple.withOpacity(0.25),
                    blurRadius: 25,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -20,
                    child: Icon(
                      banner.$3,
                      size: 145,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ZOONL EXCLUSIVE',
                        style: TextStyle(
                          color: gold,
                          letterSpacing: 2,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        banner.$1,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        banner.$2,
                        style: const TextStyle(
                          color: Color(0xFFE0D7F0),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(banners.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 5),
                            height: 4,
                            width: i == slide ? 24 : 7,
                            decoration: BoxDecoration(
                              color: i == slide ? gold : Colors.white38,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your LIVE world',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                loading ? 'Syncing...' : '$total records',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: metric('Members', count('profiles'), Icons.people)),
              const SizedBox(width: 8),
              Expanded(child: metric('Live Rooms', count('live_rooms'), Icons.live_tv)),
              const SizedBox(width: 8),
              Expanded(child: metric('Gifts', count('gifts'), Icons.card_giftcard)),
            ],
          ),
          const SizedBox(height: 22),
          sectionHeading('Explore ZOONL', 'Discover your world'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: bigFeature(
                  Icons.live_tv,
                  'LIVE ROOMS',
                  'Watch creators',
                  const Color(0xFF6339A5),
                  () => openTab(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: bigFeature(
                  Icons.card_giftcard,
                  'GIFT CENTER',
                  'Explore gifts',
                  const Color(0xFF8B3C83),
                  () => openTab(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: bigFeature(
                  Icons.workspace_premium,
                  'PRIME',
                  'Premium tiers',
                  const Color(0xFF795D30),
                  () => openSection('prime_tiers'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: bigFeature(
                  Icons.emoji_events,
                  'REWARDS',
                  'Your rewards',
                  const Color(0xFF315E73),
                  () => openSection('reward_catalog'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          sectionHeading('Your Membership', 'Levels and premium access'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: smallFeature(
                  Icons.stars,
                  'LEVELS',
                  '${count('level_definitions')} levels',
                  () => openSection('level_definitions'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: smallFeature(
                  Icons.diamond,
                  'PRIME',
                  '${count('prime_tiers')} tiers',
                  () => openSection('prime_tiers'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: smallFeature(
                  Icons.workspace_premium,
                  'VIP',
                  'Membership',
                  () => openSection('user_prime_memberships'),
                ),
              ),
            ],
          ),
          if (connectionError != null)
            errorBox('Connection problem', connectionError!),
          if (!loading && errors.isNotEmpty)
            errorBox(
              'Some data is unavailable',
              '${errors.length} data sources could not be loaded. Open the relevant section for details.',
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openSection('profiles'),
            icon: const Icon(Icons.storage),
            label: const Text('Explore connected data'),
          ),
        ],
      ),
    );
  }

  Widget livePage() {
    final rooms = data['live_rooms'] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
      children: [
        topBar(),
        const SizedBox(height: 22),
        sectionHeading('LIVE NOW', 'Discover live rooms'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B2D83), Color(0xFF21152E)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pink.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering, color: pink, size: 35),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE COMMUNITY',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${rooms.length} rooms connected',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.graphic_eq, color: gold, size: 28),
            ],
          ),
        ),
        const SizedBox(height: 18),
        sectionHeading('Available Rooms', 'Connected room data'),
        if (loading)
          const Center(child: CircularProgressIndicator(color: gold))
        else if (rooms.isEmpty)
          emptyState('No live rooms returned', 'Live room data will appear here when available.')
        else
          for (final room in rooms) dataItemCard(room, Icons.live_tv),
        const SizedBox(height: 15),
        actionCard(
          'Live Room Members',
          'View room participants',
          Icons.groups,
          () => openSection('live_room_members'),
        ),
      ],
    );
  }

  Widget walletPage() {
    final transactions = data['wallet_transactions'] ?? [];
    final balance = coinBalance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
      children: [
        topBar(),
        const SizedBox(height: 20),
        sectionHeading('MY WALLET', 'Your original account data'),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7750BA), Color(0xFF342052), Color(0xFF171126)],
            ),
            border: Border.all(color: gold.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(color: purple.withOpacity(0.2), blurRadius: 22),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: gold),
                  SizedBox(width: 8),
                  Text('COIN BALANCE', style: TextStyle(letterSpacing: 2, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.monetization_on, color: gold, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loading ? 'Loading...' : display(balance),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Connected Supabase wallet data',
                style: TextStyle(color: Color(0xFFD9CBEF), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: metric('Wallet rows', count('wallets'), Icons.wallet),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: metric('Transactions', count('wallet_transactions'), Icons.receipt_long),
            ),
          ],
        ),
        const SizedBox(height: 20),
        sectionHeading('Wallet Details', 'Your connected wallet record'),
        if (currentWallet.isEmpty)
          emptyState('Wallet data not returned', 'Your wallet table did not return a row for this session.')
        else
          dataItemCard(currentWallet, Icons.account_balance_wallet),
        const SizedBox(height: 18),
        sectionHeading('Recent Transactions', 'Wallet transaction records'),
        if (transactions.isEmpty)
          emptyState('No transactions returned', 'Transaction records will appear here when available.')
        else
          for (final row in transactions.take(15))
            dataItemCard(row, Icons.receipt_long),
      ],
    );
  }

  Widget giftsPage() {
    final gifts = data['gifts'] ?? [];
    final categories = data['gift_categories'] ?? [];
    final history = data['gift_send_history'] ?? [];
    final sends = data['gift_sends'] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
      children: [
        topBar(),
        const SizedBox(height: 20),
        sectionHeading('GIFT CENTER', 'Gifts from the ZOONL collection'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF753B83), Color(0xFF25152F)],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: pink.withOpacity(0.45)),
          ),
          child: const Row(
            children: [
              Icon(Icons.card_giftcard, color: gold, size: 40),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GIFT COLLECTION', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('Explore connected gifts and gift assets',
                        style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: metric('Gifts', gifts.length, Icons.redeem)),
            const SizedBox(width: 8),
            Expanded(child: metric('Categories', categories.length, Icons.category)),
            const SizedBox(width: 8),
            Expanded(child: metric('Sent', sends.length, Icons.send)),
          ],
        ),
        const SizedBox(height: 19),
        sectionHeading('Gift Categories', 'Browse gift groups'),
        if (categories.isEmpty)
          emptyState('No categories returned', 'Gift categories will appear here when available.')
        else
          for (final row in categories)
            dataItemCard(row, Icons.category),
        const SizedBox(height: 18),
        sectionHeading('Gift Collection', 'Original gift records'),
        if (gifts.isEmpty)
          emptyState('No gifts returned', 'The connected gifts table returned no rows.')
        else
          for (final row in gifts)
            giftCard(row),
        const SizedBox(height: 18),
        sectionHeading('Gift Assets', 'Animation and sound assets'),
        actionCard('Gift Assets', 'View connected gift media', Icons.animation,
            () => openSection('gift_assets')),
        actionCard('My Favorite Gifts', 'View saved favorites', Icons.favorite,
            () => openSection('gift_favorites')),
        const SizedBox(height: 18),
        sectionHeading('Gift History', 'Sent and received records'),
        actionCard('Gift Send History', '${history.length} history records',
            Icons.history, () => openSection('gift_send_history')),
        actionCard('Gift Sends', '${sends.length} send records',
            Icons.send, () => openSection('gift_sends')),
      ],
    );
  }

  Widget giftCard(Map<String, dynamic> row) {
    final name = firstValue(row, ['name', 'title', 'gift_name', 'gift_id']);
    final price = firstValue(row, ['price', 'coin_price', 'coins', 'cost']);
    final image = firstValue(row, ['image_url', 'icon_url', 'asset_url']);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.network(
                      image.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.card_giftcard, color: gold),
                    ),
                  )
                : const Icon(Icons.card_giftcard, color: gold, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display(name),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Price: ${display(price)}',
                    style: const TextStyle(color: gold, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }

  Widget profilePage() {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = myProfile;
    final name = firstValue(profile, [
      'username',
      'display_name',
      'full_name',
      'name',
    ]) ?? user?.email ?? 'ZOONL Member';

    final followers = number(profile['followers_count']);
    final following = number(profile['following_count']);
    final friends = number(profile['friends_count']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
      children: [
        topBar(),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgrounds[backgroundChoice][0],
                const Color(0xFF171126),
              ],
            ),
            border: Border.all(color: gold.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(color: purple.withOpacity(0.18), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      backgrounds[backgroundChoice][0],
                      purple2,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: showBackgroundPicker,
                    icon: const Icon(Icons.wallpaper, color: gold),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -37),
                child: Column(
                  children: [
                    Container(
                      height: 83,
                      width: 83,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: panel,
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [
                          BoxShadow(color: purple.withOpacity(0.35), blurRadius: 15),
                        ],
                      ),
                      child: const Icon(Icons.person, size: 45, color: gold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$name',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    zoonlIdLine(user),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 7,
                      children: [
                        ProfilePill(Icons.stars, 'LEVEL'),
                        ProfilePill(Icons.workspace_premium, 'CROWN'),
                        ProfilePill(Icons.verified, 'VIP'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: metric('Followers', followers, Icons.people)),
            const SizedBox(width: 8),
            Expanded(child: metric('Following', following, Icons.person_add)),
            const SizedBox(width: 8),
            Expanded(child: metric('Friends', friends, Icons.group)),
          ],
        ),
        const SizedBox(height: 20),
        sectionHeading('My Membership', 'Your account benefits'),
        Row(
          children: [
            Expanded(
              child: smallFeature(
                Icons.stars,
                'LEVEL',
                'Level system',
                () => openSection('level_definitions'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: smallFeature(
                Icons.diamond,
                'PRIME',
                'Premium tiers',
                () => openSection('prime_tiers'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: smallFeature(
                Icons.verified,
                'VIP',
                'Membership',
                () => openSection('user_prime_memberships'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        sectionHeading('My Space', 'Your personal features'),
        actionCard('My Gifts', 'Received gift records', Icons.card_giftcard,
            () => openSection('gift_send_history')),
        actionCard('My Wallet', 'Coins and balance', Icons.account_balance_wallet,
            () => openTab(2)),
        actionCard('My Transactions', 'Wallet history', Icons.receipt_long,
            () => openSection('wallet_transactions')),
        actionCard('Rewards', 'Reward catalog and claims', Icons.emoji_events,
            () => openSection('reward_catalog')),
        actionCard('My PRIME', 'Membership details', Icons.diamond,
            () => openSection('user_prime_memberships')),
        actionCard('Animated Background', 'Customize profile appearance',
            Icons.wallpaper, showBackgroundPicker),
        const SizedBox(height: 18),
        sectionHeading('Owner & Admin', 'Management data'),
        actionCard('Admin Permissions', 'View permission records',
            Icons.admin_panel_settings, () => openSection('admin_permissions')),
        actionCard('Agencies', 'Agency records and access',
            Icons.business, () => openSection('agencies')),
        actionCard('Agency Applications', 'Application records',
            Icons.assignment, () => openSection('agency_applications')),
        actionCard('Host Applications', 'Host application records',
            Icons.person_add_alt_1, () => openSection('host_applications')),
        const SizedBox(height: 18),
        actionCard('All Connected Data', 'Browse available database tables',
            Icons.storage, () => openSection('profiles')),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
      ],
    );
  }

  Widget zoonlIdLine(User? user) {
    if (user == null) {
      return const Text('Sign in to create your ZOONL ID');
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('user_public_profiles')
          .select('zoonl_id')
          .eq('user_id', user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading ZOONL ID...');
        }

        final id = snapshot.data?['zoonl_id'];

        return Text(
          id == null
              ? 'Complete profile setup to generate your ZOONL ID'
              : 'ZOONL ID: $id',
          style: const TextStyle(color: muted, fontSize: 10),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget tablePage(String table) {
    final section = sections.firstWhere(
      (s) => s.table == table,
      orElse: () => const AppSection(
        'Data',
        'Connected records',
        'profiles',
        Icons.storage,
      ),
    );
    final rows = data[table] ?? [];
    final error = errors[table];

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 100),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => selectedTable = null),
              icon: const Icon(Icons.arrow_back, color: gold),
            ),
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: loadData,
              icon: const Icon(Icons.refresh, color: gold),
            ),
          ],
        ),
        Text(section.subtitle, style: const TextStyle(color: muted)),
        const SizedBox(height: 15),
        metric('Records', rows.length, section.icon),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(25),
            child: Center(child: CircularProgressIndicator(color: gold)),
          ),
        if (error != null) errorBox('Data access error', error),
        if (!loading && error == null && rows.isEmpty)
          emptyState('No rows returned', 'The table may be empty or have no rows visible to this account.'),
        for (final row in rows)
          dataItemCard(row, section.icon),
        const SizedBox(height: 20),
        sectionHeading('Other Data Sections', 'Open another connected table'),
        for (final item in sections)
          if (item.table != table)
            actionCard(
              item.title,
              item.subtitle,
              item.icon,
              () => openSection(item.table),
            ),
      ],
    );
  }

  Widget metric(String label, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 21),
          const SizedBox(height: 7),
          Text(
            loading && value == 0 ? '...' : '$value',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: muted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: muted, fontSize: 10),
        ),
      ],
    );
  }

  Widget bigFeature(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, panel],
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: gold, size: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  )),
                  Text(subtitle, style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget smallFeature(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: gold.withOpacity(0.17)),
          ),
          child: Column(
            children: [
              Icon(icon, color: gold, size: 22),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              )),
              Text(subtitle, style: const TextStyle(
                color: muted,
                fontSize: 8,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget actionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          height: 39,
          width: 39,
          decoration: BoxDecoration(
            color: purple.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: gold, size: 21),
        ),
        title: Text(title, style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        )),
        subtitle: Text(subtitle, style: const TextStyle(
          color: muted,
          fontSize: 10,
        )),
        trailing: const Icon(Icons.chevron_right, color: muted),
      ),
    );
  }

  Widget feature(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return actionCard(title, subtitle, icon, onTap);
  }

  Widget dataItemCard(Map<String, dynamic> row, IconData icon) {
    final entries = row.entries.toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: gold, size: 21),
        title: Text(
          display(firstValue(row, [
            'name',
            'title',
            'username',
            'display_name',
            'id',
          ]) ?? 'Database Record'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${entries.length} fields',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: gold, fontSize: 10),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      display(entry.value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget emptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: gold, size: 30),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget errorBox(String title, String message) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF39231F),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 5),
          SelectableText(message, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  void showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROFILE BACKGROUND',
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Choose an appearance for this app preview.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                children: List.generate(backgrounds.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() => backgroundChoice = index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: backgrounds[index],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: backgroundChoice == index
                              ? gold
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: backgroundChoice == index
                          ? const Icon(Icons.check, color: gold)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class ProfilePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const ProfilePill(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: gold, size: 15),
      label: Text(text, style: const TextStyle(fontSize: 9)),
      backgroundColor: panel,
      side: BorderSide(color: gold.withOpacity(0.35)),
      visualDensity: VisualDensity.compact,
    );
  }
}

