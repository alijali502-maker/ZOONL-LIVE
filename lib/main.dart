import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ZoonlApp());
}

class ZoonlApp extends StatelessWidget {
  const ZoonlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070510),
        primaryColor: const Color(0xFF7C4DFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFFE6C47A),
          surface: Color(0xFF120D24),
        ),
        useMaterial3: true,
      ),
      home: const ZoonlMainShell(),
    );
  }
}

/// Central reactive state & business logic for ZOONL LIVE
class ZoonlStore extends ChangeNotifier {
  static final ZoonlStore instance = ZoonlStore._internal();
  ZoonlStore._internal() {
    _initDefaults();
    _startGlobalTicker();
  }

  // Owner identity locked to 10001
  static const String ownerId = '10001';

  Map<String, dynamic> currentUser = <String, dynamic>{
    'id': '10001',
    'name': 'ZOONL Sovereign Owner',
    'isOwner': true,
    'isVerifiedStreamer': true,
    'streamerId': 'ST-10001',
    'level': 100,
    'sentCoins': 50000000,
    'coins': 999999999, // Unlimited for Owner 10001
    'diamonds': 0,
    'walletBalance': 0.0,
    'vipTier': 'SVIP',
    'isNewId': false,
    'trialExpiresAt': null,
    'friendListPublic': true,
    'linkedAccounts': <String>['Email Auth', 'Phone SMS', 'Google', 'Device Key'],
    'payoutLocked': true,
    'payoutMethod': 'Official Owner Vault',
    'payoutAccount': 'OWNER-10001-VAULT',
    'registrationType': 'OWNER',
    'approved': true,
    'isLive': false,
    'offlineSince': null,
  };

  // Owner-only Permanent Ban / Fraud Block registry (hidden from all non-owners)
  final Set<String> _ownerPermanentBannedIds = <String>{};
  final Map<String, String> _ownerBanReasons = <String, String>{};

  // Admin coin limits set by Owner 10001
  final Map<String, Map<String, dynamic>> adminAccounts = <String, Map<String, dynamic>>{
    'ADM-201': <String, dynamic>{
      'id': 'ADM-201',
      'name': 'Elite Admin Tara',
      'coinLimit': 500000,
      'coinsUsed': 120000,
      'stopped': false,
    },
  };

  // Official hosting & support settings editable by Owner 10001
  String officialHostingEmail = 'hosting@zoonllive.com';
  String officialHostingContact = '+971-50-000-10001';
  String supportEmail = 'support@zoonllive.com';
  String supportContact = '+971-50-111-10001';

  // Owner Frame Backup & Reward Library
  final List> ownerRewardLibrary = >[
    <String, dynamic>{'id': 'r1', 'type': 'Frame', 'name': 'Sovereign Gold Crown Frame', 'rarity': 'Mythic'},
    <String, dynamic>{'id': 'r2', 'type': 'Entry', 'name': 'Phantom Dragon Sovereign Entry', 'rarity': 'Mythic'},
    <String, dynamic>{'id': 'r3', 'type': 'Background', 'name': 'Royal Eclipse Back-Aura', 'rarity': 'VIP'},
    <String, dynamic>{'id': 'r4', 'type': 'Frame', 'name': 'Crimson Phoenix Frame', 'rarity': 'Legendary'},
    <String, dynamic>{'id': 'r5', 'type': 'Entry', 'name': 'Golden Meteor Arrival', 'rarity': 'Legendary'},
  ];

  // User / Streamer Backup Store
  final List> backupStore = >[
    <String, dynamic>{'id': 'b1', 'type': 'Frame', 'name': 'Owner Sovereign Frame', 'equipped': true, 'fromTrial': false},
    <String, dynamic>{'id': 'b2', 'type': 'Entry', 'name': 'Sovereign Gate Entry', 'equipped': true, 'fromTrial': false},
    <String, dynamic>{'id': 'b3', 'type': 'Background', 'name': 'Royal Eclipse Back-Aura', 'equipped': true, 'fromTrial': false},
  ];

