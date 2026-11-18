import 'package:flutter/material.dart';
import 'core/backend.dart';

const Color _bg = Color(0xFF080D14);
const Color _panel = Color(0xFF17232E);
const Color _raised = Color(0xFF1D2B37);
const Color _gold = Color(0xFFD6B46A);
const Color _teal = Color(0xFF4BC2B0);
const Color _muted = Color(0xFFAAB5BE);

class RolePortalGateScreen extends StatefulWidget {
  const RolePortalGateScreen({super.key});
  @override
  State<RolePortalGateScreen> createState() => _RolePortalGateScreenState();
}

class _RolePortalGateScreenState extends State<RolePortalGateScreen> {
  bool loading = true;
  bool owner = false;
  final Map<String, bool> adminPermissions = {};
  String? error;

  static const Map<String, String> permissionLabels = {
    'manage_users': 'User Management',
    'manage_topups': 'Top-up Management',
    'manage_agencies': 'Agency Management',
    'manage_hosts': 'Host Management',
    'manage_withdrawals': 'Withdrawal Review',
    'view_reports': 'Reports & Analytics',
    'manage_live_rooms': 'Live Room Moderation',
    'manage_gifts': 'Gift Catalogue',
  };

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    try {
      final bool isOwner = await Backend.isZoonlOwner();
      final Map<String, bool> permissions = {};
      if (!isOwner) {
        for (final key in permissionLabels.keys) {
          permissions[key] = await Backend.isZoonlAdminAllowed(key);
        }
      }
      if (!mounted) return;
      setState(() {
        owner = isOwner;
        adminPermissions.addAll(permissions);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool admin = adminPermissions.values.any((v) => v);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Official Control Portals')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : error != null
              ? _message('Verification unavailable', error!)
              : owner
                  ? const OwnerMasterPortalScreen()
                  : admin
                      ? AdminOperationsPortalScreen(permissions: adminPermissions)
                      : _message(
                          'No privileged access',
                          'This account has no Owner or Admin permission. Public ZOONL ID is not used to grant portal access.',
                        ),
    );
  }

  Widget _message(String title, String detail) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _gold.withOpacity(.35)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_outlined, color: _gold, size: 42),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(color: _gold, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.5)),
            ]),
          ),
        ),
      );
}

class OwnerMasterPortalScreen extends StatefulWidget {
  const OwnerMasterPortalScreen({super.key});
  @override
  State<OwnerMasterPortalScreen> createState() => _OwnerMasterPortalScreenState();
}

class _OwnerMasterPortalScreenState extends State<OwnerMasterPortalScreen> {
  int selected = 0;
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> records = const [];
  final TextEditingController search = TextEditingController();
  final TextEditingController adminId = TextEditingController();
  final TextEditingController agencyName = TextEditingController();
  final TextEditingController agencyCode = TextEditingController();
  final TextEditingController commission = TextEditingController(text: '65');
  final TextEditingController coinTargetId = TextEditingController();
  final TextEditingController coinAmount = TextEditingController();
  final TextEditingController coinDescription = TextEditingController();
  bool allowTopups = true;
  bool actionBusy = false;

  static const List<_PortalSection> sections = [
    _PortalSection('Overview', Icons.dashboard_outlined),
    _PortalSection('Admin Registry', Icons.admin_panel_settings_outlined),
    _PortalSection('Agency Registry', Icons.business_outlined),
    _PortalSection('User Directory', Icons.people_outline),
    _PortalSection('Wallet Accounts', Icons.account_balance_wallet_outlined),
    _PortalSection('Top-up & Transactions', Icons.receipt_long_outlined),
    _PortalSection('Gift Catalogue', Icons.card_giftcard_outlined),
    _PortalSection('Live Operations', Icons.live_tv_outlined),
    _PortalSection('Security & Audit', Icons.security_outlined),
  ];

  static const List<String> _portalTables = [
    '',
    'owner_admin_permissions',
    'agency_applications',
    'profiles',
    'wallets',
    'wallet_transactions',
    'gifts',
    'live_rooms',
    'owner_control_settings',
  ];

