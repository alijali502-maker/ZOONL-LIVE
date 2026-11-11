import 'package:flutter/material.dart';

void main() {
  runApp(const ZoonlLive());
}

class ZoonlLive extends StatelessWidget {
  const ZoonlLive({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF101020);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZOONL LIVE',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
          surface: const Color(0xFF202039),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF19192D),
          selectedItemColor: Colors.purpleAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    _HomeTab(),
    _SimpleTab(
      icon: Icons.live_tv,
      title: 'Live rooms',
      message: 'Find a room and join the conversation.',
    ),
    _SimpleTab(
      icon: Icons.card_giftcard,
      title: 'Virtual gifts',
      message: 'Send a little appreciation to your favorite hosts.',
    ),
    _SimpleTab(
      icon: Icons.person,
      title: 'Your profile',
      message: 'Your ZOONL LIVE profile is ready to set up.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ZOONL LIVE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.purpleAccent,
          ),
        ),
        actions: const [
          Icon(Icons.diamond, color: Colors.cyan),
          SizedBox(width: 8),
          Text('1000'),
          SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live'),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Gifts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Welcome to ZOONL LIVE',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect with people around the world.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 25),
        const _SectionHeading('LIVE ROOMS'),
        const SizedBox(height: 15),
        _RoomCard(name: 'Global Music Room', viewers: '120 viewers', color: Colors.purple),
        _RoomCard(name: 'Friends Lounge', viewers: '85 viewers', color: Colors.blue),
        _RoomCard(name: 'VIP Party Room', viewers: '250 viewers', color: Colors.deepPurple),
        const SizedBox(height: 25),
        const _SectionHeading('YOUR FEATURES'),
        const SizedBox(height: 8),
        const _Feature(icon: Icons.video_call, name: 'Live Video'),
        const _Feature(icon: Icons.card_giftcard, name: 'Virtual Gifts'),
        const _Feature(icon: Icons.diamond, name: 'Coins & Diamonds'),
        const _Feature(icon: Icons.workspace_premium, name: 'VIP Membership'),
        const _Feature(icon: Icons.sports_esports, name: 'Games'),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.name,
    required this.viewers,
    required this.color,
  });

  final String name;
  final String viewers;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF202039),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.play_arrow, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Text(viewers),
        trailing: IconButton(
          tooltip: 'Like $name',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You liked $name')),
          ),
          icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
        ),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joining $name…')),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Colors.purpleAccent),
        title: Text(name),
      );
}

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Colors.purpleAccent),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