  // Streamers & Live Rooms
  final List> streamers = >[];
  final List> shortVideos = >[];
  final List> privateRooms = >[];
  final List> inboxMessages = >[];
  final List> friendsList = >[];
  final List> adminAssignedStreamers = >[];

  // Global 5+ second non-intrusive gift ticker queue
  final List> _giftTickerQueue = >[];
  Map<String, dynamic>? activeGlobalGiftBanner;
  Timer? _tickerTimer;

  // Pending 5-day new ID welcome concert popup
  Map<String, dynamic>? pendingNewIdWelcome;

  void _initDefaults() {
    streamers.addAll(>[
      <String, dynamic>{
        'id': 'STR-101',
        'userId': '88412',
        'name': 'Zara Queen',
        'verified': true,
        'isLive': true,
        'offlineSince': null,
        'mode': 'VIDEO',
        'sentCoins': 4650000,
        'receivedCoins': 1850000,
        'dailyReceiving': 420000,
        'isAdminForMe': true,
        'inMyFriends': true,
        'videoCallOpen': true,
        'guestCallMode': 'VIDEO',
        'guestName': 'Guest Leo',
        'guestMutedAudio': false,
        'guestMutedVideo': false,
        'pkMode': '6P',
        'blacklist': <String>[],
        'roomAdmins': <String>['90012'],
        'mutedUsers': <String>[],
        'giftersHistory': >[
          <String, dynamic>{'userId': '77101', 'name': 'Rohan', 'coins': 2400000, 'period': 'MONTHLY'},
          <String, dynamic>{'userId': '77102', 'name': 'Tariq', 'coins': 950000, 'period': 'WEEKLY'},
          <String, dynamic>{'userId': '77103', 'name': 'Hamza', 'coins': 260000, 'period': 'DAILY'},
          <String, dynamic>{'userId': '77104', 'name': 'Bilal', 'coins': 65000, 'period': 'DAILY'},
          <String, dynamic>{'userId': '77105', 'name': 'Usman', 'coins': 15000, 'period': 'DAILY'},
        ],
      },
      <String, dynamic>{
        'id': 'STR-102',
        'userId': '88419',
        'name': 'Maya Melody',
        'verified': true,
        'isLive': true,
        'offlineSince': null,
        'mode': 'AUDIO',
        'seatCount': 8,
        'plusOpen': true,
        'callRequestOpen': true,
        'pendingCallRequests': >[
          <String, dynamic>{'userId': '55210', 'name': 'Ayan', 'type': 'CALL'},
        ],
        'seats': List>.generate(8, (int i) {
          return <String, dynamic>{
            'seat': i + 1,
            'occupied': i == 0,
            'userId': i == 0 ? '88419' : '',
            'name': i == 0 ? 'Maya Melody' : 'Empty',
            'muted': false,
          };
        }),
        'sentCoins': 1250000,
        'receivedCoins': 920000,
        'dailyReceiving': 210000,
        'isAdminForMe': true,
        'inMyFriends': false,
        'blacklist': <String>[],
        'roomAdmins': <String>[],
        'mutedUsers': <String>[],
        'giftersHistory': >[],
      },
      <String, dynamic>{
        'id': 'STR-103',
        'userId': '88450',
        'name': 'Noor Star',
        'verified': true,
        'isLive': false,
        'offlineSince': DateTime.now().subtract(const Duration(minutes: 24)),
        'mode': 'VIDEO',
        'sentCoins': 850000,
        'receivedCoins': 640000,
        'dailyReceiving': 0,
        'isAdminForMe': false,
        'inMyFriends': true,
        'blacklist': <String>[],
        'roomAdmins': <String>[],
        'mutedUsers': <String>[],
        'giftersHistory': >[],
      },
    ]);

    shortVideos.addAll(>[
      <String, dynamic>{
        'id': 'SV-1',
        'author': 'Zara Queen',
        'authorId': '88412',
        'caption': 'Royal Night Vibes ✨ #ZOONL',
        'filter': 'VIP Velvet Glow',
        'likes': 1420,
      },
      <String, dynamic>{
        'id': 'SV-2',
        'author': 'Maya Melody',
        'authorId': '88419',
        'caption': 'Live Audio & PK Tonight 🎧',
        'filter': 'Golden Rose LUT',
        'likes': 980,
      },
    ]);

    friendsList.addAll(>[
      <String, dynamic>{'id': '88412', 'name': 'Zara Queen', 'isLive': true},
      <String, dynamic>{'id': '88450', 'name': 'Noor Star', 'isLive': false},
      <String, dynamic>{'id': '66310', 'name': 'Danish', 'isLive': true},
    ]);

    adminAssignedStreamers.addAll(>[
      <String, dynamic>{'id': '88412', 'name': 'Zara Queen', 'isLive': true},
      <String, dynamic>{'id': '88419', 'name': 'Maya Melody', 'isLive': true},
    ]);

    inboxMessages.addAll(>[
      <String, dynamic>{
        'from': 'Zara Queen',
        'fromId': '88412',
        'text': 'Welcome to ZOONL LIVE!',
        'privateKey': null,
        'roomId': null,
      },
    ]);
  }