  String get _table => _portalTables[selected];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    search.dispose();
    adminId.dispose();
    agencyName.dispose();
    agencyCode.dispose();
    commission.dispose();
    coinTargetId.dispose();
    coinAmount.dispose();
    coinDescription.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    if (selected == 0) {
      setState(() { loading = false; error = null; records = []; });
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      List<Map<String, dynamic>> rows;
      if (selected == 2) {
        final dynamic result = await Backend.client.rpc('owner_list_agencies');
        final dynamic values = result is Map ? result['agencies'] : result;
        rows = values is List
            ? values.map((row) => Map<String, dynamic>.from(row as Map)).toList()
            : <Map<String, dynamic>>[];
      } else {
        rows = await Backend.fetchPortalRows(_table);
      }
      if (!mounted) return;
      setState(() { records = rows; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; records = []; });
    }
  }

  void _select(int index) {
    setState(() { selected = index; });
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _portalHeader('OWNER MASTER CONTROL', 'OFFICIAL OWNER • ZOONL ID 10001', Icons.workspace_premium),
      SizedBox(
        height: 58,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: sections.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: Text(sections[i].title),
              selected: selected == i,
              onSelected: (_) => _select(i),
              selectedColor: _gold.withOpacity(.22),
              backgroundColor: _panel,
              labelStyle: TextStyle(color: selected == i ? _gold : _muted, fontSize: 11, fontWeight: FontWeight.w700),
              side: BorderSide(color: selected == i ? _gold : const Color(0xFF354653)),
            ),
          ),
        ),
      ),
      Expanded(child: selected == 0 ? _overview() : _records()),
    ]);
  }

  Widget _overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _portalCard('PLATFORM AUTHORITY', 'Owner authority is verified through the Supabase is_zoonl_owner() function. Public ID alone never grants access.', Icons.verified_user),
      const SizedBox(height: 12),
      _portalGrid([
        ('Admin Registry', 'Permission rows', Icons.admin_panel_settings),
        ('Agency Registry', 'Applications', Icons.business),
        ('User Directory', 'Profiles', Icons.people),
        ('Wallet Accounts', 'Wallet records', Icons.account_balance_wallet),
        ('Top-up & Transactions', 'Ledger records', Icons.receipt_long),
        ('Gift Catalogue', 'Gift records', Icons.card_giftcard),
        ('Live Operations', 'Room records', Icons.live_tv),
        ('Security & Audit', 'Owner controls', Icons.security),
      ]),
      const SizedBox(height: 14),
      _portalCard('OWNER-ONLY OPERATIONS', 'Admin permissions, official role issuance, coin adjustments, agency approvals and payout decisions must be completed by trusted server functions. The portal reads protected records and never fabricates balances or approvals.', Icons.lock),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _select(1),
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('OPEN ADMIN REGISTRY'),
      ),
      OutlinedButton.icon(
        onPressed: () => _select(2),
        icon: const Icon(Icons.business),
        label: const Text('OPEN AGENCY REGISTRY'),
      ),
      OutlinedButton.icon(
        onPressed: () => _select(5),
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('OPEN WALLET & TOP-UP RECORDS'),
      ),
    ],
  );

  Widget _portalGrid(List<(String, String, IconData)> items) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 9,
    crossAxisSpacing: 9,
    childAspectRatio: 1.65,
    children: [
      for (int i = 0; i < items.length; i++)
        InkWell(
          onTap: () => _select(i + 1),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF354653))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(items[i].$3, color: _gold, size: 23),
              const SizedBox(height: 7),
              Text(items[i].$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              Text(items[i].$2, style: const TextStyle(color: _muted, fontSize: 10)),
            ]),
          ),
        ),
    ],
  );

  Future<void> _setAdminTopupPermission() async {
    final id = adminId.text.trim();
    if (!RegExp(r'^[0-9]{5,12}
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records'),
        ),
      ),
      if (loading) const LinearProgressIndicator(color: _gold),
      if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text('Could not load $_table: $error', style: const TextStyle(color: Color(0xFFE47777)))),
      Expanded(
        child: filtered.isEmpty && !loading && error == null
            ? const Center(child: Text('No records returned by the connected database.', style: TextStyle(color: _muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final row = filtered[i];
                  final title = row['display_name'] ?? row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Database record';
                  return Card(
                    color: _panel,
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined, color: _gold),
                      title: Text(title.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(row.entries.take(5).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
                      trailing: const Icon(Icons.chevron_right, color: _gold),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: _panel,
                          title: Text(title.toString(), style: const TextStyle(color: _gold)),
                          content: SingleChildScrollView(child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('\n'), style: const TextStyle(color: _muted, fontSize: 12))),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(onPressed: loading ? null : _loadRecords, icon: const Icon(Icons.refresh), label: const Text('REFRESH DATABASE RECORDS')),
      ),
    ]);
  }
}

