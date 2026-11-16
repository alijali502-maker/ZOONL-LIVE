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
  void checkTrialExpiryAndMoveToBackup() {
    final dynamic rawExpiry = currentUser['trialExpiresAt'];
    if (rawExpiry is! String || rawExpiry.isEmpty) return;

    final DateTime? expiry = DateTime.tryParse(rawExpiry);
    if (expiry == null || DateTime.now().isBefore(expiry)) return;

    currentUser['vipTier'] = 'NONE';

    for (final Map<String, dynamic> item in backupStore) {
      if (item['fromTrial'] == true &&
          item['id'].toString().contains(
                currentUser['id'].toString(),
              )) {
        item['equipped'] = false;
        item['expiredToBackup'] = true;
      }
    }

    currentUser['trialExpiresAt'] = null;
    notifyListeners();
  }

  int resolveUserLevel(int sentCoins) {
    const List<int> thresholds = <int>[
      0, 50000, 100000, 160000, 230000,
      310000, 400000, 500000, 620000, 750000,
      1000000, 1300000, 1600000, 1900000, 2200000,
      2700000, 3200000, 3700000, 4200000, 4700000,
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

  Map<String, dynamic> resolveStreamerCrownOrDemon(
    int sentCoins,
  ) {
    if (sentCoins < 30000) {
      return <String, dynamic>{
        'kind': 'HEART',
        'count': 1,
        'title': 'Mini Heart',
        'color': const Color(0xFFFF5C8A),
      };
    }

    if (sentCoins < 150000) {
      final int demonCount = sentCoins < 80000 ? 1 : 2;
      return <String, dynamic>{
        'kind': 'DEMON',
        'count': demonCount,
        'title': '$demonCount Demon',
        'color': const Color(0xFFFF3D57),
      };
    }

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

    return <String, dynamic>{
      'kind': 'CROWN',
      'count': min(40, crown),
      'title': '$crown Crown',
      'color': const Color(0xFFFFD700),
    };
  }

  // Local gift accounting is permitted only in clearly marked TEST mode.
  // LIVE mode must use a trusted server transaction/RPC.
  bool sendGift({
    required Map<String, dynamic> streamer,
    required String giftName,
    required int giftCoins,
  }) {
    if (!isTestMode) return false;

    final String senderId =
        currentUser['id']?.toString() ?? '';

    if (senderId.isEmpty ||
        giftName.trim().isEmpty ||
        giftCoins <= 0 ||
        isPermanentlyBannedByOwner(senderId) ||
        !streamers.contains(streamer)) {
      return false;
    }

    final int currentCoins =
        (currentUser['coins'] as num?)?.toInt() ?? 0;

    if (currentCoins < giftCoins) return false;

    currentUser['coins'] = currentCoins - giftCoins;

    final int senderSentCoins =
        (currentUser['sentCoins'] as num?)?.toInt() ?? 0;
    currentUser['sentCoins'] = senderSentCoins + giftCoins;
    currentUser['level'] =
        resolveUserLevel(senderSentCoins + giftCoins);

    final int received =
        (streamer['receivedCoins'] as num?)?.toInt() ?? 0;
    streamer['receivedCoins'] = received + giftCoins;

    final int daily =
        (streamer['dailyReceiving'] as num?)?.toInt() ?? 0;
    streamer['dailyReceiving'] = daily + giftCoins;

    final double payoutGain = giftCoins * 0.65 / 100.0;
    final double streamerBalance =
        (streamer['walletBalance'] as num?)?.toDouble() ?? 0.0;
    streamer['walletBalance'] = streamerBalance + payoutGain;

    final List<Map<String, dynamic>> history = _convertMaps(
      (streamer['giftersHistory'] as List<dynamic>?) ??
          <dynamic>[],
    );

    history.insert(0, <String, dynamic>{
      'userId': senderId,
      'name': currentUser['name']?.toString() ?? 'User',
      'coins': giftCoins,
      'period': 'DAILY',
      'createdAt': DateTime.now().toIso8601String(),
      'mode': 'TEST',
    });

    streamer['giftersHistory'] = history;

    final Map<String, dynamic> crownInfo =
        resolveStreamerCrownOrDemon(received + giftCoins);

    final Map<String, dynamic> banner = <String, dynamic>{
      'senderName': currentUser['name'],
      'senderLevel': currentUser['level'],
      'giftName': giftName,
      'streamerName': streamer['name'],
      'streamerCrown': crownInfo['title'],
      'crownColor': crownInfo['color'],
      'mode': 'TEST',
    };

    if (activeGlobalGiftBanner == null) {
      activeGlobalGiftBanner = banner;
    } else {
      _giftTickerQueue.add(banner);
    }

    notifyListeners();
    return true;
  }

  // Test Coins are explicitly marked test credits, never real currency.
  bool addTestCoins(int amount) {
    if (!isTestMode || amount <= 0) return false;

    final int currentCoins =
        (currentUser['coins'] as num?)?.toInt() ?? 0;
    currentUser['coins'] = currentCoins + amount;
    notifyListeners();
    return true;
  }

  bool canStartLive() {
    if (isOwner) return true;
    if (currentUser['isVerifiedStreamer'] == true) return true;
    return ((currentUser['level'] as num?)?.toInt() ?? 1) >= 5;
  }

  void toggleLiveStatus({
    required bool goLive,
    String mode = 'VIDEO',
  }) {
    if (goLive && !canStartLive()) return;

    final String safeMode =
        mode.toUpperCase() == 'AUDIO' ? 'AUDIO' : 'VIDEO';

    currentUser['isLive'] = goLive;
    currentUser['liveMode'] = safeMode;
    currentUser['offlineSince'] =
        goLive ? null : DateTime.now();

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
    if (targetUserId.trim().isEmpty ||
        targetUserId == streamer['userId']?.toString()) {
      return;
    }

    final bool owner = isOwner;
    final bool streamerOwner =
        currentUser['id']?.toString() ==
            streamer['userId']?.toString();

    final List<dynamic> admins =
        streamer['roomAdmins'] as List<dynamic>? ?? <dynamic>[];

    final bool verifiedRoomAdmin = admins
        .map((dynamic id) => id.toString())
        .contains(currentUser['id']?.toString());

    final bool canActAsStreamer = owner || streamerOwner;
    final bool canActAsAdmin =
        !canActAsStreamer && verifiedRoomAdmin && actorIsAdmin;

    final List<String> muted = List<String>.from(
      (streamer['mutedUsers'] as List<dynamic>?) ?? <dynamic>[],
    );
    final List<String> blacklist = List<String>.from(
      (streamer['blacklist'] as List<dynamic>?) ?? <dynamic>[],
    );
    final List<String> booted = List<String>.from(
      (streamer['bootedUsers'] as List<dynamic>?) ?? <dynamic>[],
    );

    if (canActAsStreamer) {
      switch (action) {
        case 'MUTE':
          if (!muted.contains(targetUserId)) muted.add(targetUserId);
          break;
        case 'UNMUTE':
          muted.remove(targetUserId);
          break;
        case 'BLACKLIST':
          if (!blacklist.contains(targetUserId)) {
            blacklist.add(targetUserId);
          }
          break;
        case 'BOOT':
          if (!booted.contains(targetUserId)) {
            booted.add(targetUserId);
          }
          break;
      }
    } else if (canActAsAdmin) {
      final bool hasVip =
          actorVipTier == 'VIP' || actorVipTier == 'SVIP';
      if (hasVip && action == 'MUTE' &&
          !muted.contains(targetUserId)) {
        muted.add(targetUserId);
      } else if (hasVip && action == 'UNMUTE') {
        muted.remove(targetUserId);
      }
    }

    streamer['mutedUsers'] = muted;
    streamer['blacklist'] = blacklist;
    streamer['bootedUsers'] = booted;
    notifyListeners();
  }

  void disposeStore() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    super.dispose();
  }
}
enum ZoonlAppMode {
  test,
  live,
}

