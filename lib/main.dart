import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZoonlLiveApp());
}

/// ZOONL LIVE Theme: Dark + Champagne Gold + Teal
class ZoonlTheme {
  static const Color bgDark = Color(0xFF07090F);
  static const Color bgPanel = Color(0xFF101522);
  static const Color bgCard = Color(0xFF171F30);
  static const Color gold = Color(0xFFE6C27A);
  static const Color goldBright = Color(0xFFFFE2A8);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealBright = Color(0xFF2DD4BF);
  static const Color crimson = Color(0xFFFF3355);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
}

class ZoonlSystemRules {
  /// 1★=10k, 2★=50k, 3★=200k, 4★=1M, 5★=2M
  static int starFromCoins(int coins) {
    if (coins >= 2000000) return 5;
    if (coins >= 1000000) return 4;
    if (coins >= 200000) return 3;
    if (coins >= 50000) return 2;
    return 1;
  }

  static int limitForStar(int star) {
    switch (star) {
      case 5:
        return 2000000;
      case 4:
        return 1000000;
      case 3:
        return 200000;
      case 2:
        return 50000;
      default:
        return 10000;
    }
  }

  static String badgeForLevel(int level) {
    if (level >= 25) return 'SUPREME CROWN BADGE';
    if (level >= 20) return 'ROYAL GOLD BADGE';
    if (level >= 15) return 'TEAL SOVEREIGN BADGE';
    if (level >= 10) return 'STAR GUARD BADGE';
    if (level >= 5) return 'RISING FLAME BADGE';
    return 'ROOKIE BADGE';
  }

  static Color stripColorForLevel(int level) {
    if (level >= 25) return const Color(0xFFD97706);
    if (level >= 20) return const Color(0xFFB45309);
    if (level >= 15) return const Color(0xFF0F766E);
    if (level >= 10) return const Color(0xFF1D4ED8);
    if (level >= 5) return const Color(0xFF047857);
    return const Color(0xFF334155);
  }
}

class OfficialAgencyEntry {
  final String officialId;
  final String agencyName;
  final String mobileNumber;
  final String agencyType; // 'Top-Up Agency', 'Streamer Agency', 'Top-Up + Streamer Both'
  int streamerCount;
  int topUpVolumeCoins;
  bool isOfficialVerified;

  OfficialAgencyEntry({
    required this.officialId,
    required this.agencyName,
    required this.mobileNumber,
    required this.agencyType,
    required this.streamerCount,
    required this.topUpVolumeCoins,
    this.isOfficialVerified = true,
  });
}

class StreamerProfileRecord {
  final String streamerId;
  final String name;
  final String joinMode; // 'Agency Linked' or 'Direct Self'
  final String agencyCodeOrNumber;
  int receivedGiftingCoins;
  int earningCoins;
  int validDaysCompleted; // Target: 20 days
  int totalHoursLogged; // Target: 80 hours (min 2h/day)
  int todayHoursLogged; // Min 2h/day required
  bool reward40Claimed;

  StreamerProfileRecord({
    required this.streamerId,
    required this.name,
    required this.joinMode,
    required this.agencyCodeOrNumber,
    required this.receivedGiftingCoins,
    required this.earningCoins,
    required this.validDaysCompleted,
    required this.totalHoursLogged,
    required this.todayHoursLogged,
    this.reward40Claimed = false,
  });

  bool get qualifiesFor40Reward =>
      validDaysCompleted >= 20 && totalHoursLogged >= 80 && todayHoursLogged >= 2;
}

class PayoutRequestItem {
  final String id;
  final String streamerId;
  final String streamerName;
  final String requestType; // 'Monthly Withdraw (1st-5th)' or 'Advance Request'
  final int coinsAmount;
  final String payoutLabel;
  String status; // 'Pending', 'Accepted & Sent', 'Rejected'

  PayoutRequestItem({
    required this.id,
    required this.streamerId,
    required this.streamerName,
    required this.requestType,
    required this.coinsAmount,
    required this.payoutLabel,
    this.status = 'Pending',
  });
}