class AdminOperationsPortalScreen extends StatefulWidget {
  final Map<String, bool> permissions;
  const AdminOperationsPortalScreen({super.key, required this.permissions});

  @override
  State<AdminOperationsPortalScreen> createState() => _AdminOperationsPortalScreenState();
}

class _AdminOperationsPortalScreenState extends State<AdminOperationsPortalScreen> {
  final TextEditingController targetId = TextEditingController();
  final TextEditingController amount = TextEditingController();
  final TextEditingController description = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    targetId.dispose();
    amount.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _addCoins() async {
    final id = targetId.text.trim();
    final coins = int.tryParse(amount.text.trim());
    if (!RegExp(r'^[0-9]{5,12}$').hasMatch(id) || coins == null || coins <= 0) {
      _notice('Enter a valid User ID and positive Coin amount.');
      return;
    }
    setState(() => busy = true);
    try {
      await Backend.client.rpc(
        'add_zoonl_coins',
        params: <String, dynamic>{
          'p_zoonl_id': id,
          'p_amount': coins,
          'p_description': description.text.trim().isEmpty
              ? 'Admin top-up'
              : description.text.trim(),
        },
      );
      targetId.clear();
      amount.clear();
      description.clear();
      _notice('Coins added through the secure Supabase ledger.');
    } catch (e) {
      _notice('Top-up failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final granted = widget.permissions.entries.where((e) => e.value).toList();
    final canTopup = widget.permissions['manage_topups'] == true;
    return Column(children: [
      _portalHeader('ADMIN OPERATIONS PORTAL', 'ONLY OWNER-GRANTED PERMISSIONS', Icons.admin_panel_settings),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _portalCard('YOUR ACCESS SCOPE', 'Only permissions confirmed by is_zoonl_admin_allowed() are shown. Missing permissions remain unavailable.', Icons.verified_user),
          const SizedBox(height: 12),
          for (final item in granted)
            Card(
              color: _panel,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _teal),
                title: Text(item.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Permission verified by Supabase', style: TextStyle(color: _muted, fontSize: 11)),
                trailing: const Icon(Icons.lock_open, color: _teal),
              ),
            ),
          if (canTopup) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: _gold.withOpacity(.35))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AUTHORIZED TOP-UP OPERATIONS', style: TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 9),
                  TextField(controller: targetId, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Recipient ZOONL ID')),
                  const SizedBox(height: 8),
                  TextField(controller: amount, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Coin amount')),
                  const SizedBox(height: 8),
                  TextField(controller: description, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Receipt / description')),
                  const SizedBox(height: 9),
                  FilledButton(onPressed: busy ? null : _addCoins, child: Text(busy ? 'PROCESSING…' : 'ADD COINS')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _portalCard('SECURITY RULE', 'Admin cannot grant permissions, issue Owner identity, change owner settings or exceed the limits granted by the Owner. Every Coin adjustment is checked again by the Supabase function.', Icons.shield),
        ],
      )),
    ]);
  }
}

class AgencyPortalScreen extends StatefulWidget {
  const AgencyPortalScreen({super.key});
  @override
  State<AgencyPortalScreen> createState() => _AgencyPortalScreenState();
}

class _AgencyPortalScreenState extends State<AgencyPortalScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Backend.fetchPortalRows('agency_applications');
      if (!mounted) return;
      setState(() { rows = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Agency & Creator Portal')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalHeader('OFFICIAL AGENCY CENTER', 'STREAMER • TOP-UP • COMBINED AGENCY', Icons.business_center),
      const SizedBox(height: 14),
      _portalCard('AGENCY APPLICATIONS', 'Application records below are loaded from the connected agency_applications table. Approval and official agency ID issuance remain Owner-authorized server operations.', Icons.assignment),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => _agencyApplicationInfo(context), icon: const Icon(Icons.add_business), label: const Text('START AGENCY APPLICATION')),
      const SizedBox(height: 14),
      if (loading) const Center(child: CircularProgressIndicator(color: _gold)),
      if (error != null) Text('Agency records could not be loaded: $error', style: const TextStyle(color: Color(0xFFE47777))),
      if (!loading && error == null && rows.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text('No agency application records returned.', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
      for (final row in rows)
        Card(color: _panel, child: ListTile(
          leading: const Icon(Icons.business, color: _gold),
          title: Text((row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Agency application').toString(), style: const TextStyle(color: Colors.white)),
          subtitle: Text(row.entries.take(4).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
        )),
      OutlinedButton.icon(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('REFRESH')),
    ]),
  );

  void _agencyApplicationInfo(BuildContext context) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Agency application', style: TextStyle(color: _gold)),
      content: const Text('Choose Streamer Agency, Top-up Agency or Both in the application flow. The secure submission endpoint and official ID issuance must be enabled in Supabase before this app can submit or approve an application. No local or sample application is created.', style: TextStyle(color: _muted, height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
    ));
  }
}

class _PortalSection {
  final String title;
  final IconData icon;
  const _PortalSection(this.title, this.icon);
}

Widget _portalHeader(String title, String subtitle, IconData icon) => Container(
  margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
  padding: const EdgeInsets.all(17),
  decoration: BoxDecoration(
    gradient: const LinearGradient(colors: [Color(0xFF293B49), _panel, _bg]),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _gold.withOpacity(.55)),
  ),
  child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: _gold.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _gold, size: 26)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .8)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
    ])),
    const Icon(Icons.verified, color: _teal),
  ]),
);

