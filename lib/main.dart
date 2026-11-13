import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ZoonlLive());
}

const Color bg = Color(0xFF090D13);
const Color surface = Color(0xFF151D27);
const Color surface2 = Color(0xFF202B38);
const Color gold = Color(0xFFC9AD7A);
const Color white = Color(0xFFF3EEE5);
const Color grey = Color(0xFF9AA6B3);

class ZoonlLive extends StatelessWidget {
  const ZoonlLive({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          surface: surface,
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
  int selected = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    DiscoverScreen(),
    GiftsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selected,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF101720),
        indicatorColor: gold.withOpacity(0.16),
        selectedIndex: selected,
        onDestinationSelected: (index) {
          setState(() => selected = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard),
            label: 'Gifts',
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
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 25),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZOONL',
                    style: TextStyle(
                      fontSize: 25,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                      color: white,
                    ),
                  ),
                  Text(
                    'LIVE  •  CONNECT BEYOND',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: gold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.diamond_outlined, color: gold),
              const SizedBox(width: 6),
              const Text(
                '1,000',
                style: TextStyle(
                  color: white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => showMessage(context, 'Notifications'),
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 25, 20, 8),
          child: Text(
            'YOUR WORLD,',
            style: TextStyle(
              color: white,
              fontSize: 29,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'LIVE NOW.',
            style: TextStyle(
              color: gold,
              fontSize: 37,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Text(
            'Meet people. Share moments. Find your circle.',
            style: TextStyle(color: grey, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InkWell(
            onTap: () => showMessage(
              context,
              'Live streaming will be connected in the next development stage.',
            ),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 185,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: gold.withOpacity(0.4)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF435363),
                    Color(0xFF202D3B),
                    Color(0xFF111820),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'THE WORLD IS TUNING IN',
                    style: TextStyle(
                      color: gold,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find your people.',
                    style: TextStyle(
                      color: white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'EXPLORE LIVE',
                        style: TextStyle(
                          color: white,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: gold, size: 17),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionHeading(
          title: 'LIVE ROOMS',
          subtitle: 'HAPPENING AROUND THE WORLD',
        ),
        SizedBox(
          height: 195,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: const [
              LiveRoomCard(
                title: 'After Hours',
                host: 'with Elena',
                viewers: '2.4K',
                colors: [Color(0xFF536A79), Color(0xFF18232D)],
              ),
              LiveRoomCard(
                title: 'The Courtyard',
                host: 'with Amir',
                viewers: '860',
                colors: [Color(0xFF77634D), Color(0xFF25221E)],
              ),
              LiveRoomCard(
                title: 'Sound Society',
                host: 'with Noah',
                viewers: '1.1K',
                colors: [Color(0xFF66566F), Color(0xFF211B29)],
              ),
            ],
          ),
        ),
        const SectionHeading(
          title: 'YOUR NEXT CHAPTER',
          subtitle: 'BUILD YOUR PRESENCE',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: const [
              Expanded(
                child: FeatureCard(
                  icon: Icons.video_library_outlined,
                  title: 'Short videos',
                  subtitle: 'Share moments',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: FeatureCard(
                  icon: Icons.workspace_premium_outlined,
                  title: 'VIP lounge',
                  subtitle: 'Member access',
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: FeatureCard(
                  icon: Icons.trending_up,
                  title: 'Levels',
                  subtitle: 'Your journey',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageTitle(
          kicker: 'EXPLORE THE COMMUNITY',
          title: 'Discover',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: surface2),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: gold),
              SizedBox(width: 12),
              Text(
                'Find creators, rooms and interests',
                style: TextStyle(color: grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const SectionHeading(
          title: 'FEATURED CREATORS',
          subtitle: 'COMMUNITY SPOTLIGHT',
        ),
        const CreatorRow(
          name: 'Elena Rose',
          username: '@elena.rose',
          level: 'LV 28',
          color: Color(0xFF796D68),
        ),
        const CreatorRow(
          name: 'Amir Khan',
          username: '@amir.live',
          level: 'LV 36',
          color: Color(0xFF536B78),
        ),
        const CreatorRow(
          name: 'Noah James',
          username: '@noahj',
          level: 'LV 19',
          color: Color(0xFF746B83),
        ),
        const SectionHeading(
          title: 'SHORT VIDEOS',
          subtitle: 'FRESH FROM THE COMMUNITY',
        ),
        Row(
          children: const [
            Expanded(
              child: VideoCard(
                title: 'City evenings',
                icon: Icons.location_city,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: VideoCard(
                title: 'Architecture',
                icon: Icons.account_balance,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GiftsScreen extends StatelessWidget {
  const GiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageTitle(
          kicker: 'THE GIFT COLLECTION',
          title: 'Give a moment.',
        ),
        const SizedBox(height: 8),
        const Text(
          'A collection of gestures for the people who make your day.',
          style: TextStyle(color: grey, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withOpacity(0.4)),
            gradient: const LinearGradient(
              colors: [Color(0xFF344454), Color(0xFF171F29)],
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.diamond_outlined, color: gold, size: 30),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEMO DIAMOND BALANCE',
                      style: TextStyle(
                        color: grey,
                        fontSize: 9,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '1,000',
                      style: TextStyle(
                        color: white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GiftRow(
          title: 'Midnight Rose',
          detail: 'A signature gesture',
          price: '120',
          icon: Icons.local_florist_outlined,
          onTap: () => showMessage(context, 'Gift service is not connected yet.'),
        ),
        GiftRow(
          title: 'Golden Hour',
          detail: 'A moment worth keeping',
          price: '350',
          icon: Icons.wb_twilight_outlined,
          onTap: () => showMessage(context, 'Gift service is not connected yet.'),
        ),
        GiftRow(
          title: 'Grand Entrance',
          detail: 'Make an arrival',
          price: '800',
          icon: Icons.auto_awesome_outlined,
          onTap: () => showMessage(context, 'Gift service is not connected yet.'),
        ),
        GiftRow(
          title: 'Celestial Suite',
          detail: 'A rare celebration',
          price: '1,500',
          icon: Icons.diamond_outlined,
          onTap: () => showMessage(context, 'Gift service is not connected yet.'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sample interface values only. No real payment or transfer is active.',
          style: TextStyle(color: grey, fontSize: 10),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'MY SPACE',
          style: TextStyle(
            color: gold,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: gold.withOpacity(0.35)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B4A57),
                Color(0xFF202A35),
                Color(0xFF141A22),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 75,
                    width: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 2),
                      color: surface2,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Display Name',
                          style: TextStyle(
                            color: white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '@yourhandle  •  ID 000000',
                          style: TextStyle(color: grey, fontSize: 10),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: gold,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'New member',
                              style: TextStyle(color: gold, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Your story starts here. Add a little about yourself and let the world know what you love.',
                style: TextStyle(
                  color: Color(0xFFD0D5DA),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showMessage(
                    context,
                    'Profile editing will be connected with account services.',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: white,
                    side: const BorderSide(color: gold),
                  ),
                  child: const Text('EDIT PROFILE'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(child: StatBlock(value: '0', label: 'FOLLOWERS')),
            Expanded(child: StatBlock(value: '0', label: 'FOLLOWING')),
            Expanded(child: StatBlock(value: '0', label: 'LIKES')),
          ],
        ),
        const SizedBox(height: 25),
        const Text(
          'YOUR VIDEOS',
          style: TextStyle(
            color: white,
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 145,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surface2),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: gold,
                size: 30,
              ),
              SizedBox(height: 10),
              Text(
                'Your video gallery',
                style: TextStyle(color: white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                'Your published clips will appear here.',
                style: TextStyle(color: grey, fontSize: 11),
              ),
            ],
          ),
        ),
        const SectionHeading(
          title: 'MEMBERSHIP & PROGRESS',
          subtitle: 'TWO DIFFERENT JOURNEYS',
        ),
        const ProgressCard(
          title: 'VIP MEMBERSHIP',
          value: 'STANDARD',
          detail: 'Member benefits and privileges',
          icon: Icons.workspace_premium_outlined,
        ),
        const SizedBox(height: 10),
        const ProgressCard(
          title: 'CREATOR LEVEL',
          value: 'LEVEL 1',
          detail: 'Your activity journey starts here',
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class LiveRoomCard extends StatelessWidget {
  final String title;
  final String host;
  final String viewers;
  final List<Color> colors;

  const LiveRoomCard({
    super.key,
    required this.title,
    required this.host,
    required this.viewers,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF9B4545),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            host,
            style: const TextStyle(color: white, fontSize: 10),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 13, color: white),
              const SizedBox(width: 5),
              Text(
                viewers,
                style: const TextStyle(color: white, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: gold,
              fontSize: 8,
              letterSpacing: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surface2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: gold, size: 21),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: grey, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String kicker;
  final String title;

  const PageTitle({
    super.key,
    required this.kicker,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: const TextStyle(
            color: gold,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: white,
            fontSize: 29,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CreatorRow extends StatelessWidget {
  final String name;
  final String username;
  final String level;
  final Color color;

  const CreatorRow({
    super.key,
    required this.name,
    required this.username,
    required this.level,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: surface2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: const Icon(Icons.person, color: white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(color: grey, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            level,
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: grey),
        ],
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const VideoCard({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 155,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF465A68), Color(0xFF1B2731)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: gold, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class GiftRow extends StatelessWidget {
  final String title;
  final String detail;
  final String price;
  final IconData icon;
  final VoidCallback onTap;

  const GiftRow({
    super.key,
    required this.title,
    required this.detail,
    required this.price,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: surface2),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF303A43),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: gold, size: 26),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.diamond_outlined, color: gold, size: 14),
            const SizedBox(width: 5),
            Text(
              price,
              style: const TextStyle(
                color: white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatBlock extends StatelessWidget {
  final String value;
  final String label;

  const StatBlock({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: grey,
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class ProgressCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;

  const ProgressCard({
    super.key,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: surface2),
      ),
      child: Row(
        children: [
          Icon(icon, color: gold, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: grey,
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(color: white, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