class ZoonlLiveApp extends StatelessWidget {
  const ZoonlLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ZoonlTheme.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: ZoonlTheme.gold,
          secondary: ZoonlTheme.teal,
          surface: ZoonlTheme.bgPanel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ZoonlTheme.bgPanel,
          foregroundColor: ZoonlTheme.goldBright,
          elevation: 0,
        ),
      ),
      home: const ZoonlFullSystemScreen(),
    );
  }
}

class ZoonlFullSystemScreen extends StatefulWidget {
  const ZoonlFullSystemScreen({super.key});

  @override
  State<ZoonlFullSystemScreen> createState() => _ZoonlFullSystemScreenState();
}

class _ZoonlFullSystemScreenState extends State<ZoonlFullSystemScreen> {
  // 0 = Earning, $40 Reward & Withdraw/Advance
  // 1 = Official Agency Reg & Top-Up Under Agency
  // 2 = Streamer Reg (Agency Code vs Direct Self) & Streamer Records
  // 3 = Live, Star Limits, PK & Owner 10001
  int tabIndex = 0;

  // Owner & Current User State
  String currentUserId = '10001';
  String currentUserName = 'ZOONL OWNER';
  String roleMode = 'Owner (10001)'; // 'Owner (10001)', 'Admin', 'Agency', 'Streamer'
  int walletCoins = 500000;
  int totalSentCoins = 215000;
  int userLevel = 20;

  // Withdraw Window (1st - 5th) & Advance Settings
  bool forceFirstToFifthWindow = true;
  int streamerEarningCoins = 185000;
  int receivedGiftingCoins = 240000;
  double bonus40UsdBalance = 0.0;

  // Official Agencies (Top-Up Agency, Streamer Agency, or Both)
  String selectedAgencyType = 'Top-Up + Streamer Both';
  String activeTopUpAgencyId = 'AG-TOP-8801';
  String activeTopUpAgencyName = 'ZOONL OFFICIAL TOP-UP';
  String activeTopUpAgencyPhone = '+971501000101';

  final List<OfficialAgencyEntry> officialAgencies = [
    OfficialAgencyEntry(
      officialId: 'AG-TOP-8801',
      agencyName: 'ZOONL OFFICIAL TOP-UP',
      mobileNumber: '+971501000101',
      agencyType: 'Top-Up + Streamer Both',
      streamerCount: 18,
      topUpVolumeCoins: 1450000,
    ),
    OfficialAgencyEntry(
      officialId: 'AG-STR-9902',
      agencyName: 'TEAL STREAMER HUB',
      mobileNumber: '+971502000202',
      agencyType: 'Streamer Agency',
      streamerCount: 11,
      topUpVolumeCoins: 320000,
    ),
  ];

  // Streamer Registration (Agency Code vs Direct Self) & Records
  String streamerJoinMode = 'Agency Linked'; // 'Agency Linked' or 'Direct Self'
  int newValidDays = 20;
  int newTotalHours = 80;
  int newTodayHours = 2;

  final List<StreamerProfileRecord> streamerRecords = [
    StreamerProfileRecord(
      streamerId: '40101',
      name: 'Nadia Teal',
      joinMode: 'Agency Linked',
      agencyCodeOrNumber: 'AG-TOP-8801',
      receivedGiftingCoins: 240000,
      earningCoins: 185000,
      validDaysCompleted: 20,
      totalHoursLogged: 82,
      todayHoursLogged: 3,
      reward40Claimed: false,
    ),
    StreamerProfileRecord(
      streamerId: '40102',
      name: 'Direct Star',
      joinMode: 'Direct Self',
      agencyCodeOrNumber: 'DIRECT-SELF-APP',
      receivedGiftingCoins: 95000,
      earningCoins: 72000,
      validDaysCompleted: 14,
      totalHoursLogged: 54,
      todayHoursLogged: 2,
      reward40Claimed: false,
    ),
  ];