Widget _portalCard(String title, String body, IconData icon) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF354653))),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: _gold, size: 24),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(color: _muted, fontSize: 11, height: 1.45)),
    ])),
  ]),
);
).hasMatch(id)) {
      _notice('Enter a valid Admin ZOONL ID.');
      return;
    }
    setState(() => actionBusy = true);
    try {
      await Backend.client.rpc(
        'owner_set_admin_topup_permission',
        params: <String, dynamic>{
          'p_admin_zoonl_id': id,
          'p_allowed': allowTopups,
        },
      );
      _notice(allowTopups ? 'Top-up permission granted.' : 'Top-up permission revoked.');
      await _loadRecords();
    } catch (e) {
      _notice('Admin permission update failed: $e');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> _createAgency() async {
    final name = agencyName.text.trim();
    final code = agencyCode.text.trim().toUpperCase();
    final rate = double.tryParse(commission.text.trim());
    if (name.length < 3 || code.length < 4 || rate == null || rate < 0 || rate > 100) {
      _notice('Enter a valid agency name, code and commission from 0 to 100.');
      return;
    }
    setState(() => actionBusy = true);
    try {
      await Backend.client.rpc(
        'owner_create_agency',
        params: <String, dynamic>{
          'p_agency_name': name,
          'p_agency_code': code,
          'p_commission_percent': rate,
        },
      );
      agencyName.clear();
      agencyCode.clear();
      _notice('Agency created in Supabase.');
      await _loadRecords();
    } catch (e) {
      _notice('Agency creation failed: $e');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> _addCoins() async {
    final id = coinTargetId.text.trim();
    final amount = int.tryParse(coinAmount.text.trim());
    if (!RegExp(r'^[0-9]{5,12}
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records'),
        ),
      ),
      if (loading) const LinearProgressIndicator(color: _gold),
      if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text('Could not load $_table: $error', style: const TextStyle(color: Color(0xFFE47777)))),
      Expanded(
        child: filtered.isEmpty && !loading && error == null
            ? const Center(child: Text('No records returned by the connected database.', style: TextStyle(color: _muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final row = filtered[i];
                  final title = row['display_name'] ?? row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Database record';
                  return Card(
                    color: _panel,
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined, color: _gold),
                      title: Text(title.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(row.entries.take(5).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
                      trailing: const Icon(Icons.chevron_right, color: _gold),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: _panel,
                          title: Text(title.toString(), style: const TextStyle(color: _gold)),
                          content: SingleChildScrollView(child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('\n'), style: const TextStyle(color: _muted, fontSize: 12))),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(onPressed: loading ? null : _loadRecords, icon: const Icon(Icons.refresh), label: const Text('REFRESH DATABASE RECORDS')),
      ),
    ]);
  }
}

class AdminOperationsPortalScreen extends StatelessWidget {
  final Map<String, bool> permissions;
  const AdminOperationsPortalScreen({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final granted = permissions.entries.where((e) => e.value).toList();
    return Column(children: [
      _portalHeader('ADMIN OPERATIONS PORTAL', 'ONLY OWNER-GRANTED PERMISSIONS', Icons.admin_panel_settings),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _portalCard('YOUR ACCESS SCOPE', 'Only permissions confirmed by is_zoonl_admin_allowed() are shown. Missing permissions remain unavailable.', Icons.verified_user),
          const SizedBox(height: 12),
          for (final item in granted)
            Card(
              color: _panel,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _teal),
                title: Text(item.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Permission verified by Supabase', style: TextStyle(color: _muted, fontSize: 11)),
                trailing: const Icon(Icons.lock_open, color: _teal),
              ),
            ),
          const SizedBox(height: 12),
          _portalCard('SECURITY RULE', 'Admin cannot grant permissions, issue Owner identity, change owner settings or exceed the limits granted by the Owner.', Icons.shield),
        ],
      )),
    ]);
  }
}