  void _startGlobalTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_giftTickerQueue.isNotEmpty) {
        activeGlobalGiftBanner = _giftTickerQueue.removeAt(0);
      } else {
        activeGlobalGiftBanner = null;
      }
      notifyListeners();
    });
  }

  /// Owner 10001 Permanent Ban / Fraud Block (hidden from everyone else, immutable by non-owners)
  bool isPermanentlyBannedByOwner(String targetId) {
    return _ownerPermanentBannedIds.contains(targetId);
  }

  void ownerPermanentBan(String targetId, {String reason = 'Rule violation / Fraud'}) {
    if (currentUser['id'] != ownerId) return; // Strict Owner 10001 lock
    if (targetId == ownerId) return;
    _ownerPermanentBannedIds.add(targetId);
    _ownerBanReasons[targetId] = reason;
    streamers.removeWhere((Map<String, dynamic> s) => s['userId'] == targetId || s['id'] == targetId);
    notifyListeners();
  }

  /// New ID / First-Login 5-Day Trial (Frame, Entry, SVIP, Background) + Auto Backup on Expiry
  void registerNewIdWithTrial({
    required String newId,
    required String name,
    required bool asStreamer,
  }) {
    if (isPermanentlyBannedByOwner(newId)) return;
    final DateTime expiry = DateTime.now().add(const Duration(days: 5));
    final String autoStreamerCode = asStreamer ? 'ST-${Random().nextInt(89999) + 10000}' : '';

    currentUser = <String, dynamic>{
      'id': newId,
      'name': name,
      'isOwner': newId == ownerId,
      'isVerifiedStreamer': asStreamer,
      'streamerId': autoStreamerCode,
      'level': 1,
      'sentCoins': 0,
      'coins': 5000,
      'diamonds': 0,
      'walletBalance': 0.0,
      'vipTier': 'SVIP',
      'isNewId': true,
      'trialExpiresAt': expiry.toIso8601String(),
      'friendListPublic': true,
      'linkedAccounts': <String>['Email Auth'],
      'payoutLocked': false,
      'payoutMethod': '',
      'payoutAccount': '',
      'registrationType': asStreamer ? 'DIRECT' : 'USER',
      'approved': !asStreamer,
      'isLive': false,
      'offlineSince': null,
    };

    // Add 5-day trial items into Backup Store
    backupStore.addAll(>[
      <String, dynamic>{
        'id': 'trial_frame_$newId',
        'type': 'Frame',
        'name': 'Welcome 5D Royal Frame',
        'equipped': true,
        'fromTrial': true,
        'expiresAt': expiry.toIso8601String(),
      },
      <String, dynamic>{
        'id': 'trial_entry_$newId',
        'type': 'Entry',
        'name': 'Welcome 5D Grand Entry',
        'equipped': true,
        'fromTrial': true,
        'expiresAt': expiry.toIso8601String(),
      },
      <String, dynamic>{
        'id': 'trial_bg_$newId',
        'type': 'Background',
        'name': 'Welcome 5D VIP Back-Aura',
        'equipped': true,
        'fromTrial': true,
        'expiresAt': expiry.toIso8601String(),
      },
    ]);

    pendingNewIdWelcome = <String, dynamic>{
      'title': 'ZOONL LIVE Welcome Concert Gift',
      'subtitle': 'Application ki taraf se aapko 5 din ke liye Frame, Entry, SVIP aur Background mil gaya hai!',
      'items': <String>['5D Frame', '5D Special Entry', '5D SVIP', '5D Background Aura'],
    };
    notifyListeners();
  }

  void checkTrialExpiryAndMoveToBackup() {
    final String? expStr = currentUser['trialExpiresAt'] as String?;
    if (expStr == null) return;
    final DateTime? expiry = DateTime.tryParse(expStr);
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      currentUser['vipTier'] = 'NONE';
      for (final Map<String, dynamic> item in backupStore) {
        if (item['fromTrial'] == true) {
          item['equipped'] = false;
          item['expiredToBackup'] = true;
        }
      }
      notifyListeners();
    }
  }

  /// Level 1..100 progression with requested coin gaps
  int resolveUserLevel(int sentCoins) {
    const List<int> thresholds = <int>[
      0,        // L1
      50000,    // L2
      100000,   // L3
      160000,   // L4
      230000,   // L5
      310000,   // L6
      400000,   // L7
      500000,   // L8
      620000,   // L9
      750000,   // L10
      1000000,  // L11 (+250k)
      1300000,  // L12 (+300k)
      1600000,  // L13 (+300k)
      1900000,  // L14 (+300k)
      2200000,  // L15 (+300k)
      2700000,  // L16 (+500k)
      3200000,  // L17 (+500k)
      3700000,  // L18 (+500k)
      4200000,  // L19 (+500k)
      4700000,  // L20 (+500k)
    ];
    if (sentCoins <= thresholds[0]) return 1;
    for (int i = 1; i < thresholds.length; i++) {
      if (sentCoins < thresholds[i]) return i;
    }
    int lvl = 20;
    int acc = thresholds.last;
    while (lvl < 100 && sentCoins >= acc) {
      final int step = lvl < 50 ? 1500000 : 3500000;
      acc += step;
      if (sentCoins >= acc) lvl++;
    }
    return min(100, lvl);
  }

  /// Color Star System: 10k -> 1, 50k -> 2, 200k -> 3, 1M -> 4, 2M -> 5 (Big Star)
  Map<String, dynamic> resolveColorStar(int sentCoins) {
    if (sentCoins >= 2000000) {
      return <String, dynamic>{'stars': 5, 'label': 'BIG STAR ★', 'color': const Color(0xFFFF2E93)};
    } else if (sentCoins >= 1000000) {
      return <String, dynamic>{'stars': 4, 'label': '4 STAR', 'color': const Color(0xFFFF9100)};
    } else if (sentCoins >= 200000) {
      return <String, dynamic>{'stars': 3, 'label': '3 STAR', 'color': const Color(0xFF00E5FF)};
    } else if (sentCoins >= 50000) {
      return <String, dynamic>{'stars': 2, 'label': '2 STAR', 'color': const Color(0xFF7C4DFF)};
    } else if (sentCoins >= 10000) {
      return <String, dynamic>{'stars': 1, 'label': '1 STAR', 'color': const Color(0xFFFFD54F)};
    }
    return <String, dynamic>{'stars': 0, 'label': 'NO STAR', 'color': Colors.white38};
  }

  /// Auto-replacing Demon -> Crown (up to 40 Crown limit)
  Map<String, dynamic> resolveStreamerCrownOrDemon(int sentCoins) {
    if (sentCoins < 30000) {
      return <String, dynamic>{'kind': 'HEART', 'count': 1, 'title': 'Mini Heart', 'color': const Color(0xFFFF5C8A)};
    } else if (sentCoins < 150000) {
      final int d = sentCoins < 80000 ? 1 : 2;
      return <String, dynamic>{'kind': 'DEMON', 'count': d, 'title': '$d Demon', 'color': const Color(0xFFFF3D57)};
    } else {
      // Auto-replaces Demon with Crown 1..40
      int crown = 1;
      if (sentCoins >= 45000000) {
        crown = 40;
      } else if (sentCoins >= 35000000) {
        crown = 32;
      } else if (sentCoins >= 20000000) {
        crown = 24;
      } else if (sentCoins >= 10000000) {
        crown = 16;
      } else if (sentCoins >= 5000000) {
        crown = 10;
      } else if (sentCoins >= 2500000) {
        crown = 6;
      } else if (sentCoins >= 1000000) {
        crown = 3;
      } else if (sentCoins >= 500000) {
        crown = 2;
      }
      crown = min(40, crown);
      return <String, dynamic>{
        'kind': 'CROWN',
        'count': crown,
        'title': '$crown Crown',
        'color': const Color(0xFFFFD700),
      };
    }
  }

  /// Send Gift + 65% Streamer Wallet Conversion + Global 5s Patti
  void sendGift({
    required Map<String, dynamic> streamer,
    required String giftName,
    required int giftCoins,
  }) {
    final String senderId = currentUser['id'] as String;
    if (isPermanentlyBannedByOwner(senderId)) return;

    if (currentUser['id'] != ownerId) {
      final int bal = (currentUser['coins'] as int?) ?? 0;
      if (bal < giftCoins) return;
      currentUser['coins'] = bal - giftCoins;
    }

    currentUser['sentCoins'] = ((currentUser['sentCoins'] as int?) ?? 0) + giftCoins;
    currentUser['level'] = resolveUserLevel(currentUser['sentCoins'] as int);

    streamer['receivedCoins'] = ((streamer['receivedCoins'] as int?) ?? 0) + giftCoins;
    streamer['dailyReceiving'] = ((streamer['dailyReceiving'] as int?) ?? 0) + giftCoins;

    // 65% conversion into Streamer Wallet balance
    final double payoutGain = (giftCoins * 0.65) / 100.0;
    streamer['walletBalance'] = ((streamer['walletBalance'] as double?) ?? 0.0) + payoutGain;

    final Map<String, dynamic> crownInfo = resolveStreamerCrownOrDemon(streamer['receivedCoins'] as int);
    final Map<String, dynamic> banner = <String, dynamic>{
      'senderName': currentUser['name'],
      'senderLevel': currentUser['level'],
      'giftName': giftName,
      'streamerName': streamer['name'],
      'streamerCrown': crownInfo['title'],
      'crownColor': crownInfo['color'],
    };

    if (activeGlobalGiftBanner == null) {
      activeGlobalGiftBanner = banner;
    } else {
      _giftTickerQueue.add(banner);
    }
    notifyListeners();
  }

  /// Live start rule: Verified Streamer from Level 1; Normal User requires Level 5
  bool canStartLive() {
    if (currentUser['id'] == ownerId) return true;
    if (currentUser['isVerifiedStreamer'] == true) return true;
    return ((currentUser['level'] as int?) ?? 1) >= 5;
  }

  void toggleLiveStatus({required bool goLive, String mode = 'VIDEO'}) {
    if (goLive && !canStartLive()) return;
    currentUser['isLive'] = goLive;
    currentUser['offlineSince'] = goLive ? null : DateTime.now();
    notifyListeners();
  }

  /// Moderation rules:
  /// - Streamer: unlimited Mute/Unmute/Blacklist/Boot
  /// - Streamer-appointed Admin: can Mute ONLY if Admin has VIP or SVIP; CANNOT Blacklist
  void moderateUser({
    required Map<String, dynamic> streamer,
    required String targetUserId,
    required String action, // MUTE, UNMUTE, BLACKLIST, BOOT
    required bool actorIsStreamer,
    required bool actorIsAdmin,
    required String actorVipTier,
  }) {
    final List<String> muted = List<String>.from((streamer['mutedUsers'] as List<dynamic>?) ?? <dynamic>[]);
    final List<String> blacklist = List<String>.from((streamer['blacklist'] as List<dynamic>?) ?? <dynamic>[]);

    if (actorIsStreamer || currentUser['id'] == ownerId) {
      if (action == 'MUTE' && !muted.contains(targetUserId)) muted.add(targetUserId);
      if (action == 'UNMUTE') muted.remove(targetUserId);
      if (action == 'BLACKLIST' && !blacklist.contains(targetUserId)) blacklist.add(targetUserId);
    } else if (actorIsAdmin) {
      final bool hasVipOrSvip = actorVipTier == 'VIP' || actorVipTier == 'SVIP';
      if (action == 'MUTE' && hasVipOrSvip && !muted.contains(targetUserId)) {
        muted.add(targetUserId);
      }
      if (action == 'UNMUTE' && hasVipOrSvip) {
        muted.remove(targetUserId);
      }
      // Admin cannot blacklist
    }
    streamer['mutedUsers'] = muted;
    streamer['blacklist'] = blacklist;
    notifyListeners();
  }
}

