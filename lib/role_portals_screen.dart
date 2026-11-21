import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _PortalSection('Owner Settings', Icons.settings_outlined),
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
    'admin_audit_logs',
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
    super.dispose();
  }

  Future<void> _loadRecords() async {
    if (selected == 0) {
      setState(() { loading = false; error = null; records = []; });
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final rows = await Backend.fetchPortalRows(_table);
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
        ('Security & Audit', 'Administrative history', Icons.security),
        ('Owner Settings', 'Platform settings', Icons.settings),
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

  Future<void> _openAgencyReview(Map<String, dynamic> row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AgencyApplicationReviewScreen(application: row),
      ),
    );
    if (changed == true) _loadRecords();
  }

  Widget _records() {
    final filtered = records.where((row) => row.toString().toLowerCase().contains(search.text.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search records'),
        ),
      ),
      if (selected == 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AdminTopupLimitScreen()),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('SET ADMIN TOP-UP LIMITS'),
            ),
          ),
        ),
      if (selected == 5)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(builder: (_) => const CoinAdjustmentScreen()),
                );
                if (changed == true) _loadRecords();
              },
              icon: const Icon(Icons.add_card),
              label: const Text('ADD COINS BY ZOONL ID'),
            ),
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
                      trailing: selected == 2
                          ? IconButton(
                              tooltip: 'Review application',
                              onPressed: () => _openAgencyReview(row),
                              icon: const Icon(Icons.fact_check, color: _gold),
                            )
                          : const Icon(Icons.chevron_right, color: _gold),
                      onTap: selected == 2
                          ? () => _openAgencyReview(row)
                          : () => showDialog<void>(
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
          if (permissions['manage_topups'] == true)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CoinAdjustmentScreen()),
              ),
              icon: const Icon(Icons.add_card),
              label: const Text('ADD COINS BY ZOONL ID'),
            ),
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

class AdminTopupLimitScreen extends StatefulWidget {
  const AdminTopupLimitScreen({super.key});
  @override
  State<AdminTopupLimitScreen> createState() => _AdminTopupLimitScreenState();
}

class _AdminTopupLimitScreenState extends State<AdminTopupLimitScreen> {
  final TextEditingController _adminId = TextEditingController();
  final TextEditingController _perTransaction = TextEditingController(text: '180000');
  final TextEditingController _dailyLimit = TextEditingController(text: '360000');
  bool _busy = false;
  String? _adminName;
  String? _message;
  bool _success = false;

