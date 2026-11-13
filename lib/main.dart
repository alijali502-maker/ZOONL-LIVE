
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ZoonlApp());
}

const bg = Color(0xFF090713);
const panel = Color(0xFF19132A);
const purple = Color(0xFF9360F5);
const gold = Color(0xFFE6C47A);
const muted = Color(0xFFAAA1BC);

const tables = [
  'profiles',
  'level_definitions',
  'prime_tiers',
  'user_prime_memberships',
  'wallets',
  'wallet_transactions',
  'gift_catalog',
  'gift_sends',
  'live_rooms',
  'live_room_members',
  'reward_catalog',
  'reward_claims',
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
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0;
  int slide = 0;
  bool loading = true;
  String? connectionError;
  Timer? timer;

  final Map<String, List<Map<String, dynamic>>> data = {};
  final Map<String, String> errors = {};

  final banners = const [
    ('WELCOME TO ZOONL LIVE', 'Your world. Your stage.', Icons.public),
    ('DAILY REWARDS', 'Discover rewards and events', Icons.card_giftcard),
    ('LEVEL UP', 'Every moment brings a milestone', Icons.stars),
    ('PRIME MEMBERSHIP', 'Explore premium experiences', Icons.workspace_premium),
    ('LIVE TOGETHER', 'Meet creators around the world', Icons.live_tv),
  ];

  @override
  void initState() {
    super.initState();
    loadData();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => slide = (slide + 1) % banners.length);
      }
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
      await Future.wait(tables.map((table) async {
        try {
          final result = await Supabase.instance.client
              .from(table)
              .select()
              .limit(30)
              .timeout(const Duration(seconds: 12));

          data[table] =
              List<Map<String, dynamic>>.from(result);
        } catch (e) {
          errors[table] = e.toString();
        }
      })).timeout(const Duration(seconds: 20));
    } catch (e) {
      connectionError = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  int count(String table) => data[table]?.length ?? 0;

  int number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  int get total =>
      data.values.fold(0, (sum, rows) => sum + rows.length);

  @override
  Widget build(BuildContext context) {
    final pages = [homePage(), dataPage(), profilePage()];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF151020),
        indicatorColor: purple.withOpacity(0.2),
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage),
            label: 'Data',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget topBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [purple, Color(0xFF5630A4)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.bolt, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'ZOONL LIVE',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        IconButton(
          onPressed: loading ? null : loadData,
          icon: const Icon(Icons.refresh, color: gold),
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
        padding: const EdgeInsets.all(18),
        children: [
          topBar(),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(slide),
              height: 190,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6338A8),
                    Color(0xFF28163F),
                    Color(0xFF171126),
                  ],
                ),
                border: Border.all(color: gold.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: purple.withOpacity(0.2),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: -15,
                    child: Icon(
                      banner.$3,
                      size: 125,
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        banner.$1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner.$2,
                        style: const TextStyle(
                          color: Color(0xFFE0D7F0),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: List.generate(
                          banners.length,
                          (i) => Container(
                            margin: const EdgeInsets.only(right: 5),
                            height: 4,
                            width: i == slide ? 22 : 7,
                            decoration: BoxDecoration(
                              color: i == slide ? gold : Colors.white38,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
              Expanded(
                child: metric('Profiles', count('profiles'), Icons.people),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: metric('Live Rooms', count('live_rooms'), Icons.live_tv),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: metric('Gifts', count('gift_catalog'), Icons.card_giftcard),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Explore',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          feature(Icons.video_library, 'Short Videos', 'Creator videos and moments'),
          feature(Icons.emoji_events, 'Rewards & Events', 'Levels and special events'),
          feature(Icons.workspace_premium, 'PRIME Membership', 'Premium experiences'),
          if (connectionError != null)
            errorBox('Connection problem', connectionError!),
          if (!loading && errors.isNotEmpty)
            errorBox(
              'Some tables need access',
              '${errors.length} tables could not be read. Open Data for details.',
            ),
        ],
      ),
    );
  }

  Widget metric(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold),
          const SizedBox(height: 7),
          Text(
            loading ? '...' : '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget feature(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: gold, size: 26),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
  }

  Widget dataPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        topBar(),
        const SizedBox(height: 18),
        const Text(
          'SUPABASE DATA',
          style: TextStyle(color: gold, letterSpacing: 2),
        ),
        Text(
          loading ? 'Connecting...' : '$total records loaded',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (connectionError != null)
          errorBox('Connection error', connectionError!),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: gold),
            ),
          ),
        for (final table in tables) tableCard(table),
      ],
    );
  }

  Widget tableCard(String table) {
    final rows = data[table];
    final error = errors[table];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        title: Text(table),
        subtitle: Text(
          error != null ? 'Error' : '${rows?.length ?? 0} records',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                error,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
            )
          else if (rows == null || rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No rows returned or table is empty',
                style: TextStyle(color: muted),
              ),
            )
          else
            for (final row in rows.take(8))
              Padding(
                padding: const EdgeInsets.all(10),
                child: SelectableText(
                  row.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
        ],
      ),
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
  Widget profilePage() {
    final user = Supabase.instance.client.auth.currentUser;
    final rows = data['profiles'] ?? [];
    final profile = rows.isEmpty ? <String, dynamic>{} : rows.first;
    final name = profile['username'] ??
        profile['display_name'] ??
        user?.email ??
        'ZOONL Member';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        topBar(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF513080), Color(0xFF20152F)],
            ),
            border: Border.all(color: gold.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold, width: 2),
                  color: purple.withOpacity(0.2),
                ),
                child: const Icon(Icons.person, size: 44, color: gold),
              ),
              const SizedBox(height: 12),
              Text(
                '$name',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              Text(
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: metric('Followers', number(profile['followers_count']), Icons.people),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: metric('Following', number(profile['following_count']), Icons.person_add),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: metric('Friends', number(profile['friends_count']), Icons.group),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'My Space',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        feature(Icons.video_library, 'Short Videos', 'Your videos and posts'),
        feature(Icons.photo, 'Photo Posts', 'Your shared moments'),
        feature(Icons.card_giftcard, 'Received Gifts', 'Gifts from your community'),
        feature(Icons.collections, 'My Collection', 'Saved items'),
        feature(Icons.wallpaper, 'Animated Background', 'Profile appearance'),
        feature(Icons.settings, 'Settings & Privacy', 'Account controls'),
        if (user != null)
          OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
      ],
    );
  }

  Widget errorBox(String title, String message) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF39231F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          SelectableText(message, style: const TextStyle(fontSize: 11)),
        ],
      ),
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
    );
  }
}