  // Withdraw & Advance Requests
  final List<PayoutRequestItem> payoutRequests = [
    PayoutRequestItem(
      id: 'WD-101',
      streamerId: '40101',
      streamerName: 'Nadia Teal',
      requestType: 'Advance Request',
      coinsAmount: 50000,
      payoutLabel: 'Gifting Record Verified (240,000 Coins)',
      status: 'Pending',
    ),
  ];

  // PK & Broad State
  int leftPkScore = 15200;
  int rightPkScore = 11800;
  String broadLine =
      'ZOONL LIVE: Official Agency Top-Up, Earning, \$40 Reward & Withdraw System Ready';

  // Controllers
  final TextEditingController agNameCtrl = TextEditingController();
  final TextEditingController agPhoneCtrl = TextEditingController();
  final TextEditingController agCustomIdCtrl = TextEditingController(text: 'AG-OFF-');
  final TextEditingController topUpAmtCtrl = TextEditingController(text: '50000');
  final TextEditingController stNameCtrl = TextEditingController();
  final TextEditingController stIdCtrl = TextEditingController(text: '40103');
  final TextEditingController stAgencyCodeCtrl =
      TextEditingController(text: 'AG-TOP-8801');
  final TextEditingController withdrawCoinsCtrl =
      TextEditingController(text: '40000');

