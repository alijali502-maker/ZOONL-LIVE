import 'package:flutter/material.dart';

class FeatureHubScreen extends StatelessWidget {
  const FeatureHubScreen({super.key});

  static const Color gold = Color(0xFFE8C77B);
  static const Color panel = Color(0xFF171326);
  static const Color muted = Color(0xFFAAA5B7);

  static const List<_Feature> features = <_Feature>[
    _Feature('Home & Discovery', 'Discover creators, trending rooms and popular videos.', Icons.explore, ['Recommended creators', 'Trending now', 'Live now', 'Following feed', 'Search people and rooms', 'Categories']),
    _Feature('Short Videos', 'A complete creator studio and public video feed.', Icons.play_circle, ['For You feed', 'Following feed', 'Record video', 'Choose from gallery', 'Filters and effects', 'Caption and hashtags', 'Like, comment and share', 'My uploads']),
    _Feature('Live Streaming', 'Video and audio rooms with guest and moderation controls.', Icons.live_tv, ['Start video live', 'Start audio live', 'Room title and cover', 'Guest invitations and seats', 'Live chat and viewers', 'Mute and camera controls', 'Moderators and room rules', 'Private room access']),
    _Feature('PK Battle', 'Multi-seat battle layouts, invitations and score panels.', Icons.sports_mma, ['1 vs 1', '2 player layout', '3 player layout', '4 player grid', '6 player grid', 'Invite and accept', 'Countdown and timer', 'Scoreboard and history']),
    _Feature('Wallet & Gifts', 'Coins, gift catalog, top-ups and transaction history.', Icons.account_balance_wallet, ['Coin balance', 'Top-up packages', 'Gift catalog', 'Gift animation and sound', 'Sent gift history', 'Received gift history', 'Wallet transactions', 'Earnings and payout history']),
    _Feature('Profile & Social', 'Identity, creator profile and social connections.', Icons.person, ['Profile photo', 'Display name', 'User ID', 'Bio and country', 'Followers and following', 'Friends', 'VIP and level badges', 'Privacy and blocked users']),
    _Feature('Messages & Notifications', 'Private conversations, requests and account alerts.', Icons.forum, ['Private conversations', 'Message requests', 'Friend requests', 'Gift notifications', 'Live notifications', 'System announcements', 'Block and report']),
    _Feature('VIP & Events', 'Membership, levels, rewards and leaderboards.', Icons.workspace_premium, ['VIP membership', 'Level progression', 'Frames and entry effects', 'Profile backgrounds', 'Weekly Star 1 to 5', 'Daily leaderboard', 'Weekly leaderboard', 'Monthly leaderboard', 'Event rewards']),
    _Feature('Agency & Creator Center', 'Creator applications, verification and agency tools.', Icons.business_center, ['Streamer agency application', 'Top-up agency application', 'Combined agency application', 'Host registration', 'Identity document upload', 'Application status', 'Live-hour targets', 'Agency reports']),
    _Feature('Owner & Admin Control', 'Permission-based operations and platform oversight.', Icons.admin_panel_settings, ['Owner identity: 10001', 'P2 / P3 / P4 permission groups', 'Admin permission management', 'User management', 'Gift and package configuration', 'Agency approvals', 'Reports and moderation', 'Audit history']),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF30234D), Color(0xFF171326), Color(0xFF11101A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(.45)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ZOONL LIVE', style: TextStyle(color: gold, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              SizedBox(height: 8),
              Text('Your world of live entertainment', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              SizedBox(height: 5),
              Text('Explore all ten feature areas. Service connections can be added to each section without redesigning the app.', style: TextStyle(color: Color(0xFFD0CCD9), height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('ALL APP FEATURES', style: TextStyle(color: gold, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        for (int i = 0; i < features.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FeatureCard(index: i + 1, feature: features[i]),
          ),
      ],
    );
  }
}

class _Feature {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> items;
  const _Feature(this.title, this.subtitle, this.icon, this.items);
}

class _FeatureCard extends StatelessWidget {
  final int index;
  final _Feature feature;
  const _FeatureCard({required this.index, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171326),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => _FeatureDetailPage(feature: feature, index: index),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF393149)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFF30234D), borderRadius: BorderRadius.circular(14)),
                child: Icon(feature.icon, color: const Color(0xFFE8C77B), size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index. ${feature.title}', style: const TextStyle(color: Color(0xFFF8F7FB), fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(feature.subtitle, style: const TextStyle(color: Color(0xFFAAA5B7), fontSize: 12, height: 1.35)),
                ],
              )),
              const Icon(Icons.chevron_right, color: Color(0xFFE8C77B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureDetailPage extends StatefulWidget {
  final _Feature feature;
  final int index;
  const _FeatureDetailPage({required this.feature, required this.index});

  @override
  State<_FeatureDetailPage> createState() => _FeatureDetailPageState();
}

class _FeatureDetailPageState extends State<_FeatureDetailPage> {
  final Set<String> selected = <String>{};
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.feature.items.where((e) => e.toLowerCase().contains(searchController.text.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF090812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF100D1B),
        title: Text(widget.feature.title, style: const TextStyle(color: Color(0xFFF8F7FB), fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Color(0xFFE8C77B)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF30234D), Color(0xFF171326)]),
              border: Border.all(color: const Color(0xFFE8C77B).withOpacity(.4)),
            ),
            child: Row(children: [
              Icon(widget.feature.icon, color: const Color(0xFFE8C77B), size: 34),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.feature.subtitle, style: const TextStyle(color: Colors.white, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find a feature', filled: true),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              color: const Color(0xFF171326),
              child: CheckboxListTile(
                value: selected.contains(item),
                activeColor: const Color(0xFF8B5CF6),
                checkColor: Colors.white,
                title: Text(item, style: const TextStyle(color: Color(0xFFF1EEF7))),
                subtitle: const Text('Feature area in the app structure', style: TextStyle(color: Color(0xFFAAA5B7), fontSize: 11)),
                onChanged: (value) => setState(() {
                  if (value == true) { selected.add(item); } else { selected.remove(item); }
                }),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF211B30), borderRadius: BorderRadius.circular(14)),
            child: const Text('STRUCTURE PREVIEW • This screen defines the feature layout. Live data, uploads, payments and privileged actions will be connected to their trusted services in the next phase.', style: TextStyle(color: Color(0xFFD0CCD9), height: 1.45)),
          ),
        ],
      ),
    );
  }
}