  Future<void> _save() async {
    final id = _adminId.text.trim();
    final perTx = int.tryParse(_perTransaction.text.trim());
    final daily = int.tryParse(_dailyLimit.text.trim());
    if (!RegExp(r'^[0-9]+$').hasMatch(id) || perTx == null || daily == null ||
        perTx <= 0 || daily < perTx) {
      setState(() { _success = false; _message = 'Enter a valid Admin ZOONL ID and limits. Daily limit must be at least the per-transaction limit.'; });
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final publicProfile = await Backend.client
          .from('user_public_profiles')
          .select('user_id,zoonl_id')
          .eq('zoonl_id', id)
          .maybeSingle();
      if (publicProfile == null) throw StateError('Admin ZOONL ID not found.');
      final profile = await Backend.client
          .from('profiles')
          .select('display_name')
          .eq('id', publicProfile['user_id'])
          .maybeSingle();
      final result = await Backend.client.rpc(
        'owner_set_admin_topup_limits',
        params: <String, dynamic>{
          'p_admin_user_id': publicProfile['user_id'],
          'p_max_coins_per_transaction': perTx,
          'p_daily_coin_limit': daily,
        },
      );
      if (mounted) {
        setState(() {
          _adminName = (profile?['display_name'] ?? 'ZOONL Admin').toString();
          _success = result == true;
          _message = _success
              ? 'Limits saved for $_adminName • $perTx coins per transaction • $daily coins per day.'
              : 'Limit update was not confirmed.';
        });
      }
    } catch (error) {
      if (mounted) setState(() { _success = false; _message = error.toString(); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _adminId.dispose();
    _perTransaction.dispose();
    _dailyLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Admin Top-up Limits')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalCard('OWNER-ONLY LIMIT CONTROL', 'The Owner sets both limits. Supabase enforces them for every Admin top-up and resets the daily counter by date.', Icons.shield),
      const SizedBox(height: 14),
      TextField(controller: _adminId, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Admin ZOONL ID')),
      TextField(controller: _perTransaction, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Maximum coins per transaction')),
      TextField(controller: _dailyLimit, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Maximum coins per day')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save), label: Text(_busy ? 'Saving...' : 'SAVE ADMIN LIMITS')),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_message!, style: TextStyle(color: _success ? _teal : const Color(0xFFE47777))),
        ),
    ]),
  );
}

class CoinAdjustmentScreen extends StatefulWidget {
  const CoinAdjustmentScreen({super.key});

  @override
  State<CoinAdjustmentScreen> createState() => _CoinAdjustmentScreenState();
}

class _CoinAdjustmentScreenState extends State<CoinAdjustmentScreen> {
  final TextEditingController _zoonlId = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  bool _checking = false;
  bool _submitting = false;
  String? _recipientName;
  String? _error;
  Map<String, dynamic>? _receipt;

  Future<void> _lookupRecipient() async {
    final id = _zoonlId.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      setState(() => _error = 'Enter a numeric ZOONL ID.');
      return;
    }
    setState(() { _checking = true; _error = null; _recipientName = null; });
    try {
      final publicProfile = await Backend.client
          .from('user_public_profiles')
          .select('user_id,zoonl_id')
          .eq('zoonl_id', id)
          .maybeSingle();
      if (publicProfile == null) throw StateError('ZOONL ID not found.');
      final profile = await Backend.client
          .from('profiles')
          .select('display_name')
          .eq('id', publicProfile['user_id'])
          .maybeSingle();
      if (!mounted) return;
      setState(() => _recipientName =
          (profile?['display_name'] ?? 'ZOONL User').toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    final id = _zoonlId.text.trim();
    final amount = int.tryParse(_amount.text.trim());
    if (_recipientName == null) {
      await _lookupRecipient();
      if (_recipientName == null) return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid coin amount.');
      return;
    }
    setState(() { _submitting = true; _error = null; _receipt = null; });
    try {
      final result = await Backend.client.rpc(
        'add_zoonl_coins',
        params: <String, dynamic>{
          'p_zoonl_id': id,
          'p_amount': amount,
          'p_description': _description.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() => _receipt = Map<String, dynamic>.from(result as Map));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _zoonlId.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Secure Coin Adjustment')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalCard('SERVER-VERIFIED TOP-UP', 'The server checks Owner status or the Owner-granted manage_topups permission. The client cannot choose a wallet UUID or write a balance directly.', Icons.lock),
      const SizedBox(height: 14),
      TextField(
        controller: _zoonlId,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Recipient ZOONL ID', suffixIcon: IconButton(onPressed: _checking ? null : _lookupRecipient, icon: const Icon(Icons.search))),
      ),
      if (_recipientName != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Recipient: $_recipientName • ID ${_zoonlId.text.trim()}',
              style: const TextStyle(color: _teal, fontWeight: FontWeight.w700)),
        ),
      TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Coins to add'),
      ),
      TextField(
        controller: _description,
        maxLength: 160,
        decoration: const InputDecoration(labelText: 'Receipt description / reference'),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFE47777))),
        ),
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: const Icon(Icons.check_circle),
        label: Text(_submitting ? 'Processing...' : 'CONFIRM COIN ADJUSTMENT'),
      ),
      if (_receipt != null)
        Card(
          color: _panel,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TOP-UP RECEIPT', style: TextStyle(color: _gold, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Recipient: $_recipientName', style: const TextStyle(color: Colors.white)),
              Text('ZOONL ID: ${_receipt!['zoonl_id']}', style: const TextStyle(color: Colors.white70)),
              Text('Coins added: ${_receipt!['coins_added']}', style: const TextStyle(color: Colors.white70)),
              Text('New balance: ${_receipt!['new_balance']}', style: const TextStyle(color: Colors.white70)),
              Text('Type: ${_receipt!['transaction_type']}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
    ]),
  );
}

class AgencyApplicationReviewScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  const AgencyApplicationReviewScreen({super.key, required this.application});

  @override
  State<AgencyApplicationReviewScreen> createState() => _AgencyApplicationReviewScreenState();
}

class _AgencyApplicationReviewScreenState extends State<AgencyApplicationReviewScreen> {
  final TextEditingController _note = TextEditingController();
  bool _busy = false;
  String? _receiptUrl;
  String? _message;
  String? _agencyCode;

  Map<String, dynamic> get app => widget.application;
  String get applicationId => app['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final path = app['deposit_receipt_path']?.toString();
    if (path == null || path.isEmpty) return;
    try {
      final url = await Backend.client.storage
          .from('agency-documents-private')
          .createSignedUrl(path, 3600);
      if (mounted) setState(() => _receiptUrl = url);
    } catch (error) {
      if (mounted) setState(() => _message = 'Receipt preview unavailable: $error');
    }
  }

  Future<void> _setDeposit(String status) async {
    setState(() { _busy = true; _message = null; });
    try {
      await Backend.client.rpc(
        'owner_set_agency_deposit_status',
        params: <String, dynamic>{
          'p_application_id': applicationId,
          'p_deposit_status': status,
          'p_review_note': _note.text.trim(),
        },
      );
      if (mounted) setState(() => _message = 'Deposit status set to $status.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(String decision) async {
    setState(() { _busy = true; _message = null; });
    try {
      final result = await Backend.client.rpc(
        'owner_review_agency_application',
        params: <String, dynamic>{
          'p_application_id': applicationId,
          'p_decision': decision,
          'p_review_note': _note.text.trim(),
        },
      );
      if (mounted) {
        setState(() {
          _agencyCode = result is Map ? result['agency_code']?.toString() : null;
          _message = decision == 'approved'
              ? 'Agency approved. Official code: ${_agencyCode ?? 'pending'}'
              : 'Application rejected.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depositStatus = (app['deposit_status'] ?? 'pending').toString();
    final applicationStatus = (app['application_status'] ?? 'pending').toString();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Review Agency Application')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _portalCard(
          (app['proposed_name'] ?? 'Agency').toString(),
          'Type: ${app['agency_type']} • Deposit: USD ${app['deposit_amount']} • Application: $applicationStatus • Deposit status: $depositStatus',
          Icons.business,
        ),
        const SizedBox(height: 10),
        Text('Contact: ${app['contact_details']}', style: const TextStyle(color: _muted)),
        Text('Deposit reference: ${app['deposit_reference'] ?? 'Not supplied'}',
            style: const TextStyle(color: _muted)),
        if (_receiptUrl != null) ...[
          const SizedBox(height: 12),
          const Text('Private deposit receipt', style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(_receiptUrl!, height: 220, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('Receipt preview could not be rendered.', style: TextStyle(color: _muted))),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Owner review note'),
        ),
        const SizedBox(height: 12),
        if (applicationStatus == 'pending') ...[
          if (depositStatus == 'pending')
            FilledButton(
              onPressed: _busy ? null : () => _setDeposit('verified'),
              child: const Text('VERIFY USD 300 DEPOSIT'),
            ),
          if (depositStatus != 'rejected')
            OutlinedButton(
              onPressed: _busy ? null : () => _setDeposit('rejected'),
              child: const Text('REJECT DEPOSIT RECEIPT'),
            ),
          if (depositStatus == 'verified')
            FilledButton(
              onPressed: _busy ? null : () => _review('approved'),
              child: const Text('APPROVE & ISSUE AGENCY CODE'),
            ),
          OutlinedButton(
            onPressed: _busy ? null : () => _review('rejected'),
            child: const Text('REJECT APPLICATION'),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_message!, style: const TextStyle(color: _teal)),
          ),
        if (_busy) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(color: _gold)),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('BACK TO AGENCY RECORDS'),
        ),
      ]),
    );
  }
}

class AgencyApplicationFormScreen extends StatefulWidget {
  const AgencyApplicationFormScreen({super.key});
  @override
  State<AgencyApplicationFormScreen> createState() => _AgencyApplicationFormScreenState();
}

class _AgencyApplicationFormScreenState extends State<AgencyApplicationFormScreen> {
  final SupabaseClient _db = Backend.client;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _depositReference = TextEditingController();
  String _agencyType = 'streamer';
  XFile? _receipt;
  bool _uploading = false;
  bool _submitting = false;
  String? _receiptPath;
  String? _error;