class ZoonlStore extends ChangeNotifier {
  static final ZoonlStore instance = ZoonlStore._internal();

  ZoonlStore._internal() {
    _initDefaults();
    _startGlobalTicker();
  }

  static const String ownerId = '10001';

  // TEST is the safe initial mode. LIVE transactions require server integration.
  ZoonlAppMode appMode = ZoonlAppMode.test;

  bool get isTestMode => appMode == ZoonlAppMode.test;
  bool get isLiveMode => appMode == ZoonlAppMode.live;

  // Public ID is never proof of Owner authority.
  bool get isOwner => currentUser['trustedRole'] == 'OWNER';

  bool get canUseLocalTestTransactions => isTestMode;

  Map<String, dynamic> currentUser = <String, dynamic>{
    'id': '',
    'name': '',
    'trustedRole': 'USER',
    'isVerifiedStreamer': false,
    'streamerId': '',
    'level': 1,
    'sentCoins': 0,
    'coins': 0,
    'diamonds': 0,
    'walletBalance': 0.0,
    'vipTier': 'NONE',
    'isNewId': false,
    'trialExpiresAt': null,
    'friendListPublic': true,
    'linkedAccounts': <String>[],
    'payoutLocked': true,
    'payoutMethod': '',
    'payoutAccount': '',
    'registrationType': 'USER',
    'approved': false,
    'isLive': false,
    'liveMode': 'VIDEO',
    'offlineSince': null,
  };

