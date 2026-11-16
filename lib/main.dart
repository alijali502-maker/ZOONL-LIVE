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

  // Owner authority must come from a trusted authenticated role.
  // The public ZOONL ID is not, by itself, proof of Owner permission.
  bool get isOwner => currentUser['isOwner'] == true;

  Map<String, dynamic> currentUser = <String, dynamic>{
    'id': ownerId,
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
      'Device Key',
    ],
    'payoutLocked': true,
    'payoutMethod': 'Official Owner Vault',
    'payoutAccount': 'OWNER-10001-VAULT',
    'registrationType': 'OWNER',
    'approved': true,
    'isLive': false,
    'liveMode': 'VIDEO',
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
    memberships = _convertMaps(rawMemberships);
    agencyApplications = _convertMaps(rawApps);
    notifyListeners();
  }

  List<Map<String, dynamic>> _convertMaps(List<dynamic> source) {
    return source.map((dynamic item) {
      if (item is Map<String, dynamic>) return item;
      if (item is Map) return Map<String, dynamic>.from(item);
      throw FormatException('Invalid list item: $item');
    }).toList();
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
        'bootedUsers': <String>[],
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
        'bootedUsers': <String>[],
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
        'bootedUsers': <String>[],
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

  String? ownerBanReason(String targetId) {
    return _ownerBanReasons[targetId];
  }

  void ownerPermanentBan(
    String targetId, {
    String reason = 'Rule violation / Fraud',
  }) {
    if (!isOwner || targetId == ownerId || targetId.trim().isEmpty) {
      return;
    }

    _ownerPermanentBannedIds.add(targetId);
    _ownerBanReasons[targetId] = reason;

    streamers.removeWhere(
      (Map<String, dynamic> streamer) =>
          streamer['userId']?.toString() == targetId ||
          streamer['id']?.toString() == targetId,
    );

    notifyListeners();
  }

  void registerNewIdWithTrial({
    required String newId,
    required String name,
    required bool asStreamer,
  }) {
    final String cleanId = newId.trim();
    final String cleanName = name.trim();

    if (cleanId.isEmpty ||
        cleanName.isEmpty ||
        cleanId == ownerId ||
        isPermanentlyBannedByOwner(cleanId)) {
      return;
    }

    // A normal registration can never create or claim the Owner account.
    final DateTime expiry = DateTime.now().add(
      const Duration(days: 5),
    );

    final String autoStreamerCode = asStreamer
        ? 'ST-${Random().nextInt(89999) + 10000}'
        : '';

    currentUser = <String, dynamic>{
      'id': cleanId,
      'name': cleanName,
      'isOwner': false,
      'isVerifiedStreamer': asStreamer,
      'streamerId': autoStreamerCode,
      'level': 1,
      'sentCoins': 0,
      'coins': 5000,
      'diamonds': 0,
      'walletBalance': 0.0,
      'vipTier': 'NONE',
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
      'liveMode': 'VIDEO',
      'offlineSince': null,
    };

    backupStore.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'trial_frame_$cleanId',
        'type': 'Frame',
        'name': 'Welcome 5D Royal Frame',
        'equipped': true,
        'fromTrial': true,
        'expiresAt': expiry.toIso8601String(),
      },
      <String, dynamic>{
        'id': 'trial_entry_$cleanId',
        'type': 'Entry',
        'name': 'Welcome 5D Grand Entry',
        'equipped': true,
        'fromTrial': true,
        'expiresAt': expiry.toIso8601String(),
      },
      <String, dynamic>{
        'id': 'trial_bg_$cleanId',
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
          'Aapko 5 din ke liye Frame, Entry, SVIP aur Background trial mila hai.',
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
    final dynamic rawExpiry = currentUser['trialExpiresAt'];
    if (rawExpiry is! String || rawExpiry.isEmpty) return;

    final DateTime? expiry = DateTime.tryParse(rawExpiry);
    if (expiry == null || DateTime.now().isBefore(expiry)) return;

    if (currentUser['vipTier'] != 'NONE') {
      currentUser['vipTier'] = 'NONE';
    }

    for (final Map<String, dynamic> item in backupStore) {
      if (item['fromTrial'] == true &&
          item['id'].toString().contains(currentUser['id'].toString())) {
        item['equipped'] = false;
        item['expiredToBackup'] = true;
      }
    }

    currentUser['trialExpiresAt'] = null;
    notifyListeners();
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

    if (sentCoins <= 0) return 1;

    for (int i = 1; i < thresholds.length; i++) {
      if (sentCoins < thresholds[i]) return i;
    }

    int level = 20;
    int accumulated = thresholds.last;

    while (level < 100) {
      final int step = level < 50 ? 1500000 : 3500000;
      if (sentCoins < accumulated + step) break;
      accumulated += step;
      level++;
    }

    return min(100, level);
  }

  Map<String, dynamic> resolveColorStar(int sentCoins) {
    if (sentCoins >= 2000000) {