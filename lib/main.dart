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