class ZoonlMainShell extends StatefulWidget {
  const ZoonlMainShell({super.key});

  @override
  State<ZoonlMainShell> createState() => _ZoonlMainShellState();
}

class _ZoonlMainShellState extends State<ZoonlMainShell> {
  final ZoonlStore store = ZoonlStore.instance;
  int topTabIndex = 0; // 0: Short Video (default first), 1: Live, 2: PK, 3: Audio, 4: VIP Hub
  int bottomIndex = 0; // 0: Home/TopTabs, 1: Inbox, 2: Wallet, 3: Support, 4: Profile

  @override
  void initState() {
    super.initState();
    store.checkTrialExpiryAndMoveToBackup();
    store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? welcome = store.pendingNewIdWelcome;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                // Global 5+ second non-intrusive gift ticker banner
                if (store.activeGlobalGiftBanner != null)
                  _buildGlobalGiftBanner(store.activeGlobalGiftBanner!),

                // Top Step-by-Step Section Tabs (Short Video first)
                if (bottomIndex == 0) _buildTopSectionTabs(),

                // Main Content
                Expanded(child: _buildBody()),
              ],
            ),
          ),

          // Side Floating Round Bubble for Admin Streamers & Friends Live
          Positioned(
            right: 12,
            bottom: 110,
            child: _buildFloatingAdminFriendBubble(),
          ),

          // New ID 5-Day Welcome Concert Popup
          if (welcome != null) _buildNewIdWelcomeOverlay(welcome),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGlobalGiftBanner(Map<String, dynamic> banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF2A184A), Color(0xFF140D26)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6C47A), width: 1),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lv.${banner['senderLevel']} ${banner['senderName']} → ${banner['giftName']} → ${banner['streamerName']} [${banner['streamerCrown']}]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSectionTabs() {
    const List<String> labels = <String>['Short Video', 'Live', 'PK', 'Audio', 'VIP Hub'];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool active = topTabIndex == index;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: active,
            selectedColor: const Color(0xFF7C4DFF),
            backgroundColor: const Color(0xFF150F2B),
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFFE6C47A),
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) => setState(() => topTabIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildFloatingAdminFriendBubble() {
    final List> liveTargets = >[
      ...store.adminAssignedStreamers.where((Map<String, dynamic> e) => e['isLive'] == true),
      ...store.friendsList.where((Map<String, dynamic> e) => e['isLive'] == true),
    ];

    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: const Color(0xFF120D24),
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Admin Streamers & Friends Live Now',
                    style: TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (liveTargets.isEmpty)
                    const Text('Abhi koi Admin Streamer ya Friend live nahi hai.', style: TextStyle(color: Colors.white70))
                  else
                    ...liveTargets.map((Map<String, dynamic> item) {
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF7C4DFF), child: Icon(Icons.live_tv, color: Colors.white)),
                        title: Text('${item['name']} (ID: ${item['id']})', style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('LIVE NOW', style: TextStyle(color: Color(0xFF00E676))),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => topTabIndex = 1);
                        },
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: <Color>[Color(0xFFE6C47A), Color(0xFF7C4DFF)]),
          boxShadow: const <BoxShadow>[BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(Icons.radar, color: Colors.white),
            if (liveTargets.isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text('${liveTargets.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewIdWelcomeOverlay(Map<String, dynamic> welcome) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16102E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE6C47A), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.auto_awesome, color: Color(0xFFE6C47A), size: 42),
              const SizedBox(height: 10),
              Text(welcome['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE6C47A))),
              const SizedBox(height: 8),
              Text(welcome['subtitle'] as String, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
                onPressed: () {
                  store.pendingNewIdWelcome = null;
                  store.notifyListeners();
                },
                child: const Text('Claim 5-Day VIP Trial', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: const Color(0xFF100B21),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(icon: const Icon(Icons.home_filled), onPressed: () => setState(() => bottomIndex = 0)),
          IconButton(icon: const Icon(Icons.mail_outline), onPressed: () => setState(() => bottomIndex = 1)),
          // Center Live Start Button -> 3 options: Live, Audio, Private Room
          GestureDetector(
            onTap: _openCenterLiveStartSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: <Color>[Color(0xFFE6C47A), Color(0xFF7C4DFF)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.videocam, color: Colors.black, size: 20),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.account_balance_wallet_outlined), onPressed: () => setState(() => bottomIndex = 2)),
          IconButton(icon: const Icon(Icons.support_agent), onPressed: () => setState(() => bottomIndex = 3)),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => setState(() => bottomIndex = 4)),
        ],
      ),
    );
  }

  void _openCenterLiveStartSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF140E28),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Start Broadcast Mode', style: TextStyle(color: Color(0xFFE6C47A), fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.live_tv, color: Color(0xFFE6C47A)),
                title: const Text('1. Live Section (Video Broad)'),
                subtitle: const Text('Verified Streamer Lv.1+ | Normal User Lv.5+'),
                onTap: () {
                  Navigator.pop(context);
                  if (!store.canStartLive()) return;
                  store.toggleLiveStatus(goLive: true, mode: 'VIDEO');
                  setState(() {
                    bottomIndex = 0;
                    topTabIndex = 1;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.graphic_eq, color: Color(0xFF7C4DFF)),
                title: const Text('2. Audio Section (6 / 8 Seats)'),
                subtitle: const Text('Streamer + / Call Join Accept-Reject Control'),
                onTap: () {
                  Navigator.pop(context);
                  if (!store.canStartLive()) return;
                  store.toggleLiveStatus(goLive: true, mode: 'AUDIO');
                  setState(() {
                    bottomIndex = 0;
                    topTabIndex = 3;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key, color: Colors.amberAccent),
                title: const Text('3. Private Room (Key + Inbox Invite)'),
                subtitle: const Text('Hidden Publicly • Max 2–3 People • Audio/Video/Gift'),
                onTap: () {
                  Navigator.pop(context);
                  final String keyCode = 'KEY-${Random().nextInt(9000) + 1000}';
                  store.privateRooms.add(<String, dynamic>{
                    'roomId': 'PR-${Random().nextInt(99999)}',
                    'hostId': store.currentUser['id'],
                    'key': keyCode,
                    'maxSeats': 3,
                  });
                  store.inboxMessages.add(<String, dynamic>{
                    'from': store.currentUser['name'],
                    'fromId': store.currentUser['id'],
                    'text': 'Private Room Invite — Key: $keyCode',
                    'privateKey': keyCode,
                  });
                  store.notifyListeners();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    // Part 2 renders full interactive screens for Short Video, Live/PK/Audio, Wallet, Support AI & Owner/Profile Settings
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Part 1 Core Loaded • Active Tab: $topTabIndex • Bottom: $bottomIndex\nOwner 10001 Sovereign Protection & 5-Day Trial Ready.\nSend Part 2 request to attach full Live/PK/Audio/Earning/AI/Settings screens.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE6C47A), fontSize: 14),
        ),
      ),
    );
  }
}
