import 'package:flutter/material.dart';
import 'role_portals_screen.dart';

class FeatureHubScreen extends StatelessWidget {
  const FeatureHubScreen({super.key});

  static const Color gold = Color(0xFFD6B46A);
  static const Color panel = Color(0xFF17232E);
  static const Color muted = Color(0xFFAAB5BE);

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
              colors: [Color(0xFF293B49), Color(0xFF17232E), Color(0xFF11101A)],
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
      color: const Color(0xFF17232E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (index == 10) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const RolePortalGateScreen(),
            ));
            return;
          }
          if (index == 9) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AgencyPortalScreen(),
            ));
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => _FeatureDetailPage(feature: feature, index: index),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF354653)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: const Color(0xFF293B49), borderRadius: BorderRadius.circular(14)),
                child: Icon(feature.icon, color: const Color(0xFFD6B46A), size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index. ${feature.title}', style: const TextStyle(color: Color(0xFFF8F7FB), fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(feature.subtitle, style: const TextStyle(color: Color(0xFFAAB5BE), fontSize: 12, height: 1.35)),
                ],
              )),
              const Icon(Icons.chevron_right, color: Color(0xFFD6B46A)),
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
      backgroundColor: const Color(0xFF080D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101923),
        title: Text(widget.feature.title, style: const TextStyle(color: Color(0xFFF8F7FB), fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Color(0xFFD6B46A)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF293B49), Color(0xFF17232E)]),
              border: Border.all(color: const Color(0xFFD6B46A).withOpacity(.4)),
            ),
            child: Row(children: [
              Icon(widget.feature.icon, color: const Color(0xFFD6B46A), size: 34),
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
              color: const Color(0xFF17232E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF354653)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                leading: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFFD6B46A),
                ),
                title: Text(
                  item,
                  style: const TextStyle(
                    color: Color(0xFFF4F1E9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Open this section',
                  style: TextStyle(
                    color: Color(0xFFAAB5BE),
                    fontSize: 11,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD6B46A),
                ),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF101923),
                  showDragHandle: true,
                  builder: (sheetContext) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item,
                            style: const TextStyle(
                              color: Color(0xFFD6B46A),
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'This section is included in the ZOONL LIVE application plan. Its live service must be connected and verified before it can process real account data or transactions.',
                            style: TextStyle(
                              color: Color(0xFFAAB5BE),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('CLOSE'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1D2B37), borderRadius: BorderRadius.circular(14)),
            child: const Text('STRUCTURE PREVIEW • This screen defines the feature layout. Live data, uploads, payments and privileged actions will be connected to their trusted services in the next phase.', style: TextStyle(color: Color(0xFFD0CCD9), height: 1.45)),
          ),
        ],
      ),
    );
  }
}