class AgencyPortalScreen extends StatefulWidget {
  const AgencyPortalScreen({super.key});
  @override
  State<AgencyPortalScreen> createState() => _AgencyPortalScreenState();
}

class _AgencyPortalScreenState extends State<AgencyPortalScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Backend.fetchPortalRows('agency_applications');
      if (!mounted) return;
      setState(() { rows = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Agency & Creator Portal')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalHeader('OFFICIAL AGENCY CENTER', 'STREAMER • TOP-UP • COMBINED AGENCY', Icons.business_center),
      const SizedBox(height: 14),
      _portalCard('AGENCY APPLICATIONS', 'Application records below are loaded from the connected agency_applications table. Approval and official agency ID issuance remain Owner-authorized server operations.', Icons.assignment),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => _agencyApplicationInfo(context), icon: const Icon(Icons.add_business), label: const Text('START AGENCY APPLICATION')),
      const SizedBox(height: 14),
      if (loading) const Center(child: CircularProgressIndicator(color: _gold)),
      if (error != null) Text('Agency records could not be loaded: $error', style: const TextStyle(color: Color(0xFFE47777))),
      if (!loading && error == null && rows.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text('No agency application records returned.', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
      for (final row in rows)
        Card(color: _panel, child: ListTile(
          leading: const Icon(Icons.business, color: _gold),
          title: Text((row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Agency application').toString(), style: const TextStyle(color: Colors.white)),
          subtitle: Text(row.entries.take(4).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
        )),
      OutlinedButton.icon(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('REFRESH')),
    ]),
  );

  void _agencyApplicationInfo(BuildContext context) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Agency application', style: TextStyle(color: _gold)),
      content: const Text('Choose Streamer Agency, Top-up Agency or Both in the application flow. The secure submission endpoint and official ID issuance must be enabled in Supabase before this app can submit or approve an application. No local or sample application is created.', style: TextStyle(color: _muted, height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
    ));
  }
}

class _PortalSection {
  final String title;
  final IconData icon;
  const _PortalSection(this.title, this.icon);
}

Widget _portalHeader(String title, String subtitle, IconData icon) => Container(
  margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
  padding: const EdgeInsets.all(17),
  decoration: BoxDecoration(
    gradient: const LinearGradient(colors: [Color(0xFF293B49), _panel, _bg]),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _gold.withOpacity(.55)),
  ),
  child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: _gold.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _gold, size: 26)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .8)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
    ])),
    const Icon(Icons.verified, color: _teal),
  ]),
);

