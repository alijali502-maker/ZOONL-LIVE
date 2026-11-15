
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

class ZoonlStore extends ChangeNotifier {
  static final ZoonlStore instance = ZoonlStore._internal();

  ZoonlStore._internal() {
    _initDefaults();
    _startGlobalTicker();
  }

  static const String ownerId = '10001';

  Map<String, dynamic> currentUser = <String, dynamic>{
    'id': '10001',
    'name': 'ZOONL Sovereign Owner',
    'isOwner': true,
    'isVerifiedStreamer': true,
    'streamerId': 'ST-10001',
    'level': 100,
    'sentCoins': 50000000,
    'coins': 999999999,
    'diamonds': 0,
    'walletBalance': 0.0,
    'vipTier': 'SVIP',
    'isNewId': false,
    'trialExpiresAt': null,
    'friendListPublic': true,
    'linkedAccounts': <String>[
      'Email Auth',
      'Phone SMS',
      'Google',
      'Device Key'
    ],
    'payoutLocked': true,
    'payoutMethod': 'Official Owner Vault',
    'payoutAccount': 'OWNER-10001-VAULT',
    'registrationType': 'OWNER',
    'approved': true,
    'isLive': false,
    'offlineSince': null,
  };

  final Set<String> _ownerPermanentBannedIds = <String>{};
  final Map<String, String> _ownerBanReasons = <String, String>{};

  final Map<String, Map<String, dynamic>> adminAccounts =
      <String, Map<String, dynamic>>{
    'ADM-201': <String, dynamic>{
      'id': 'ADM-201',
      'name': 'Elite Admin Tara',
      'coinLimit': 500000,
      'coinsUsed': 120000,
      'stopped': false,
    },
  };

  List<Map<String, dynamic>> memberships = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> agencyApplications =
      <Map<String, dynamic>>[];

  String officialHostingEmail = 'hosting@zoonllive.com';
  String officialHostingContact = '+971-50-000-10001';
  String supportEmail = 'support@zoonllive.com';
  String supportContact = '+971-50-111-10001';