  @override
  void dispose() {
    agNameCtrl.dispose();
    agPhoneCtrl.dispose();
    agCustomIdCtrl.dispose();
    topUpAmtCtrl.dispose();
    stNameCtrl.dispose();
    stIdCtrl.dispose();
    stAgencyCodeCtrl.dispose();
    withdrawCoinsCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZoonlTheme.bgCard,
        content: Text(msg, style: const TextStyle(color: ZoonlTheme.goldBright)),
      ),
    );
  }

  bool get isWithinWithdrawWindow {
    if (forceFirstToFifthWindow) return true;
    final day = DateTime.now().day;
    return day >= 1 && day <= 5;
  }

  void _registerOfficialAgency() {
    final name = agNameCtrl.text.trim();
    final phone = agPhoneCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Agency name likhein');
      return;
    }

    // Unique official ID generation (custom prefix/value + auto suffix if needed)
    var baseId = agCustomIdCtrl.text.trim();
    if (baseId.isEmpty || baseId == 'AG-OFF-') {
      baseId = 'AG-OFF-${1000 + officialAgencies.length * 137}';
    } else if (officialAgencies.any((a) => a.officialId == baseId)) {
      baseId = '${baseId}-${officialAgencies.length + 1}';
    }

    final created = OfficialAgencyEntry(
      officialId: baseId,
      agencyName: name,
      mobileNumber: phone.isEmpty ? '+971500000000' : phone,
      agencyType: selectedAgencyType,
      streamerCount: 0,
      topUpVolumeCoins: 0,
      isOfficialVerified: true,
    );

    setState(() {
      officialAgencies.insert(0, created);
      activeTopUpAgencyId = created.officialId;
      activeTopUpAgencyName = created.agencyName;
      activeTopUpAgencyPhone = created.mobileNumber;
      stAgencyCodeCtrl.text = created.officialId;
      broadLine =
          'OFFICIAL AGENCY REGISTERED: ${created.agencyName} • ID ${created.officialId} (${created.agencyType})';
      agNameCtrl.clear();
      agPhoneCtrl.clear();
    });
    _toast('Official Agency Created: ${created.officialId}');
  }

  void _executeTopUpUnderAgency() {
    final coins = int.tryParse(topUpAmtCtrl.text.trim()) ?? 0;
    if (coins <= 0) return;

    setState(() {
      walletCoins += coins;
      final ag = officialAgencies.firstWhere(
        (a) => a.officialId == activeTopUpAgencyId,
        orElse: () => officialAgencies.first,
      );
      ag.topUpVolumeCoins += coins;
      payoutRequests.insert(
        0,
        PayoutRequestItem(
          id: 'TU-${500 + payoutRequests.length + 1}',
          streamerId: currentUserId,
          streamerName: currentUserName,
          requestType: 'Top-Up Credit',
          coinsAmount: coins,
          payoutLabel:
              'Official Agency: ${ag.agencyName} • No: ${ag.officialId} • Ph: ${ag.mobileNumber}',
          status: 'Accepted & Sent',
        ),
      );
      broadLine =
          'TOP-UP RECORD: +$coins Coins via ${ag.agencyName} (Official ID: ${ag.officialId})';
    });
    _toast('Top-Up $coins Coins recorded under ${ag.officialId}');
  }

  void _registerStreamerWithMode() {
    final name = stNameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Streamer ka naam likhein');
      return;
    }
    final sid = stIdCtrl.text.trim().isEmpty
        ? '40${200 + streamerRecords.length}'
        : stIdCtrl.text.trim();
    final code = streamerJoinMode == 'Direct Self'
        ? 'DIRECT-SELF-APP'
        : (stAgencyCodeCtrl.text.trim().isEmpty
            ? activeTopUpAgencyId
            : stAgencyCodeCtrl.text.trim());

    setState(() {
      streamerRecords.insert(
        0,
        StreamerProfileRecord(
          streamerId: sid,
          name: name,
          joinMode: streamerJoinMode,
          agencyCodeOrNumber: code,
          receivedGiftingCoins: 60000,
          earningCoins: 45000,
          validDaysCompleted: newValidDays,
          totalHoursLogged: newTotalHours,
          todayHoursLogged: newTodayHours,
          reward40Claimed: false,
        ),
      );
      if (streamerJoinMode == 'Agency Linked') {
        for (final ag in officialAgencies) {
          if (ag.officialId == code) {
            ag.streamerCount++;
          }
        }
      }
      stNameCtrl.clear();
    });
    _toast('Streamer Registered ($streamerJoinMode • $code)');
  }

  void _submitWithdrawOrAdvance(bool isAdvance) {
    final amt = int.tryParse(withdrawCoinsCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;

    if (!isAdvance && !isWithinWithdrawWindow) {
      _toast('Monthly withdraw 1st se 5th tarikh tak open hota hai');
      return;
    }

    if (isAdvance && receivedGiftingCoins <= 0) {
      _toast('Advance ke liye gifting coin record zaroori hai');
      return;
    }

    if (streamerEarningCoins < amt) {
      _toast('Earning coins kam hain');
      return;
    }

    setState(() {
      streamerEarningCoins -= amt;
      payoutRequests.insert(
        0,
        PayoutRequestItem(
          id: isAdvance
              ? 'ADV-${300 + payoutRequests.length}'
              : 'WDR-${700 + payoutRequests.length}',
          streamerId: currentUserId,
          streamerName: currentUserName,
          requestType: isAdvance
              ? 'Advance Request'
              : 'Monthly Withdraw (1st–5th)',
          coinsAmount: amt,
          payoutLabel: isAdvance
              ? 'Gifting Record: $receivedGiftingCoins Coins'
              : 'Monthly Clear (1st–5th Window)',
          status: 'Pending',
        ),
      );
    });

    _toast(isAdvance
        ? 'Advance Request bhej di gayi (Gifting record attached)'
        : 'Withdraw Request bhej di gayi (1st–5th clear)');
  }

  void _decidePayoutRequest(PayoutRequestItem req, bool accept) {
    if (roleMode != 'Owner (10001)' && roleMode != 'Admin') {
      _toast('Sirf Owner 10001 ya Admin accept/send kar sakte hain');
      return;
    }
    setState(() {
      req.status = accept ? 'Accepted & Sent' : 'Rejected';
      if (!accept) {
        streamerEarningCoins += req.coinsAmount;
      }
    });
    _toast('${req.id}: ${req.status}');
  }

  void _claim40DollarReward(StreamerProfileRecord rec) {
    if (rec.reward40Claimed) {
      _toast('\$40 reward pehle hi claim ho chuka hai');
      return;
    }
    if (!rec.qualifiesFor40Reward) {
      _toast(
          'Shart: 20 valid days, 80 total hours aur aaj kam از کم 2 hours zaroori hain');
      return;
    }
    setState(() {
      rec.reward40Claimed = true;
      bonus40UsdBalance += 40.0;
    });
    _toast('\$40 New Streamer Reward approved for ${rec.name}!');
  }

  @override
  Widget build(BuildContext context) {
    final star = ZoonlSystemRules.starFromCoins(totalSentCoins);
    final starLimit = ZoonlSystemRules.limitForStar(star);

    final pages = [
      _earningRewardWithdrawTab(),
      _officialAgencyAndTopUpTab(),
      _streamerRegAndRecordsTab(),
      _liveStarPkAndOwnerTab(star, starLimit),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: ZoonlTheme.gold),
            const SizedBox(width: 8),
            const Text(
              'ZOONL LIVE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(width: 8),
            Text(
              '★$star',
              style: const TextStyle(
                  color: ZoonlTheme.tealBright, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$walletCoins C',
                style: const TextStyle(
                  color: ZoonlTheme.goldBright,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: ZoonlTheme.bgPanel,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Role: $roleMode • Earn: $streamerEarningCoins C • \$${bonus40UsdBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: ZoonlTheme.tealBright,
                      fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: roleMode,
                  isDense: true,
                  dropdownColor: ZoonlTheme.bgCard,
                  underline: const SizedBox(),
                  style:
                      const TextStyle(fontSize: 11, color: ZoonlTheme.goldBright),
                  items: const [
                    DropdownMenuItem(
                        value: 'Owner (10001)', child: Text('Owner (10001)')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'Agency', child: Text('Agency')),
                    DropdownMenuItem(value: 'Streamer', child: Text('Streamer')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => roleMode = v);
                  },
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: ZoonlTheme.bgCard,
            child: Text(
              broadLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ZoonlTheme.goldBright,
              ),
            ),
          ),
          Expanded(child: pages[tabIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (i) => setState(() => tabIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: ZoonlTheme.bgPanel,
        selectedItemColor: ZoonlTheme.gold,
        unselectedItemColor: ZoonlTheme.textMuted,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Earn/Wdr'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance), label: 'Agency/TopUp'),
          BottomNavigationBarItem(
              icon: Icon(Icons.badge), label: 'Streamers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.live_tv), label: 'Live/PK/10001'),
        ],
      ),
    );
  }

  /// TAB 0: Earning Section, $40 New Streamer Reward (80h / 20 valid days / 2h daily) & Withdraw / Advance (1st-5th)
  Widget _earningRewardWithdrawTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Earning & 1st-5th Withdraw / Advance Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZoonlTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZoonlTheme.gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EARNING • WITHDRAW (1st–5th) • ADVANCE REQUEST',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
              ),
              const SizedBox(height: 6),
              Text(
                'Earning Balance: $streamerEarningCoins Coins • Gifting Record: $receivedGiftingCoins Coins',
                style: const TextStyle(fontSize: 12, color: ZoonlTheme.tealBright),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable 1st–5th Withdraw Window (Test/Clear)'),
                value: forceFirstToFifthWindow,
                activeTrackColor: ZoonlTheme.teal,
                onChanged: (v) => setState(() => forceFirstToFifthWindow = v),
              ),
              TextField(
                controller: withdrawCoinsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Withdraw / Advance Coins Amount',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ZoonlTheme.gold,
                        foregroundColor: Colors.black),
                    onPressed: () => _submitWithdrawOrAdvance(false),
                    child: const Text('Monthly Withdraw (1st–5th)'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ZoonlTheme.teal,
                        foregroundColor: Colors.black),
                    onPressed: () => _submitWithdrawOrAdvance(true),
                    child: const Text('Advance Request'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Payout & Advance Records (Admin/Owner Accept & Send)
        const Text(
          'WITHDRAW & ADVANCE RECORDS (ACCEPT & SEND)',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
        ),
        ...payoutRequests.map((req) => Card(
              color: ZoonlTheme.bgCard,
              child: ListTile(
                title: Text(
                    '${req.id} • ${req.streamerName} (${req.requestType})'),
                subtitle: Text(
                    '${req.coinsAmount} Coins • ${req.payoutLabel} • ${req.status}'),
                trailing: req.status == 'Pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: ZoonlTheme.tealBright),
                            onPressed: () => _decidePayoutRequest(req, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: ZoonlTheme.crimson),
                            onPressed: () => _decidePayoutRequest(req, false),
                          ),
                        ],
                      )
                    : Text(
                        req.status,
                        style: const TextStyle(
                            color: ZoonlTheme.tealBright,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
              ),
            )),
      ],
    );
  }

  /// TAB 1: Official Agency Registration (Top-Up Agency / Streamer Agency / Both) + Top-Up Under Agency
  Widget _officialAgencyAndTopUpTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZoonlTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZoonlTheme.gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OFFICIAL AGENCY REGISTRATION (UNIQUE OFFICIAL ID)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
              ),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: selectedAgencyType,
                isExpanded: true,
                dropdownColor: ZoonlTheme.bgPanel,
                items: const [
                  DropdownMenuItem(
                      value: 'Top-Up + Streamer Both',
                      child: Text('Top-Up + Streamer Agency (Both)')),
                  DropdownMenuItem(
                      value: 'Top-Up Agency', child: Text('Top-Up Agency')),
                  DropdownMenuItem(
                      value: 'Streamer Agency',
                      child: Text('Streamer Agency')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selectedAgencyType = v);
                },
              ),
              TextField(
                controller: agNameCtrl,
                decoration: const InputDecoration(labelText: 'Agency Name'),
              ),
              TextField(
                controller: agPhoneCtrl,
                decoration:
                    const InputDecoration(labelText: 'Agency Mobile Number'),
              ),
              TextField(
                controller: agCustomIdCtrl,
                decoration: const InputDecoration(
                    labelText: 'Official Agency ID Number (Auto-Unique)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ZoonlTheme.gold,
                    foregroundColor: Colors.black),
                onPressed: _registerOfficialAgency,
                child: const Text('Register Official Agency'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Top-Up System Showing Official Agency Number & Name Below
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZoonlTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZoonlTheme.teal),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOP-UP SYSTEM (OFFICIAL AGENCY RECORD BELOW)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: ZoonlTheme.tealBright),
              ),
              TextField(
                controller: topUpAmtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Top-Up Coins'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ZoonlTheme.teal,
                    foregroundColor: Colors.black),
                onPressed: _executeTopUpUnderAgency,
                child: const Text('Execute Top-Up'),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZoonlTheme.bgPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZoonlTheme.gold),
                ),
                child: Text(
                  'OFFICIAL AGENCY • ID: $activeTopUpAgencyId • Name: $activeTopUpAgencyName • Ph: $activeTopUpAgencyPhone',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: ZoonlTheme.goldBright),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'ALL OFFICIAL AGENCY RECORDS',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
        ),
        ...officialAgencies.map((ag) => Card(
              color: ZoonlTheme.bgCard,
              child: ListTile(
                title: Text(
                    '${ag.agencyName} • Official ID: ${ag.officialId}'),
                subtitle: Text(
                    '${ag.agencyType} • Ph: ${ag.mobileNumber} • Streamers: ${ag.streamerCount} • TopUp: ${ag.topUpVolumeCoins}'),
                trailing: const Icon(Icons.verified, color: ZoonlTheme.tealBright),
              ),
            )),
      ],
    );
  }

  /// TAB 2: Streamer Registration (Agency Code vs Direct Self) + $40 Reward Tracker (80h / 20d / 2h/d) + Streamer Records
  Widget _streamerRegAndRecordsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZoonlTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZoonlTheme.gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STREAMER REGISTRATION (AGENCY CODE OR DIRECT SELF)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Agency Linked'),
                    selected: streamerJoinMode == 'Agency Linked',
                    selectedColor: ZoonlTheme.gold,
                    labelStyle: TextStyle(
                      color: streamerJoinMode == 'Agency Linked'
                          ? Colors.black
                          : ZoonlTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) =>
                        setState(() => streamerJoinMode = 'Agency Linked'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Direct Self'),
                    selected: streamerJoinMode == 'Direct Self',
                    selectedColor: ZoonlTheme.teal,
                    labelStyle: TextStyle(
                      color: streamerJoinMode == 'Direct Self'
                          ? Colors.black
                          : ZoonlTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) =>
                        setState(() => streamerJoinMode = 'Direct Self'),
                  ),
                ],
              ),
              TextField(
                controller: stNameCtrl,
                decoration: const InputDecoration(labelText: 'Streamer Name'),
              ),
              TextField(
                controller: stIdCtrl,
                decoration: const InputDecoration(labelText: 'Streamer ID'),
              ),
              if (streamerJoinMode == 'Agency Linked')
                TextField(
                  controller: stAgencyCodeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Agency Code / Official Number'),
                ),
              const SizedBox(height: 8),
              Text(
                'New Streamer \$40 Target: Valid Days $newValidDays/20 • Total Hours $newTotalHours/80 • Today $newTodayHours/2h min',
                style: const TextStyle(fontSize: 11, color: ZoonlTheme.tealBright),
              ),
              Slider(
                value: newValidDays.toDouble(),
                min: 1,
                max: 25,
                divisions: 24,
                activeColor: ZoonlTheme.gold,
                label: 'Valid Days: $newValidDays',
                onChanged: (v) => setState(() => newValidDays = v.round()),
              ),
              Slider(
                value: newTotalHours.toDouble(),
                min: 10,
                max: 120,
                divisions: 110,
                activeColor: ZoonlTheme.tealBright,
                label: 'Total Hours: $newTotalHours',
                onChanged: (v) => setState(() => newTotalHours = v.round()),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ZoonlTheme.gold,
                    foregroundColor: Colors.black),
                onPressed: _registerStreamerWithMode,
                child: const Text('Register Streamer'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'STREAMER RECORDS & \$40 NEW REWARD STATUS',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
        ),
        ...streamerRecords.map((st) => Card(
              color: ZoonlTheme.bgCard,
              child: ListTile(
                title: Text(
                    '${st.name} (ID ${st.streamerId}) • ${st.joinMode} (${st.agencyCodeOrNumber})'),
                subtitle: Text(
                    'Earn: ${st.earningCoins} • Gift: ${st.receivedGiftingCoins} • Days: ${st.validDaysCompleted}/20 • Hrs: ${st.totalHoursLogged}/80 (Today ${st.todayHoursLogged}h)'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: st.reward40Claimed
                        ? ZoonlTheme.bgPanel
                        : (st.qualifiesFor40Reward
                            ? ZoonlTheme.teal
                            : ZoonlTheme.gold),
                    foregroundColor:
                        st.reward40Claimed ? ZoonlTheme.textMuted : Colors.black,
                  ),
                  onPressed: () => _claim40DollarReward(st),
                  child: Text(
                    st.reward40Claimed
                        ? '\$40 Paid'
                        : (st.qualifiesFor40Reward ? 'Claim \$40' : '80h/20d'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  /// TAB 3: Live Star Limits (1..5), PK Punch & Owner 10001 Controls
  Widget _liveStarPkAndOwnerTab(int star, int starLimit) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ZoonlTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZoonlTheme.gold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAR TIER ★$star (Limit $starLimit) • Sent $totalSentCoins • ${ZoonlSystemRules.badgeForLevel(userLevel)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: ZoonlTheme.goldBright),
              ),
              const SizedBox(height: 8),
              Text('PK Score: Left $leftPkScore vs Right $rightPkScore'),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ZoonlTheme.gold,
                        foregroundColor: Colors.black),
                    onPressed: () => setState(() {
                      leftPkScore += 450;
                      rightPkScore = (rightPkScore - 150).clamp(0, 99999999);
                    }),
                    child: const Text('Left Punch'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ZoonlTheme.teal,
                        foregroundColor: Colors.black),
                    onPressed: () => setState(() {
                      rightPkScore += 450;
                      leftPkScore = (leftPkScore - 150).clamp(0, 99999999);
                    }),
                    child: const Text('Right Punch'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