  final Set<String> _ownerPermanentBannedIds = <String>{};
  final Map<String, String> _ownerBanReasons = <String, String>{};

  final Map<String, Map<String, dynamic>> adminAccounts =
      <String, Map<String, dynamic>>{};

  List<Map<String, dynamic>> memberships = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> agencyApplications =
      <Map<String, dynamic>>[];

  String officialHostingEmail = 'hosting@zoonllive.com';
  String officialHostingContact = '';
  String supportEmail = 'support@zoonllive.com';
  String supportContact = '';

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
      <Map<String, dynamic>>[];

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

  void setAppMode(ZoonlAppMode mode) {
    if (appMode == mode) return;

    appMode = mode;
    notifyListeners();
  }

  void setAuthenticatedUser(Map<String, dynamic> user) {
    currentUser = <String, dynamic>{
      'id': user['id']?.toString() ?? '',
      'name': user['name']?.toString() ?? '',
      'trustedRole': user['trustedRole']?.toString() ?? 'USER',
      'isVerifiedStreamer': user['isVerifiedStreamer'] == true,
      'streamerId': user['streamerId']?.toString() ?? '',
      'level': (user['level'] as num?)?.toInt() ?? 1,
      'sentCoins': (user['sentCoins'] as num?)?.toInt() ?? 0,
      'coins': (user['coins'] as num?)?.toInt() ?? 0,
      'diamonds': (user['diamonds'] as num?)?.toInt() ?? 0,
      'walletBalance':
          (user['walletBalance'] as num?)?.toDouble() ?? 0.0,
      'vipTier': user['vipTier']?.toString() ?? 'NONE',
      'isNewId': user['isNewId'] == true,
      'trialExpiresAt': user['trialExpiresAt'],
      'friendListPublic': user['friendListPublic'] != false,
      'linkedAccounts':
          List<String>.from(user['linkedAccounts'] ?? <String>[]),
      'payoutLocked': user['payoutLocked'] != false,
      'payoutMethod': user['payoutMethod']?.toString() ?? '',
      'payoutAccount': user['payoutAccount']?.toString() ?? '',
      'registrationType':
          user['registrationType']?.toString() ?? 'USER',
      'approved': user['approved'] == true,
      'isLive': user['isLive'] == true,
      'liveMode': user['liveMode']?.toString() ?? 'VIDEO',
      'offlineSince': user['offlineSince'],
    };

    notifyListeners();
  }

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
    // No sample users, fake Coins, fake gifts, or fabricated wallet records.
    // TEST mode uses only explicitly entered test data.
    memberships = <Map<String, dynamic>>[];
    agencyApplications = <Map<String, dynamic>>[];
    streamers.clear();
    shortVideos.clear();
    privateRooms.clear();
    inboxMessages.clear();
    friendsList.clear();
    adminAssignedStreamers.clear();
    backupStore.clear();
  }

  void _startGlobalTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(
      const Duration(seconds: 5),
      (Timer timer) {
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

    final DateTime expiry =
        DateTime.now().add(const Duration(days: 5));

    final String autoStreamerCode = asStreamer
        ? 'ST-${Random().nextInt(89999) + 10000}'
        : '';

    currentUser = <String, dynamic>{
      'id': cleanId,
      'name': cleanName,
      'trustedRole': 'USER',
      'isVerifiedStreamer': asStreamer,
      'streamerId': autoStreamerCode,
      'level': 1,
      'sentCoins': 0,
      'coins': 0,
      'diamonds': 0,
      'walletBalance': 0.0,
      'vipTier': 'NONE',
      'isNewId': true,
      'trialExpiresAt': expiry.toIso8601String(),
      'friendListPublic': true,
      'linkedAccounts': <String>[],
      'payoutLocked': true,
      'payoutMethod': '',
      'payoutAccount': '',
      'registrationType': asStreamer ? 'DIRECT' : 'USER',
      'approved': false,
      'isLive': false,
      'liveMode': 'VIDEO',
      'offlineSince': null,
    };

    pendingNewIdWelcome = <String, dynamic>{
      'title': 'ZOONL LIVE Welcome',
      'subtitle': 'Your account trial is active for 5 days.',
      'items': <String>[
        '5D Frame',
        '5D Special Entry',
        '5D SVIP',
        '5D Background Aura',
      ],
    };

    notifyListeners();
  }