  final List<Map<String, dynamic>> ownerRewardLibrary =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'r1',
      'type': 'Frame',
      'name': 'Sovereign Gold Crown Frame',
      'rarity': 'Mythic',
    },
    <String, dynamic>{
      'id': 'r2',
      'type': 'Entry',
      'name': 'Phantom Dragon Sovereign Entry',
      'rarity': 'Mythic',
    },
    <String, dynamic>{
      'id': 'r3',
      'type': 'Background',
      'name': 'Royal Eclipse Back-Aura',
      'rarity': 'VIP',
    },
    <String, dynamic>{
      'id': 'r4',
      'type': 'Frame',
      'name': 'Crimson Phoenix Frame',
      'rarity': 'Legendary',
    },
    <String, dynamic>{
      'id': 'r5',
      'type': 'Entry',
      'name': 'Golden Meteor Arrival',
      'rarity': 'Legendary',
    },
  ];

  final List<Map<String, dynamic>> backupStore =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'b1',
      'type': 'Frame',
      'name': 'Owner Sovereign Frame',
      'equipped': true,
      'fromTrial': false,
    },
    <String, dynamic>{
      'id': 'b2',
      'type': 'Entry',
      'name': 'Sovereign Gate Entry',
      'equipped': true,
      'fromTrial': false,
    },
    <String, dynamic>{
      'id': 'b3',
      'type': 'Background',
      'name': 'Royal Eclipse Back-Aura',
      'equipped': true,
      'fromTrial': false,
    },
  ];

  final List<Map<String, dynamic>> streamers =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> shortVideos =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> privateRooms =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> inboxMessages =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> friendsList =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> adminAssignedStreamers =
      <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> _giftTickerQueue =
      <Map<String, dynamic>>[];

  Map<String, dynamic>? activeGlobalGiftBanner;
  Timer? _tickerTimer;

  Map<String, dynamic>? pendingNewIdWelcome;

  void syncRemoteLists(
    List<dynamic> rawMemberships,
    List<dynamic> rawApps,
  ) {
    memberships = List<Map<String, dynamic>>.from(
      rawMemberships.map(
        (dynamic item) => item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map),
      ),
    );

    agencyApplications = List<Map<String, dynamic>>.from(
      rawApps.map(
        (dynamic item) => item is Map<String, dynamic>
            ? item
            : Map<String, dynamic>.from(item as Map),
      ),
    );

    notifyListeners();
  }

  void _initDefaults() {
    memberships = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'M-1',
        'tier': 'SVIP',
        'active': true,
      },
    ];

    agencyApplications = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'AG-1',
        'agencyCode': 'AG-1001',
        'status': 'APPROVED',
      },
    ];

    streamers.addAll(<Map<String, dynamic>>[
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
        'walletBalance': 0.0,
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
        'giftersHistory': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': '77101',
            'name': 'Rohan',
            'coins': 2400000,
            'period': 'MONTHLY',
          },
          <String, dynamic>{
            'userId': '77102',
            'name': 'Tariq',
            'coins': 950000,
            'period': 'WEEKLY',
          },
          <String, dynamic>{
            'userId': '77103',
            'name': 'Hamza',
            'coins': 260000,
            'period': 'DAILY',
          },
          <String, dynamic>{
            'userId': '77104',
            'name': 'Bilal',
            'coins': 65000,
            'period': 'DAILY',
          },
          <String, dynamic>{
            'userId': '77105',
            'name': 'Usman',
            'coins': 15000,
            'period': 'DAILY',
          },
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
        'pendingCallRequests': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': '55210',
            'name': 'Ayan',
            'type': 'CALL',
          },
        ],
        'seats': List<Map<String, dynamic>>.generate(8, (int i) {
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
        'walletBalance': 0.0,
        'isAdminForMe': true,
        'inMyFriends': false,
        'blacklist': <String>[],
        'roomAdmins': <String>[],
        'mutedUsers': <String>[],
        'giftersHistory': <Map<String, dynamic>>[],
      },
      <String, dynamic>{
        'id': 'STR-103',
        'userId': '88450',
        'name': 'Noor Star',
        'verified': true,
        'isLive': false,
        'offlineSince': DateTime.now().subtract(
          const Duration(minutes: 24),
        ),
        'mode': 'VIDEO',
        'sentCoins': 850000,
        'receivedCoins': 640000,
        'dailyReceiving': 0,
        'walletBalance': 0.0,
        'isAdminForMe': false,
        'inMyFriends': true,
        'blacklist': <String>[],
        'roomAdmins': <String>[],
        'mutedUsers': <String>[],
        'giftersHistory': <Map<String, dynamic>>[],
      },
    ]);

    shortVideos.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'SV-1',
        'author': 'Zara Queen',
        'authorId': '88412',
        'caption': 'Royal Night Vibes #ZOONL',
        'filter': 'VIP Velvet Glow',
        'likes': 1420,
      },
      <String, dynamic>{
        'id': 'SV-2',
        'author': 'Maya Melody',
        'authorId': '88419',
        'caption': 'Live Audio & PK Tonight',
        'filter': 'Golden Rose LUT',
        'likes': 980,
      },
    ]);

    friendsList.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': '88412',
        'name': 'Zara Queen',
        'isLive': true,
      },
      <String, dynamic>{
        'id': '88450',
        'name': 'Noor Star',
        'isLive': false,
      },
      <String, dynamic>{
        'id': '66310',
        'name': 'Danish',
        'isLive': true,
      },
    ]);

    adminAssignedStreamers.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': '88412',
        'name': 'Zara Queen',
        'isLive': true,
      },
      <String, dynamic>{
        'id': '88419',
        'name': 'Maya Melody',
        'isLive': true,
      },
    ]);

    inboxMessages.addAll(<Map<String, dynamic>>[
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

    _tickerTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (_giftTickerQueue.isNotEmpty) {
          activeGlobalGiftBanner = _giftTickerQueue.removeAt(0);
        } else {
          activeGlobalGiftBanner = null;
        }

        notifyListeners();
      },
    );
  }

  bool isPermanentlyBannedByOwner(String targetId) {
    return _ownerPermanentBannedIds.contains(targetId);
  }

  void ownerPermanentBan(
    String targetId, {
    String reason = 'Rule violation / Fraud',
  }) {
    if (currentUser['id'] != ownerId) return;
    if (targetId == ownerId) return;

    _ownerPermanentBannedIds.add(targetId);
    _ownerBanReasons[targetId] = reason;

    streamers.removeWhere(
      (Map<String, dynamic> s) =>
          s['userId'] == targetId || s['id'] == targetId,
    );

    notifyListeners();
  }

  void registerNewIdWithTrial({
    required String newId,
    required String name,
    required bool asStreamer,
  }) {
    if (isPermanentlyBannedByOwner(newId)) return;

    final DateTime expiry = DateTime.now().add(
      const Duration(days: 5),
    );

    final String autoStreamerCode = asStreamer
        ? 'ST-${Random().nextInt(89999) + 10000}'
        : '';

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

    backupStore.addAll(<Map<String, dynamic>>[
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
      'subtitle':
          'Application ki taraf se aapko 5 din ke liye Frame, Entry, SVIP aur Background mil gaya hai!',
      'items': <String>[
        '5D Frame',
        '5D Special Entry',
        '5D SVIP',
        '5D Background Aura',
      ],
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

  int resolveUserLevel(int sentCoins) {
    const List<int> thresholds = <int>[
      0,
      50000,
      100000,
      160000,
      230000,
      310000,
      400000,
      500000,
      620000,
      750000,
      1000000,
      1300000,
      1600000,
      1900000,
      2200000,
      2700000,
      3200000,
      3700000,
      4200000,
      4700000,
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

  Map<String, dynamic> resolveColorStar(int sentCoins) {
    if (sentCoins >= 2000000) {
      return <String, dynamic>{
        'stars': 5,
        'label': 'BIG STAR',
        'color': const Color(0xFFFF2E93),
      };
    } else if (sentCoins >= 1000000) {
      return <String, dynamic>{
        'stars': 4,
        'label': '4 STAR',
        'color': const Color(0xFFFF9100),
      };
    } else if (sentCoins >= 200000) {
      return <String, dynamic>{
        'stars': 3,
        'label': '3 STAR',
        'color': const Color(0xFF00E5FF),
      };
    } else if (sentCoins >= 50000) {
      return <String, dynamic>{
        'stars': 2,
        'label': '2 STAR',
        'color': const Color(0xFF7C4DFF),
      };
    } else if (sentCoins >= 10000) {
      return <String, dynamic>{
        'stars': 1,
        'label': '1 STAR',
        'color': const Color(0xFFFFD54F),
      };
    }

    return <String, dynamic>{
      'stars': 0,
      'label': 'NO STAR',
      'color': Colors.white38,
    };
  }

  Map<String, dynamic> resolveStreamerCrownOrDemon(int sentCoins) {
    if (sentCoins < 30000) {
      return <String, dynamic>{
        'kind': 'HEART',
        'count': 1,
        'title': 'Mini Heart',
        'color': const Color(0xFFFF5C8A),
      };
    } else if (sentCoins < 150000) {
      final int d = sentCoins < 80000 ? 1 : 2;

      return <String, dynamic>{
        'kind': 'DEMON',
        'count': d,
        'title': '$d Demon',
        'color': const Color(0xFFFF3D57),
      };
    } else {
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

    currentUser['sentCoins'] =
        ((currentUser['sentCoins'] as int?) ?? 0) + giftCoins;

    currentUser['level'] = resolveUserLevel(
      currentUser['sentCoins'] as int,
    );

    streamer['receivedCoins'] =
        ((streamer['receivedCoins'] as int?) ?? 0) + giftCoins;

    streamer['dailyReceiving'] =
        ((streamer['dailyReceiving'] as int?) ?? 0) + giftCoins;

    final double payoutGain = (giftCoins * 0.65) / 100.0;

    streamer['walletBalance'] =
        ((streamer['walletBalance'] as double?) ?? 0.0) + payoutGain;

    currentUser['walletBalance'] =
        ((currentUser['walletBalance'] as double?) ?? 0.0) + payoutGain;

    final List<Map<String, dynamic>> history =
        List<Map<String, dynamic>>.from(
      (streamer['giftersHistory'] as List<dynamic>?) ?? <dynamic>[],
    );

    history.insert(0, <String, dynamic>{
      'userId': senderId,
      'name': currentUser['name'],
      'coins': giftCoins,
      'period': 'DAILY',
    });

    streamer['giftersHistory'] = history;

    final Map<String, dynamic> crownInfo =
        resolveStreamerCrownOrDemon(
      streamer['receivedCoins'] as int,
    );

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

  bool canStartLive() {
    if (currentUser['id'] == ownerId) return true;
    if (currentUser['isVerifiedStreamer'] == true) return true;

    return ((currentUser['level'] as int?) ?? 1) >= 5;
  }

  void toggleLiveStatus({
    required bool goLive,
    String mode = 'VIDEO',
  }) {
    if (goLive && !canStartLive()) return;

    currentUser['isLive'] = goLive;
    currentUser['offlineSince'] = goLive ? null : DateTime.now();

    notifyListeners();
  }

  void moderateUser({
    required Map<String, dynamic> streamer,
    required String targetUserId,
    required String action,
    required bool actorIsStreamer,
    required bool actorIsAdmin,
    required String actorVipTier,
  }) {
    final List<String> muted = List<String>.from(
      (streamer['mutedUsers'] as List<dynamic>?) ?? <dynamic>[],
    );

    final List<String> blacklist = List<String>.from(
      (streamer['blacklist'] as List<dynamic>?) ?? <dynamic>[],
    );

    if (actorIsStreamer || currentUser['id'] == ownerId) {
      if (action == 'MUTE' && !muted.contains(targetUserId)) {
        muted.add(targetUserId);
      }

      if (action == 'UNMUTE') {
        muted.remove(targetUserId);
      }

      if (action == 'BLACKLIST' && !blacklist.contains(targetUserId)) {
        blacklist.add(targetUserId);
      }
    } else if (actorIsAdmin) {
      final bool hasVipOrSvip =
          actorVipTier == 'VIP' || actorVipTier == 'SVIP';

      if (action == 'MUTE' &&
          hasVipOrSvip &&
          !muted.contains(targetUserId)) {
        muted.add(targetUserId);
      }

      if (action == 'UNMUTE' && hasVipOrSvip) {
        muted.remove(targetUserId);
      }
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

  int topTabIndex = 0;
  int bottomIndex = 0;

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
                if (store.activeGlobalGiftBanner != null)
                  _buildGlobalGiftBanner(
                    store.activeGlobalGiftBanner!,
                  ),
                if (bottomIndex == 0) _buildTopSectionTabs(),
                Expanded(
                  child: ZoonlCompleteBody(
                    topTabIndex: topTabIndex,
                    bottomIndex: bottomIndex,
                    onSwitchToLive: () {
                      setState(() {
                        bottomIndex = 0;
                        topTabIndex = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: _buildFloatingAdminFriendBubble(),
          ),
          if (welcome != null) _buildNewIdWelcomeOverlay(welcome),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildGlobalGiftBanner(Map<String, dynamic> banner) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF2A184A),
            Color(0xFF140D26),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE6C47A),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.card_giftcard,
            color: Color(0xFFFFD700),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Lv.${banner['senderLevel']} ${banner['senderName']} -> ${banner['giftName']} -> ${banner['streamerName']} [${banner['streamerCrown']}]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSectionTabs() {
    const List<String> labels = <String>[
      'Short Video',
      'Live',
      'PK',
      'Audio',
      'VIP Hub',
    ];

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
            onSelected: (_) {
              setState(() => topTabIndex = index);
            },
          );
        },
      ),
    );
  }

  Widget _buildFloatingAdminFriendBubble() {
    final List<Map<String, dynamic>> liveTargets =
        <Map<String, dynamic>>[
      ...store.adminAssignedStreamers.where(
        (Map<String, dynamic> e) => e['isLive'] == true,
      ),
      ...store.friendsList.where(
        (Map<String, dynamic> e) => e['isLive'] == true,
      ),
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
                    style: TextStyle(
                      color: Color(0xFFE6C47A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (liveTargets.isEmpty)
                    const Text(
                      'Abhi koi Admin Streamer ya Friend live nahi hai.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    ...liveTargets.map((Map<String, dynamic> item) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF7C4DFF),
                          child: Icon(
                            Icons.live_tv,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          '${item['name']} (ID: ${item['id']})',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'LIVE NOW',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                          ),
                        ),
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
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFE6C47A),
              Color(0xFF7C4DFF),
            ],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
            ),
          ],
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
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${liveTargets.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewIdWelcomeOverlay(
    Map<String, dynamic> welcome,
  ) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16102E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE6C47A),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFE6C47A),
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                welcome['title'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6C47A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                welcome['subtitle'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                ),
                onPressed: () {
                  store.pendingNewIdWelcome = null;
                  store.notifyListeners();
                },
                child: const Text(
                  'Claim 5-Day VIP Trial',
                  style: TextStyle(color: Colors.white),
                ),
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
          IconButton(
            icon: const Icon(Icons.home_filled),
            onPressed: () {
              setState(() => bottomIndex = 0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            onPressed: () {
              setState(() => bottomIndex = 1);
            },
          ),
          GestureDetector(
            onTap: _openCenterLiveStartSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFFE6C47A),
                    Color(0xFF7C4DFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.videocam,
                    color: Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.account_balance_wallet_outlined,
            ),
            onPressed: () {
              setState(() => bottomIndex = 2);
            },
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () {
              setState(() => bottomIndex = 3);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              setState(() => bottomIndex = 4);
            },
          ),
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
              const Text(
                'Start Broadcast Mode',
                style: TextStyle(
                  color: Color(0xFFE6C47A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.live_tv,
                  color: Color(0xFFE6C47A),
                ),
                title: const Text(
                  '1. Live Section (Video Broad)',
                ),
                subtitle: const Text(
                  'Verified Streamer Lv.1+ | Normal User Lv.5+',
                ),
                onTap: () {
                  Navigator.pop(context);

                  if (!store.canStartLive()) return;

                  store.toggleLiveStatus(
                    goLive: true,
                    mode: 'VIDEO',
                  );

                  setState(() {
                    bottomIndex = 0;
                    topTabIndex = 1;
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.graphic_eq,
                  color: Color(0xFF7C4DFF),
                ),
                title: const Text(
                  '2. Audio Section (6 / 8 Seats)',
                ),
                subtitle: const Text(
                  'Streamer + / Call Join Accept-Reject Control',
                ),
                onTap: () {
                  Navigator.pop(context);

                  if (!store.canStartLive()) return;

                  store.toggleLiveStatus(
                    goLive: true,
                    mode: 'AUDIO',
                  );

                  setState(() {
                    bottomIndex = 0;
                    topTabIndex = 3;
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.vpn_key,
                  color: Colors.amberAccent,
                ),
                title: const Text(
                  '3. Private Room (Key + Inbox Invite)',
                ),
                subtitle: const Text(
                  'Hidden Publicly • Max 2–3 People • Audio/Video/Gift',
                ),
                onTap: () {
                  Navigator.pop(context);

                  final String keyCode =
                      'KEY-${Random().nextInt(9000) + 1000}';

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
}

class ZoonlCompleteBody extends StatefulWidget {
  final int topTabIndex;
  final int bottomIndex;
  final VoidCallback onSwitchToLive;

  const ZoonlCompleteBody({
    super.key,
    required this.topTabIndex,
    required this.bottomIndex,
    required this.onSwitchToLive,
  });

  @override
  State<ZoonlCompleteBody> createState() =>
      _ZoonlCompleteBodyState();
}

class _ZoonlCompleteBodyState extends State<ZoonlCompleteBody> {
  final ZoonlStore store = ZoonlStore.instance;

  String selectedVideoFilter = 'VIP Velvet Glow';
  bool recordingShort = false;

  final TextEditingController shortCaptionCtrl =
      TextEditingController();

  double skinSmooth = 0.75;
  double faceSize = 0.50;
  double eyeSize = 0.65;

  String eyeLens = 'Crystal Hazel';
  String eyeColor = 'Amber Gold';
  String makeupPreset = 'Royal Glamour';

  bool micMuted = false;
  bool camMuted = false;

  String pkModeSelected = '6P';
  String historyPeriod = 'DAILY';

  String kycCountry = 'Pakistan';
  String kycDob = '1998-05-12';

  bool kycFrontUploaded = false;
  bool kycBackUploaded = false;
  bool kycCardSelfieUploaded = false;

  final TextEditingController payoutAccountCtrl =
      TextEditingController(
    text: 'EasyPaisa - 03001234567',
  );

  final TextEditingController agencyTrackCtrl =
      TextEditingController();

  bool registrationSubmitted = false;

  bool aiExpanded = false;
  bool femaleVoiceEnabled = true;

  String selectedAiAnswer =
      'Assalam-o-Alaikum! Main ZOONL LIVE AI Support hoon. Koi bhi option chunein ya sawal poochein.';

  final List<Map<String, String>> aiQuickPrompts =
      <Map<String, String>>[
    <String, String>{
      'q': '65% Earning & 1–5 Payout rule kya hai?',
      'a':
          'Streamer ko sending/diamonds ka 65% wallet mein milta hai. Mahina khatam hone ke baad 1 se 5 tareekh ke beech withdraw request lagti hai aur 5 din ke andar payout milta hai.',
    },
    <String, String>{
      'q': 'Direct Hosting vs Agency/Track registration?',
      'a':
          'Earning folder mein step-by-step KYC (Front, Back, Card selfie, DOB, Country) aur payout account lock karke direct apply karein, ya Agency/Track number darj karke agency route se register karein.',
    },
    <String, String>{
      'q': 'Level 1 vs Level 5 Live rule kya hai?',
      'a':
          'Verified Streamer Level 1 se live aa sakta hai, jabke normal user ko live broad ke liye kam az kam Level 5 chahiye.',
    },
    <String, String>{
      'q': 'Admin Mute & Blacklist ka rule?',
      'a':
          'Streamer bina shart Mute/Blacklist/Boot kar sakta hai. Streamer ka banaya hua Admin sirf VIP/SVIP hone par Mute kar sakta hai; Admin Blacklist nahi kar sakta.',
    },
    <String, String>{
      'q': 'Private Room kaise kaam karta hai?',
      'a':
          'Center LIVE button se Private Room chunein. Yeh bahar public feed mein nahi dikhta; Key generate karke Inbox mein friend ko bhejein. Max 2–3 log audio/video/gift kar sakte hain.',
    },
    <String, String>{
      'q': 'Crown / Demon aur Color Star kaise badalte hain?',
      'a':
          '10k=1 Star, 50k=2 Star, 200k=3 Star, 1M=4 Star, 2M=Big Star. Streamer par pehle Heart/Demon aur phir auto-replace hokar 1 se 40 Crown tak lagta hai.',
    },
    <String, String>{
      'q': 'New ID 5-Day Trial ka kya hota hai?',
      'a':
          'Nayi ID pehle login par 5 din ke liye Frame, Special Entry, SVIP aur Background leti hai; expire hone par sab Backup Store mein chala jata hai.',
    },
    <String, String>{
      'q': 'Owner 10001 Permanent Ban kaise kaam karta hai?',
      'a':
          'Fraud ya rule violation par sirf Owner 10001 permanent ban/block laga sakta hai; yeh kisi aur ko nazar nahi aata aur koi change nahi kar sakta.',
    },
  ];

  @override
  void dispose() {
    shortCaptionCtrl.dispose();
    payoutAccountCtrl.dispose();
    agencyTrackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bottomIndex == 1) return _buildInboxScreen();
    if (widget.bottomIndex == 2) {
      return _buildWalletAndEarningScreen();
    }
    if (widget.bottomIndex == 3) return _buildSupportAiScreen();
    if (widget.bottomIndex == 4) {
      return _buildProfileAndSettingsScreen();
    }

    switch (widget.topTabIndex) {
      case 0:
        return _buildShortVideoSection();
      case 1:
        return _buildLiveSection();
      case 2:
        return _buildPkSection();
      case 3:
        return _buildAudioSection();
      default:
        return _buildVipHubSection();
    }
  }

  Widget _buildShortVideoSection() {
    const List<String> filters = <String>[
      'VIP Velvet Glow',
      'Golden Rose LUT',
      'Neon Cyber',
      'Soft Porcelain',
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title: 'Short Video Studio (Filter • Record • Post)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: filters.map((String f) {
                  return ChoiceChip(
                    label: Text(f),
                    selected: selectedVideoFilter == f,
                    onSelected: (_) {
                      setState(() => selectedVideoFilter = f);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: shortCaptionCtrl,
                decoration: const InputDecoration(
                  hintText: 'Video caption likhein...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        recordingShort = !recordingShort;
                      });
                    },
                    icon: Icon(
                      recordingShort
                          ? Icons.stop
                          : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      recordingShort
                          ? 'Stop Recording'
                          : 'Record Video',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () {
                      store.shortVideos.insert(
                        0,
                        <String, dynamic>{
                          'id':
                              'SV-${DateTime.now().millisecondsSinceEpoch}',
                          'author': store.currentUser['name'],
                          'authorId': store.currentUser['id'],
                          'caption': shortCaptionCtrl.text.isEmpty
                              ? 'New ZOONL Short'
                              : shortCaptionCtrl.text,
                          'filter': selectedVideoFilter,
                          'likes': 0,
                        },
                      );

                      shortCaptionCtrl.clear();
                      store.notifyListeners();
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Post Short Video'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...store.shortVideos.map((Map<String, dynamic> vid) {
          return _luxuryCard(
            title: '${vid['author']} • Filter: ${vid['filter']}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text('${vid['caption']}'),
                ),
                TextButton.icon(
                  onPressed: () {
                    vid['likes'] =
                        ((vid['likes'] as int?) ?? 0) + 1;

                    store.notifyListeners();
                  },
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                  ),
                  label: Text('${vid['likes']}'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiveSection() {
    final Map<String, dynamic> activeStreamer =
        store.streamers.firstWhere(
      (Map<String, dynamic> s) => s['mode'] == 'VIDEO',
      orElse: () => store.streamers.first,
    );

    final Map<String, dynamic> crownInfo =
        store.resolveStreamerCrownOrDemon(
      (activeStreamer['receivedCoins'] as int?) ?? 0,
    );

    final Map<String, dynamic> starInfo =
        store.resolveColorStar(
      (store.currentUser['sentCoins'] as int?) ?? 0,
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title:
              '${activeStreamer['name']} (ID: ${activeStreamer['userId']}) • ${crownInfo['title']}',
          trailing: _buildThreeDotModerationButton(
            activeStreamer,
            activeStreamer['userId'] as String,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <String>[
                  'DAILY',
                  'WEEKLY',
                  'MONTHLY',
                ].map((String p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p),
                      selected: historyPeriod == p,
                      onSelected: (_) {
                        setState(() => historyPeriod = p);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                'Top 10 & All Senders ($historyPeriod): '
                '${((activeStreamer['giftersHistory'] as List<dynamic>?) ?? <dynamic>[]).take(10).map((dynamic g) => '${g['name']} (${g['coins']})').join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE6C47A),
                ),
              ),
              const Divider(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 170,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1235),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE6C47A),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Streamer Live (${camMuted ? "Cam Off" : "Cam On"} • ${micMuted ? "Mic Off" : "Mic On"})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Color Star: ${starInfo['label']}',
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              IconButton(
                                icon: Icon(
                                  micMuted
                                      ? Icons.mic_off
                                      : Icons.mic,
                                ),
                                onPressed: () {
                                  setState(() {
                                    micMuted = !micMuted;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  camMuted
                                      ? Icons.videocam_off
                                      : Icons.videocam,
                                ),
                                onPressed: () {
                                  setState(() {
                                    camMuted = !camMuted;
                                  });
                                },
                              ),
                              Switch(
                                value:
                                    activeStreamer['videoCallOpen'] == true,
                                onChanged: (bool v) {
                                  activeStreamer['videoCallOpen'] = v;
                                  store.notifyListeners();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (activeStreamer['videoCallOpen'] == true)
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 170,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF100A24),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF7C4DFF),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Side Guest',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${activeStreamer['guestName']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            DropdownButton<String>(
                              isExpanded: true,
                              value:
                                  activeStreamer['guestCallMode']
                                          as String? ??
                                      'VIDEO',
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: 'VIDEO',
                                  child: Text('Video Call'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'AUDIO',
                                  child: Text('Audio Call'),
                                ),
                              ],
                              onChanged: (String? val) {
                                if (val != null) {
                                  activeStreamer['guestCallMode'] = val;
                                  store.notifyListeners();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'VIP Beauty Filter',
                style: TextStyle(
                  color: Color(0xFFE6C47A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: skinSmooth,
                onChanged: (double v) {
                  setState(() => skinSmooth = v);
                },
              ),
              Slider(
                value: faceSize,
                onChanged: (double v) {
                  setState(() => faceSize = v);
                },
              ),
              Slider(
                value: eyeSize,
                onChanged: (double v) {
                  setState(() => eyeSize = v);
                },
              ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  Chip(label: Text('Lens: $eyeLens')),
                  Chip(label: Text('Eye Color: $eyeColor')),
                  Chip(label: Text('Makeup: $makeupPreset')),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  store.sendGift(
                    streamer: activeStreamer,
                    giftName: 'Royal Sovereign Castle',
                    giftCoins: 200000,
                  );
                },
                icon: const Icon(Icons.card_giftcard),
                label: const Text(
                  'Send Gift (200k Coins -> 65% Wallet + Global Patti)',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPkSection() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title:
              'PK Battle Arena (6P • 3P • 2P • Friend Train • 4-Grid)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: <String>[
                  '6P',
                  '3P',
                  '2P',
                  'TRAIN',
                  '4GRID',
                ].map((String m) {
                  return ChoiceChip(
                    label: Text(m),
                    selected: pkModeSelected == m,
                    onSelected: (_) {
                      setState(() => pkModeSelected = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text('Active PK Mode: $pkModeSelected'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(
                  pkModeSelected == '6P'
                      ? 6
                      : pkModeSelected == '4GRID'
                          ? 4
                          : pkModeSelected == '3P'
                              ? 3
                              : 2,
                  (int idx) {
                    return Container(
                      width: 140,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1235),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE6C47A),
                        ),
                      ),
                      child: Text(
                        'Slot ${idx + 1} ($pkModeSelected)',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    final Map<String, dynamic> audioRoom =
        store.streamers.firstWhere(
      (Map<String, dynamic> s) => s['mode'] == 'AUDIO',
      orElse: () => store.streamers.first,
    );

    final List<Map<String, dynamic>> seats =
        List<Map<String, dynamic>>.from(
      (audioRoom['seats'] as List<dynamic>?) ?? <dynamic>[],
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title:
              '${audioRoom['name']} • Audio Room (${seats.length} Seats)',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Color(0xFFE6C47A),
                ),
                onPressed: () {
                  audioRoom['plusOpen'] =
                      !(audioRoom['plusOpen'] == true);

                  store.notifyListeners();
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.phone_in_talk,
                  color: Color(0xFF00E676),
                ),
                onPressed: () {
                  audioRoom['callRequestOpen'] =
                      !(audioRoom['callRequestOpen'] == true);

                  store.notifyListeners();
                },
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: seats.length,
                itemBuilder: (_, int i) {
                  final Map<String, dynamic> seat = seats[i];

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF191133),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.headset_mic,
                          color: Color(0xFFE6C47A),
                        ),
                        Text(
                          'Seat ${seat['seat']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${seat['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ...((audioRoom['pendingCallRequests']
                          as List<dynamic>?) ??
                      <dynamic>[])
                  .map((dynamic req) {
                return ListTile(
                  title: Text(
                    'Call Join Request: ${req['name']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                        onPressed: () {
                          ((audioRoom['pendingCallRequests']
                                  as List<dynamic>))
                              .remove(req);

                          store.notifyListeners();
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          ((audioRoom['pendingCallRequests']
                                  as List<dynamic>))
                              .remove(req);

                          store.notifyListeners();
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVipHubSection() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title: 'VIP Top-Up & Backup Store',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Current VIP: ${store.currentUser['vipTier']} • Coins: ${store.currentUser['coins']}',
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  store.currentUser['vipTier'] = 'SVIP';
                  store.notifyListeners();
                },
                child: const Text('VIP / SVIP Top-Up Activate'),
              ),
              const SizedBox(height: 8),
              ...store.backupStore.map((Map<String, dynamic> b) {
                return ListTile(
                  title: Text(
                    '${b['name']} (${b['type']})',
                  ),
                  trailing: Switch(
                    value: b['equipped'] == true,
                    onChanged: (bool v) {
                      b['equipped'] = v;
                      store.notifyListeners();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        _luxuryCard(
          title:
              'Private Rooms (Hidden Publicly • Key + Inbox Invite)',
          child: Column(
            children: store.privateRooms.map(
              (Map<String, dynamic> pr) {
                return ListTile(
                  leading: const Icon(
                    Icons.lock,
                    color: Color(0xFFE6C47A),
                  ),
                  title: Text(
                    'Private Room ${pr['roomId']} (Key: ${pr['key']})',
                  ),
                  subtitle: const Text(
                    'Max 2–3 People • Audio + Video + Gifting',
                  ),
                );
              },
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInboxScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: store.inboxMessages.map(
        (Map<String, dynamic> m) {
          return _luxuryCard(
            title: 'From: ${m['from']} (ID: ${m['fromId']})',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text('${m['text']}'),
                ),
                if (m['privateKey'] != null)
                  ElevatedButton(
                    onPressed: widget.onSwitchToLive,
                    child: Text(
                      'Enter Key (${m['privateKey']})',
                    ),
                  ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildWalletAndEarningScreen() {
    final int nowDay = DateTime.now().day;
    final bool inPayoutWindow =
        nowDay >= 1 && nowDay <= 5;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title: 'Wallet & 65% Streamer Earning',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Coins: ${store.currentUser['coins']}'),
              Text(
                '65% Streamer Wallet Balance: \$${((store.currentUser['walletBalance'] as double?) ?? 0.0).toStringAsFixed(2)}',
              ),
              Text(
                inPayoutWindow
                    ? 'Payout Window Open (1–5 Tareekh) — 5 din ke andar payout milega.'
                    : 'Payout Window: Mahina khatam hone ke baad 1 se 5 tareekh tak request lagayein (5 din ke andar payout).',
                style: const TextStyle(
                  color: Color(0xFFE6C47A),
                ),
              ),
            ],
          ),
        ),
        _luxuryCard(
          title:
              'Earning Folder — Step-by-Step Direct / Agency Registration',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: kycCountry,
                items: const <String>[
                  'Pakistan',
                  'UAE',
                  'Saudi Arabia',
                  'India',
                  'Other',
                ].map(
                  (String c) {
                    return DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    );
                  },
                ).toList(),
                onChanged: (String? v) {
                  setState(() {
                    kycCountry = v ?? 'Pakistan';
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Country / Nationality',
                ),
              ),
              const SizedBox(height: 8),
              Text('DOB: $kycDob'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () {
                      setState(() => kycFrontUploaded = true);
                    },
                    child: Text(
                      kycFrontUploaded
                          ? 'Front ID ✓'
                          : 'Upload ID Front',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => kycBackUploaded = true);
                    },
                    child: Text(
                      kycBackUploaded
                          ? 'Back ID ✓'
                          : 'Upload ID Back',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(
                        () => kycCardSelfieUploaded = true,
                      );
                    },
                    child: Text(
                      kycCardSelfieUploaded
                          ? 'Card Selfie ✓'
                          : 'Upload Photo with Card',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: payoutAccountCtrl,
                enabled: !registrationSubmitted,
                decoration: const InputDecoration(
                  labelText:
                      'Mobile Wallet (e.g., EasyPaisa) / Bank Account (Locked on Submit)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: agencyTrackCtrl,
                decoration: const InputDecoration(
                  labelText: 'Optional Agency / Track Number',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    registrationSubmitted = true;
                    store.currentUser['payoutLocked'] = true;
                    store.currentUser['payoutAccount'] =
                        payoutAccountCtrl.text;
                  });
                },
                child: Text(
                  registrationSubmitted
                      ? 'Registration Submitted & Account Locked ✓'
                      : 'Submit Registration',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportAiScreen() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        GestureDetector(
          onTap: () {
            setState(() => aiExpanded = !aiExpanded);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1134),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE6C47A),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.smart_toy,
                          color: Color(0xFFE6C47A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          aiExpanded
                              ? 'ZOONL AI Assistant (Female Voice)'
                              : 'AI Support (Tap to Open)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      aiExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ],
                ),
                if (aiExpanded) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Text('Female Voice: '),
                      Switch(
                        value: femaleVoiceEnabled,
                        onChanged: (bool v) {
                          setState(() {
                            femaleVoiceEnabled = v;
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    selectedAiAnswer,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  ...aiQuickPrompts.map(
                    (Map<String, String> item) {
                      return ListTile(
                        dense: true,
                        title: Text(item['q'] ?? ''),
                        trailing: const Icon(
                          Icons.volume_up,
                          size: 18,
                          color: Color(0xFFE6C47A),
                        ),
                        onTap: () {
                          setState(() {
                            selectedAiAnswer = item['a'] ?? '';
                          });
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _luxuryCard(
          title: 'Support Team Contacts',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Support Email: ${store.supportEmail}'),
              Text('Support Contact: ${store.supportContact}'),
              Text(
                'Official Hosting Email: ${store.officialHostingEmail}',
              ),
              Text(
                'Official Hosting Contact: ${store.officialHostingContact}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAndSettingsScreen() {
    final bool isOwner =
        store.currentUser['id'] == ZoonlStore.ownerId;

    final bool isLive =
        store.currentUser['isLive'] == true;

    final DateTime? offlineSince =
        store.currentUser['offlineSince'] as DateTime?;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title:
              '${store.currentUser['name']} (ID: ${store.currentUser['id']})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Level: ${store.currentUser['level']} • VIP: ${store.currentUser['vipTier']}',
              ),
              Text(
                isLive
                    ? 'Status: LIVE'
                    : 'Status: OFFLINE ${offlineSince != null ? "(Since ${offlineSince.hour}:${offlineSince.minute})" : ""}',
                style: TextStyle(
                  color: isLive
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text(
                  'Friend List Public / Private',
                ),
                value:
                    store.currentUser['friendListPublic'] == true,
                onChanged: (bool v) {
                  store.currentUser['friendListPublic'] = v;
                  store.notifyListeners();
                },
              ),
              Text(
                'Linked Accounts: ${(store.currentUser['linkedAccounts'] as List<dynamic>).join(", ")}',
              ),
            ],
          ),
        ),
        if (isOwner)
          _luxuryCard(
            title:
                'Owner 10001 Sovereign Control (Permanent Ban & Limits)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Unlimited Coins: ACTIVE (No restriction on Owner 10001)',
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    store.ownerPermanentBan(
                      '99901',
                      reason:
                          'Permanent Streamer/Fraud Ban by Owner 10001',
                    );
                  },
                  icon: const Icon(Icons.gpp_bad),
                  label: const Text(
                    'Permanent Ban Fraud/Streamer ID (Owner Only)',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildThreeDotModerationButton(
    Map<String, dynamic> streamer,
    String targetUserId,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (String action) {
        store.moderateUser(
          streamer: streamer,
          targetUserId: targetUserId,
          action: action,
          actorIsStreamer:
              store.currentUser['id'] == streamer['userId'],
          actorIsAdmin:
              (streamer['roomAdmins'] as List<dynamic>)
                  .contains(store.currentUser['id']),
          actorVipTier:
              store.currentUser['vipTier'] as String? ?? 'NONE',
        );
      },
      itemBuilder: (_) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'MUTE',
          child: Text('Mute Chat'),
        ),
        PopupMenuItem<String>(
          value: 'UNMUTE',
          child: Text('Unmute Chat'),
        ),
        PopupMenuItem<String>(
          value: 'BLACKLIST',
          child: Text('Blacklist (Streamer Only)'),
        ),
        PopupMenuItem<String>(
          value: 'BOOT',
          child: Text('Boot from Room'),
        ),
      ],
    );
  }

  Widget _luxuryCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF120D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3A2766),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE6C47A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