Widget _portalCard(String title, String body, IconData icon) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF354653))),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: _gold, size: 24),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(color: _muted, fontSize: 11, height: 1.45)),
    ])),
  ]),
);
).hasMatch(id) || amount == null || amount <= 0) {
      _notice('Enter a valid User ID and positive Coin amount.');
      return;
    }
    setState(() => actionBusy = true);
    try {
      await Backend.client.rpc(
        'add_zoonl_coins',
        params: <String, dynamic>{
          'p_zoonl_id': id,
          'p_amount': amount,
          'p_description': coinDescription.text.trim().isEmpty
              ? 'Owner portal Coin adjustment'
              : coinDescription.text.trim(),
        },
      );
      coinTargetId.clear();
      coinAmount.clear();
      coinDescription.clear();
      _notice('Coin adjustment completed by the secure Supabase ledger.');
      await _loadRecords();
    } catch (e) {
      _notice('Coin adjustment failed: $e');
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _actionPanel(String title, List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _gold.withOpacity(.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 9),
        ...children,
      ],
    ),
  );

  Widget _adminPermissionPanel() => _actionPanel('OWNER: ADMIN TOP-UP PERMISSION', [
    TextField(
      controller: adminId,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(labelText: 'Admin ZOONL ID'),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: allowTopups,
      onChanged: actionBusy ? null : (value) => setState(() => allowTopups = value),
      title: const Text('Allow Admin to manage top-ups', style: TextStyle(color: Colors.white, fontSize: 12)),
      activeColor: _teal,
    ),
    FilledButton(
      onPressed: actionBusy ? null : _setAdminTopupPermission,
      child: Text(actionBusy ? 'SAVING…' : 'SAVE PERMISSION'),
    ),
  ]);

  Widget _agencyCreatePanel() => _actionPanel('OWNER: CREATE AGENCY', [
    TextField(controller: agencyName, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Agency name')),
    const SizedBox(height: 8),
    TextField(controller: agencyCode, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Agency code')),
    const SizedBox(height: 8),
    TextField(controller: commission, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Commission %')),
    const SizedBox(height: 9),
    FilledButton(onPressed: actionBusy ? null : _createAgency, child: Text(actionBusy ? 'CREATING…' : 'CREATE AGENCY')),
  ]);

  Widget _coinAdjustmentPanel() => _actionPanel('OWNER / AUTHORIZED ADMIN: ADD COINS', [
    TextField(controller: coinTargetId, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Recipient ZOONL ID')),
    const SizedBox(height: 8),
    TextField(controller: coinAmount, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Coin amount')),
    const SizedBox(height: 8),
    TextField(controller: coinDescription, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description / receipt note')),
    const SizedBox(height: 9),
    FilledButton(onPressed: actionBusy ? null : _addCoins, child: Text(actionBusy ? 'PROCESSING…' : 'ADD COINS THROUGH LEDGER')),
  ]);

  Widget _records() {
    final filtered = records.where((row) => row.toString().toLowerCase().contains(search.text.toLowerCase())).toList();
    return Column(children: [
      if (selected == 1) _adminPermissionPanel(),
      if (selected == 2) _agencyCreatePanel(),
      if (selected == 5) _coinAdjustmentPanel(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records'),
        ),
      ),
      if (loading) const LinearProgressIndicator(color: _gold),
      if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text('Could not load $_table: $error', style: const TextStyle(color: Color(0xFFE47777)))),
      Expanded(
        child: filtered.isEmpty && !loading && error == null
            ? const Center(child: Text('No records returned by the connected database.', style: TextStyle(color: _muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final row = filtered[i];
                  final title = row['display_name'] ?? row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Database record';
                  return Card(
                    color: _panel,
                    child: ListTile(
                      leading: const Icon(Icons.storage_outlined, color: _gold),
                      title: Text(title.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(row.entries.take(5).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
                      trailing: const Icon(Icons.chevron_right, color: _gold),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: _panel,
                          title: Text(title.toString(), style: const TextStyle(color: _gold)),
                          content: SingleChildScrollView(child: Text(row.entries.map((e) => '${e.key}: ${e.value}').join('\n'), style: const TextStyle(color: _muted, fontSize: 12))),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: OutlinedButton.icon(onPressed: loading ? null : _loadRecords, icon: const Icon(Icons.refresh), label: const Text('REFRESH DATABASE RECORDS')),
      ),
    ]);
  }
}

class AdminOperationsPortalScreen extends StatelessWidget {
  final Map<String, bool> permissions;
  const AdminOperationsPortalScreen({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final granted = permissions.entries.where((e) => e.value).toList();
    return Column(children: [
      _portalHeader('ADMIN OPERATIONS PORTAL', 'ONLY OWNER-GRANTED PERMISSIONS', Icons.admin_panel_settings),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _portalCard('YOUR ACCESS SCOPE', 'Only permissions confirmed by is_zoonl_admin_allowed() are shown. Missing permissions remain unavailable.', Icons.verified_user),
          const SizedBox(height: 12),
          for (final item in granted)
            Card(
              color: _panel,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _teal),
                title: Text(item.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Permission verified by Supabase', style: TextStyle(color: _muted, fontSize: 11)),
                trailing: const Icon(Icons.lock_open, color: _teal),
              ),
            ),
          const SizedBox(height: 12),
          _portalCard('SECURITY RULE', 'Admin cannot grant permissions, issue Owner identity, change owner settings or exceed the limits granted by the Owner.', Icons.shield),
        ],
      )),
    ]);
  }
}

class AgencyPortalScreen extends StatefulWidget {
  const AgencyPortalScreen({super.key});
  @override
  State<AgencyPortalScreen> createState() => _AgencyPortalScreenState();
}

class _AgencyPortalScreenState extends State<AgencyPortalScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Backend.fetchPortalRows('agency_applications');
      if (!mounted) return;
      setState(() { rows = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Agency & Creator Portal')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalHeader('OFFICIAL AGENCY CENTER', 'STREAMER • TOP-UP • COMBINED AGENCY', Icons.business_center),
      const SizedBox(height: 14),
      _portalCard('AGENCY APPLICATIONS', 'Application records below are loaded from the connected agency_applications table. Approval and official agency ID issuance remain Owner-authorized server operations.', Icons.assignment),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: () => _agencyApplicationInfo(context), icon: const Icon(Icons.add_business), label: const Text('START AGENCY APPLICATION')),
      const SizedBox(height: 14),
      if (loading) const Center(child: CircularProgressIndicator(color: _gold)),
      if (error != null) Text('Agency records could not be loaded: $error', style: const TextStyle(color: Color(0xFFE47777))),
      if (!loading && error == null && rows.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text('No agency application records returned.', textAlign: TextAlign.center, style: TextStyle(color: _muted))),
      for (final row in rows)
        Card(color: _panel, child: ListTile(
          leading: const Icon(Icons.business, color: _gold),
          title: Text((row['agency_name'] ?? row['name'] ?? row['id'] ?? 'Agency application').toString(), style: const TextStyle(color: Colors.white)),
          subtitle: Text(row.entries.take(4).map((e) => '${e.key}: ${e.value}').join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
        )),
      OutlinedButton.icon(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('REFRESH')),
    ]),
  );

  void _agencyApplicationInfo(BuildContext context) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Agency application', style: TextStyle(color: _gold)),
      content: const Text('Choose Streamer Agency, Top-up Agency or Both in the application flow. The secure submission endpoint and official ID issuance must be enabled in Supabase before this app can submit or approve an application. No local or sample application is created.', style: TextStyle(color: _muted, height: 1.5)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
    ));
  }
}

class _PortalSection {
  final String title;
  final IconData icon;
  const _PortalSection(this.title, this.icon);
}

Widget _portalHeader(String title, String subtitle, IconData icon) => Container(
  margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
  padding: const EdgeInsets.all(17),
  decoration: BoxDecoration(
    gradient: const LinearGradient(colors: [Color(0xFF293B49), _panel, _bg]),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _gold.withOpacity(.55)),
  ),
  child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: _gold.withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _gold, size: 26)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .8)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
    ])),
    const Icon(Icons.verified, color: _teal),
  ]),
);

Widget _portalCard(String title, String body, IconData icon) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF354653))),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: _gold, size: 24),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(color: _muted, fontSize: 11, height: 1.45)),
    ])),
  ]),
);
