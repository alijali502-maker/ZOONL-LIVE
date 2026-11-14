
import 'package:flutter/material.dart';

const Color _bg = Color(0xFF080611);
const Color _panel = Color(0xFF171126);
const Color _purple = Color(0xFF9360F5);
const Color _gold = Color(0xFFE6C47A);
const Color _muted = Color(0xFFAAA1BC);
const Color _pink = Color(0xFFDA65C8);

class ZoonlFeatureHub extends StatefulWidget {
  const ZoonlFeatureHub({
    super.key,
    this.isOwner = false,
    this.isAdmin = false,
  });

  final bool isOwner;
  final bool isAdmin;

  @override
  State<ZoonlFeatureHub> createState() => _ZoonlFeatureHubState();
}

class _ZoonlFeatureHubState extends State<ZoonlFeatureHub> {
  int selected = 0;

  final Map<String, bool> permissions = {
    'Manage Users': false,
    'Manage Top-ups': false,
    'Manage Agencies': false,
    'Manage Hosts': false,
    'Manage Withdrawals': false,
    'View Reports': false,
    'Manage Live Rooms': false,
    'Manage Gifts': false,
  };

  final List<String> sections = [
    'Owner & Admin',
    'Agency Management',
    'Direct Host',
    'Host Earnings',
    'PK Battles',
    'VIP & Profile',
    'Backpack',
    'Themes & Effects',
    'Reports & Security',
  ];

  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF35234F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          'ZOONL LIVE CONTROL CENTER',
          style: TextStyle(
            color: _gold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 112,
            child: ListView.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final active = selected == index;
                return InkWell(
                  onTap: () => setState(() => selected = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? _purple.withOpacity(.25) : _panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? _purple : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      sections[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: active ? _gold : _muted,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _heading(sections[selected]),
                const SizedBox(height: 14),
                _buildSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String title) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF56328D), _panel],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _gold.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _gold,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ZOONL LIVE • Management and feature center',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (selected) {
      case 0:
        return _ownerAdmin();
      case 1:
        return _agency();
      case 2:
        return _directHost();
      case 3:
        return _earnings();
      case 4:
        return _pk();
      case 5:
        return _vip();
      case 6:
        return _backpack();
      case 7:
        return _themes();
      default:
        return _reports();
    }
  }

  Widget _ownerAdmin() {
    return Column(
      children: [
        _featureCard(
          'OFFICIAL OWNER',
          'ZOONL ID 10001',
          'Permanent Owner identity and Owner control dashboard.',
          Icons.verified_user,
        ),
        _featureCard(
          'ADMIN MANAGEMENT',
          'Admin identity and permissions',
          'Grant or revoke individual Admin permissions and limits.',
          Icons.admin_panel_settings,
        ),
        _featureCard(
          'OWNER ACTIVITY LOG',
          'Administrative history',
          'Track Admin actions, permission changes and management activity.',
          Icons.history,
        ),
        _searchField('Admin ZOONL ID'),
        ...permissions.keys.map(
          (permission) => SwitchListTile(
            value: permissions[permission]!,
            activeColor: _purple,
            title: Text(permission),
            onChanged: widget.isOwner
                ? (value) => setState(
                      () => permissions[permission] = value,
                    )
                : null,
          ),
        ),
        _action(
          'SAVE ADMIN PERMISSIONS',
          () => notice(
            'Permission controls are displayed. Backend save integration is pending.',
          ),
        ),
      ],
    );
  }

  Widget _agency() {
    return Column(
      children: [
        _featureCard(
          'AGENCY APPLICATIONS',
          'Apply, approve or reject',
          'Agency application review and approval workflow.',
          Icons.business,
        ),
        _featureCard(
          'AGENCY PROFILE',
          'Name, code and commission',
          'Agency identity, registration code and commission settings.',
          Icons.badge,
        ),
        _featureCard(
          'AGENCY MEMBERS',
          'Hosts and team members',
          'Add members, assign roles and manage agency registrations.',
          Icons.groups,
        ),
        _featureCard(
          'AGENCY ADMIN',
          'Agency-specific access',
          'Separate permissions for agency administrators.',
          Icons.manage_accounts,
        ),
        _featureCard(
          'AGENCY REPORTS',
          'Earnings and performance',
          'Agency commission, hosts, top-ups and activity reports.',
          Icons.analytics,
        ),
        _action('NEW AGENCY APPLICATION', () {
          _formDialog('Agency Application', [
            'Proposed Agency Name',
            'Contact Details',
            'Country',
          ]);
        }),
        _action('CREATE AGENCY REGISTRATION CODE', () {
          _formDialog('Registration Code', [
            'Agency ID',
            'Registration Code',
          ]);
        }),
      ],
    );
  }

  Widget _directHost() {
    return Column(
      children: [
        _featureCard(
          'DIRECT HOST APPLICATION',
          'Independent of Agency',
          'Users can apply directly without joining an agency.',
          Icons.person_add_alt_1,
        ),
        _featureCard(
          'IDENTITY VERIFICATION',
          'ID and selfie verification',
          'Personal details, country, ID front/back and selfie submission.',
          Icons.verified,
        ),
        _featureCard(
          'OWNER REVIEW',
          'Approve or reject Host',
          'Owner review, application status and Host verification.',
          Icons.fact_check,
        ),
        _featureCard(
          'HOST DASHBOARD',
          'Host ID and performance',
          'Live hours, earnings, ranking and reports.',
          Icons.dashboard,
        ),
        _action('APPLY AS DIRECT HOST', () {
          _formDialog('Direct Host Application', [
            'Full Name',
            'Country',
            'Phone Number',
            'Date of Birth',
            'ID Document Type',
            'ID Front Image',
            'ID Back Image',
            'Selfie Verification',
          ]);
        }),
      ],
    );
  }

  Widget _earnings() {
    return Column(
      children: [
        _featureCard(
          'HOST SHARE',
          '65% Host share',
          'Host earning share configuration.',
          Icons.percent,
        ),
        _featureCard(
          'MONTHLY SETTLEMENT',
          'Monthly accounting',
          'Monthly earning calculation and settlement records.',
          Icons.calendar_month,
        ),
        _featureCard(
          'WITHDRAWALS',
          'Owner approval',
          'Host withdrawal requests and approval workflow.',
          Icons.account_balance_wallet,
        ),
        _featureCard(
          'HOST ADVANCE',
          'Separate advance ledger',
          'Record advances, monthly deductions and remaining balance.',
          Icons.receipt_long,
        ),
        _featureCard(
          r'$40 TWO-MONTH REWARD',
          '80 live hours and 20 active days',
          'At least 2 live hours per qualifying day for 20 days.',
          Icons.card_giftcard,
        ),
        _action('RECORD HOST ADVANCE', () {
          _formDialog('Host Advance', [
            'Host ZOONL ID',
            'Advance Amount',
            'Date',
            'Description',
          ]);
        }),
      ],
    );
  }

  Widget _pk() {
    return Column(
      children: [
        _featureCard(
          'PK 1 VS 1',
          'One-on-one battle',
          'Live battle with timer, score and winner result.',
          Icons.sports_martial_arts,
        ),
        _featureCard(
          'RANDOM PK',
          'Match with random creator',
          'Random PK matching workflow.',
          Icons.shuffle,
        ),
        _featureCard(
          'FRIENDS PK',
          'Invite friends',
          'Invite friends to start a PK battle.',
          Icons.people,
        ),
        _featureCard(
          'MULTI PK',
          'Up to 6 participants',
          'Multi-participant battle room with score and timer.',
          Icons.groups,
        ),
        _featureCard(
          'PK LEADERBOARD',
          'Scores and winners',
          'Battle scores, winner announcements and rankings.',
          Icons.leaderboard,
        ),
      ],
    );
  }

  Widget _vip() {
    return Column(
      children: [
        _featureCard(
          'USER LEVELS',
          'Level 1 to 100',
          'User experience levels and progression.',
          Icons.trending_up,
        ),
        _featureCard(
          'BADGE FOLDER',
          'Badges and VIP roles',
          'Collected badges, official roles and profile identity.',
          Icons.military_tech,
        ),
        _featureCard(
          'VIP ENTRY EFFECT',
          'First 5 days',
          'Five-day VIP entry effect for newly registered users.',
          Icons.auto_awesome,
        ),
        _featureCard(
          'PREMIUM PROFILE FRAME',
          'Profile appearance',
          'Premium profile frame selection.',
          Icons.crop_square,
        ),
        _featureCard(
          'PRIME MEMBERSHIP',
          'Membership management',
          'PRIME membership status and benefits.',
          Icons.workspace_premium,
        ),
      ],
    );
  }

  Widget _backpack() {
    return Column(
      children: [
        _featureCard(
          'MY BACKPACK',
          'Items and gifts',
          'User inventory for gifts, frames, effects and items.',
          Icons.backpack,
        ),
        _featureCard(
          'GIFT INVENTORY',
          'Owned gifts and items',
          'View and manage owned virtual items.',
          Icons.card_giftcard,
        ),
        _featureCard(
          'ITEM HISTORY',
          'Received and used items',
          'Inventory activity and item history.',
          Icons.history,
        ),
      ],
    );
  }

  Widget _themes() {
    return Column(
      children: [
        _featureCard(
          'PERSONAL THEMES',
          'Per-user customization',
          'Each user can choose their own app appearance.',
          Icons.palette,
        ),
        _featureCard(
          'ANIMATED BACKGROUNDS',
          'Individual user background',
          'Custom animated background behind the app interface.',
          Icons.animation,
        ),
        _featureCard(
          'CAMERA FILTERS',
          'Live camera effects',
          'Camera filters and visual effects for live streaming.',
          Icons.camera_alt,
        ),
        _featureCard(
          'BACKUP AND RESTORE',
          'User data recovery',
          'Backup and restore workflow for supported user data.',
          Icons.backup,
        ),
      ],
    );
  }

  Widget _reports() {
    return Column(
      children: [
        _featureCard(
          'USER REPORTS',
          'User and account activity',
          'User account and moderation reports.',
          Icons.people_alt,
        ),
        _featureCard(
          'FINANCIAL REPORTS',
          'Wallet and settlement',
          'Top-up, gifts, withdrawals and settlement reports.',
          Icons.bar_chart,
        ),
        _featureCard(
          'SECURITY LOGS',
          'Admin and Owner actions',
          'Permission changes and management history.',
          Icons.security,
        ),
      ],
    );
  }

  Widget _featureCard(
    String title,
    String subtitle,
    String description,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _purple.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 29),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
          padding: const EdgeInsets.all(15),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  void _formDialog(String title, List<String> fields) {
    final controllers = <TextEditingController>[
      for (var i = 0; i < fields.length; i++) TextEditingController(),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: Text(title, style: const TextStyle(color: _gold)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[i],
                      decoration: InputDecoration(
                        labelText: fields[i],
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              notice(
                '$title form is displayed. Database submission integration is pending.',
              );
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    ).then((_) {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }
}