  Future<void> _pickReceipt() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null) return;
      setState(() { _receipt = file; _receiptPath = null; _error = null; });
    } catch (error) {
      setState(() => _error = 'Receipt image could not be selected: $error');
    }
  }

  Future<void> _uploadReceipt() async {
    final file = _receipt;
    final userId = _db.auth.currentUser?.id;
    if (file == null || userId == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final path = '$userId/agency-receipts/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _db.storage.from('agency-documents-private').upload(
        path,
        File(file.path),
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
      if (mounted) setState(() => _receiptPath = path);
    } catch (error) {
      if (mounted) setState(() => _error = 'Receipt upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _depositReference.text.trim().isEmpty ||
        _receiptPath == null) {
      setState(() => _error = 'Complete the contact details and upload the $300 deposit receipt.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await _db.rpc(
        'submit_agency_application',
        params: <String, dynamic>{
          'p_proposed_name': _name.text.trim(),
          'p_agency_type': _agencyType,
          'p_contact_details': <String, dynamic>{
            'email': _email.text.trim(),
            'phone': _phone.text.trim(),
          },
          'p_deposit_reference': _depositReference.text.trim(),
          'p_deposit_receipt_path': _receiptPath,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency application submitted for Owner review.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _depositReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(title: const Text('Agency Application')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _portalCard('AGENCY DEPOSIT', 'Required deposit: USD 300. Upload the receipt for manual verification. This form does not charge a card or process a payment.', Icons.receipt_long),
      const SizedBox(height: 12),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Proposed agency name')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _agencyType,
        decoration: const InputDecoration(labelText: 'Agency type'),
        items: const [
          DropdownMenuItem(value: 'streamer', child: Text('Streamer Agency')),
          DropdownMenuItem(value: 'topup', child: Text('Top-up Agency')),
          DropdownMenuItem(value: 'both', child: Text('Both')),
        ],
        onChanged: (value) => setState(() => _agencyType = value ?? 'streamer'),
      ),
      const SizedBox(height: 8),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Contact email')),
      const SizedBox(height: 8),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Contact phone / WhatsApp')),
      const SizedBox(height: 8),
      TextField(controller: _depositReference,
        decoration: const InputDecoration(labelText: 'Deposit reference')),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _uploading ? null : _pickReceipt,
        icon: const Icon(Icons.image),
        label: Text(_receipt == null ? 'SELECT DEPOSIT RECEIPT' : 'RECEIPT SELECTED'),
      ),
      if (_receipt != null)
        Text(_receiptPath == null ? 'Selected: ${_receipt!.name}' : 'Receipt securely uploaded.',
          style: const TextStyle(color: _teal, fontSize: 11)),
      if (_receipt != null && _receiptPath == null)
        FilledButton(
          onPressed: _uploading ? null : _uploadReceipt,
          child: Text(_uploading ? 'Uploading...' : 'UPLOAD RECEIPT SECURELY'),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_error!, style: const TextStyle(color: Color(0xFFE47777))),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _submitting || _uploading ? null : _submit,
        icon: const Icon(Icons.send),
        label: Text(_submitting ? 'Submitting...' : 'SUBMIT FOR OWNER REVIEW'),
      ),
    ]),
  );
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
      FilledButton.icon(
        onPressed: _openAgencyApplication,
        icon: const Icon(Icons.add_business),
        label: const Text('START AGENCY APPLICATION'),
      ),
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

  Future<void> _openAgencyApplication() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AgencyApplicationFormScreen()),
    );
    if (submitted == true) await _load();
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
