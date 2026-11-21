import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_entry.dart' as entry;
import 'core/app_config.dart';
import 'core/backend.dart';
import 'core/zoonl_theme.dart';
import 'profile_edit_screen.dart';
import 'user_level_screen.dart';
import 'feature_hub_screen.dart';
import 'settings_center_screen.dart';
import 'short_video_feed_screen.dart';
import 'short_video_studio_screen.dart';
import 'role_portals_screen.dart';
import 'features/pk_battle_screen.dart';
import 'features/pk_broadcast_screen.dart';
import 'lib/features/live_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Backend.initialize(
    supabaseUrl: AppConfig.supabaseUrl,
    supabaseAnonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const entry.ZoonlEntryApp());
}

class ZoonlApp extends StatelessWidget {
  const ZoonlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ZoonlTheme.dark,
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
  ZoonlAppMode appMode = ZoonlAppMode.live;

  bool get isTestMode => appMode == ZoonlAppMode.test;
  bool get isLiveMode => appMode == ZoonlAppMode.live;

  // Public ID is never proof of Owner authority.
  bool get isOwner => currentUser['isOwner'] == true;

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
  List<Map<String, dynamic>> walletTransactions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> agencyApplications =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> giftCatalog = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> cosmeticsCatalog = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> primeTiers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> userBaggage = <Map<String, dynamic>>[];
  Map<String, dynamic> userTrial = <String, dynamic>{};

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

  /// Public wrapper so UI code can refresh listeners
  /// (notifyListeners is protected outside the class).
  void refresh() => notifyListeners();

  void setAppMode(ZoonlAppMode mode) {
    if (appMode == mode) return;

    appMode = mode;
    notifyListeners();
  }

  void setAuthenticatedUser(Map<String, dynamic> user) {
    currentUser = <String, dynamic>{
      'id': user['id']?.toString() ?? '',
      'name': user['name']?.toString() ?? '',
      // Role is copied only from the server-verified Owner flag.
      'trustedRole': user['isOwner'] == true
          ? 'OWNER'
          : (user['trustedRole']?.toString() ?? 'USER'),
      'isOwner': user['isOwner'] == true,
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
    walletTransactions = <Map<String, dynamic>>[];
    agencyApplications = <Map<String, dynamic>>[];
    giftCatalog = <Map<String, dynamic>>[];
    cosmeticsCatalog = <Map<String, dynamic>>[];
    primeTiers = <Map<String, dynamic>>[];
    userBaggage = <Map<String, dynamic>>[];
    userTrial = <String, dynamic>{};
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
        'color': const Color(0xFF4BC2B0),
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
    // Only the trusted Owner or a server-approved Host may publish.
    // User level and public ZOONL ID never grant broadcast permission.
    return isOwner || currentUser['isVerifiedStreamer'] == true;
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
      if (hasVip &&
          action == 'MUTE' &&
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

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    super.dispose();
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
    final Map<String, dynamic>? welcome =
        store.pendingNewIdWelcome;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                _buildModeBanner(),
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
                    onOpenShortVideos: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ShortVideoFeedScreen(onlyMine: true),
                        ),
                      );
                    },
                    onCreateShortVideo: () async {
                      final uploaded = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const ShortVideoStudioScreen(),
                        ),
                      );
                      if (uploaded == true && mounted) setState(() {});
                    },
                    onOpenWallet: () => setState(() => bottomIndex = 2),
                    onOpenPrime: () => setState(() { bottomIndex = 0; topTabIndex = 4; }),
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

  Widget _buildModeBanner() => const SizedBox.shrink();

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
            Color(0xFF263746),
            Color(0xFF101923),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD6B46A),
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
              '${banner['senderName']} → ${banner['giftName']} → '
              '${banner['streamerName']} [${banner['streamerCrown']}]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (banner['mode'] == 'TEST')
            const Text(
              'LIVE EVENT',
              style: TextStyle(
                color: Color(0xFFB9AEFF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
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
            selectedColor: const Color(0xFF4BC2B0),
            backgroundColor: const Color(0xFF17232E),
            labelStyle: TextStyle(
              color: active
                  ? Colors.white
                  : const Color(0xFFD6B46A),
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
        (Map<String, dynamic> item) => item['isLive'] == true,
      ),
      ...store.friendsList.where(
        (Map<String, dynamic> item) => item['isLive'] == true,
      ),
    ];

    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: const Color(0xFF17232E),
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
                      color: Color(0xFFD6B46A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (liveTargets.isEmpty)
                    const Text(
                      'No live friends or assigned streamers.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    ...liveTargets.map(
                      (Map<String, dynamic> item) {
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF4BC2B0),
                            child: Icon(
                              Icons.live_tv,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            '${item['name']} (ID: ${item['id']})',
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: const Text(
                            'LIVE NOW',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              bottomIndex = 0;
                              topTabIndex = 1;
                            });
                          },
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFD6B46A),
              Color(0xFF4BC2B0),
            ],
          ),
          boxShadow: <BoxShadow>[
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
            color: const Color(0xFF17232E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD6B46A),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFD6B46A),
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                welcome['title']?.toString() ??
                    'Welcome to ZOONL LIVE',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD6B46A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                welcome['subtitle']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4BC2B0),
                ),
                onPressed: () {
                  store.pendingNewIdWelcome = null;
                  store.refresh();
                },
                child: const Text(
                  'Continue',
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
      color: const Color(0xFF101923),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.home_filled),
            onPressed: () => setState(() => bottomIndex = 0),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            onPressed: () => setState(() => bottomIndex = 1),
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
                    Color(0xFFD6B46A),
                    Color(0xFF4BC2B0),
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
            onPressed: () => setState(() => bottomIndex = 2),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () => setState(() => bottomIndex = 3),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => setState(() => bottomIndex = 4),
          ),
        ],
      ),
    );
  }

  void _openCenterLiveStartSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101923),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Start Broadcast Mode',
                style: TextStyle(
                  color: Color(0xFFD6B46A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.live_tv,
                  color: Color(0xFFD6B46A),
                ),
                title: const Text('Video Live'),
                subtitle: const Text(
                  'Owner or approved Host (18+)',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!store.canStartLive()) {
                    _showMessage(
                      'Live के लिए Owner या approved Host status जरूरी है।',
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveScreen(
                        userName: store.currentUser['name']?.toString() ?? 'ZOONL User',
                        userId: store.currentUser['id']?.toString() ?? '',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.graphic_eq,
                  color: Color(0xFF4BC2B0),
                ),
                title: const Text('Audio Room'),
                subtitle: const Text(
                  'LiveKit audio broadcast with in-room guest seats',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (!store.canStartLive()) {
                    _showMessage(
                      'Live के लिए Owner या approved Host status जरूरी है।',
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveScreen(
                        userName: store.currentUser['name']?.toString() ?? 'ZOONL User',
                        userId: store.currentUser['id']?.toString() ?? '',
                        roomType: 'audio',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.vpn_key,
                  color: Colors.amberAccent,
                ),
                title: const Text('Private Room'),
                subtitle: const Text(
                  'Secure server key and invitation required',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FeatureHubScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}


class _ProfileSocialPanel extends StatefulWidget {
  const _ProfileSocialPanel({
    required this.userId,
    required this.onOpenShortVideos,
    required this.onCreateShortVideo,
    required this.onOpenWallet,
    required this.onOpenPrime,
  });

  final String userId;
  final VoidCallback onOpenShortVideos;
  final Future<void> Function() onCreateShortVideo;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenPrime;

  @override
  State<_ProfileSocialPanel> createState() => _ProfileSocialPanelState();
}

class _ProfileSocialPanelState extends State<_ProfileSocialPanel> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ProfileSocialPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final followers = await client.from('user_follows')
        .select('id').eq('following_id', widget.userId);
    final following = await client.from('user_follows')
        .select('id').eq('follower_id', widget.userId);
    final publicProfile = await client.from('user_public_profiles')
        .select('zoonl_id')
        .eq('user_id', widget.userId)
        .maybeSingle();
    final videos = await client.from('short_videos')
        .select('id,user_id,caption,video_url,filter_name,is_filter_baked,duration_seconds,likes_count,created_at')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false)
        .limit(4);
    final publicId = publicProfile?['zoonl_id']?.toString() ?? '';
    return {
      'followers': (followers as List).length,
      'following': (following as List).length,
      'videos': (videos as List).map((row) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(row as Map),
          'zoonl_id': publicId,
        };
      }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17232E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF354653)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOCIAL PROFILE',
            style: TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile statistics could not be loaded.',
                      style: TextStyle(color: Colors.white70)),
                    TextButton.icon(
                      onPressed: () => setState(() => _future = _load()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }
              final data = snapshot.data!;
              final videos = data['videos'] as List<Map<String, dynamic>>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _socialStat('FOLLOWERS', data['followers'].toString(), Icons.people_alt_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: _socialStat('FOLLOWING', data['following'].toString(), Icons.person_add_alt_1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('MY SHORT VIDEOS',
                        style: TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold))),
                      TextButton(
                        onPressed: () async {
                          await widget.onCreateShortVideo();
                          if (mounted) setState(() => _future = _load());
                        },
                        child: const Text('CREATE'),
                      ),
                      TextButton(onPressed: widget.onOpenShortVideos, child: const Text('OPEN ALL')),
                    ],
                  ),
                  if (videos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('No uploaded Shorts yet. Your published videos will appear here.',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    )
                  else
                    ...videos.map((video) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF211735),
                        child: Icon(Icons.play_arrow, color: Color(0xFFD6B46A)),
                      ),
                      title: Text((video['caption'] ?? 'ZOONL Short').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${video['duration_seconds'] ?? 0}s • ${video['likes_count'] ?? 0} likes'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShortVideoPlayerScreen(video: video),
                        ),
                      ),
                    )),
                ],
              );
            },
          ),
          const Divider(color: Color(0xFF354653), height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.workspace_premium, color: Color(0xFFD6B46A)),
            title: const Text('Prime Membership'),
            subtitle: const Text('View active membership, tiers and benefits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onOpenPrime,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD6B46A)),
            title: const Text('Top-up & Payment History'),
            subtitle: const Text('View wallet balance, receipts and transactions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onOpenWallet,
          ),
        ],
      ),
    );
  }

  Widget _socialStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF211735),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD6B46A), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ],
          )),
        ],
      ),
    );
  }
}


class ZoonlCompleteBody extends StatefulWidget {
  final int topTabIndex;
  final int bottomIndex;
  final VoidCallback onSwitchToLive;
  final VoidCallback onOpenShortVideos;
  final Future<void> Function() onCreateShortVideo;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenPrime;

  const ZoonlCompleteBody({
    super.key,
    required this.topTabIndex,
    required this.bottomIndex,
    required this.onSwitchToLive,
    required this.onOpenShortVideos,
    required this.onCreateShortVideo,
    required this.onOpenWallet,
    required this.onOpenPrime,
  });

  @override
  State<ZoonlCompleteBody> createState() =>
      _ZoonlCompleteBodyState();
}

class _ZoonlCompleteBodyState extends State<ZoonlCompleteBody> {
  final ZoonlStore store = ZoonlStore.instance;

  bool _isStoreOwner = false;
  String _storeFilter = 'ALL';

  String selectedVideoFilter = 'VIP Velvet Glow';
  bool recordingShort = false;

  final TextEditingController shortCaptionCtrl =
      TextEditingController();

  bool micMuted = false;
  bool camMuted = false;

  String pkModeSelected = '6P';
  String historyPeriod = 'DAILY';

  String kycCountry = 'Pakistan';
  String kycDob = '';
  final TextEditingController kycLegalNameCtrl = TextEditingController();

  bool kycFrontUploaded = false;
  bool kycBackUploaded = false;
  bool kycCardSelfieUploaded = false;
  bool kycUploading = false;
  bool kycSubmitting = false;
  String? kycFrontPath;
  String? kycBackPath;
  String? kycSelfiePath;
  String? kycMessage;
  final ImagePicker _kycPicker = ImagePicker();

  bool get _isAdultForKyc {
    final dob = DateTime.tryParse(kycDob);
    if (dob == null) return false;
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  final TextEditingController payoutAccountCtrl =
      TextEditingController();

  final TextEditingController agencyTrackCtrl =
      TextEditingController();

  bool registrationSubmitted = false;
  late Future<Map<String, dynamic>?> _starSummaryFuture;
  bool aiExpanded = false;
  bool femaleVoiceEnabled = true;

  String selectedAiAnswer =
      'ZOONL LIVE Support. Select a topic below.';

  final List<Map<String, String>> aiQuickPrompts =
      <Map<String, String>>[
    <String, String>{
      'q': '65% Earning & payout rule',
      'a': 'Streamer earnings must be calculated from verified server-side gift transactions. Real payouts require an approved server ledger.',
    },
    <String, String>{
      'q': 'Direct Hosting vs Agency registration',
      'a': 'Direct hosting and agency registration require server-side application review and approval.',
    },
    <String, String>{
      'q': 'Level 1 vs Level 5 Live rule',
      'a': 'Verified Streamers may qualify at Level 1. Normal accounts need the configured minimum level.',
    },
    <String, String>{
      'q': 'Admin Mute & Blacklist rule',
      'a': 'Room moderation permissions must be checked against trusted server-side room roles.',
    },
    <String, String>{
      'q': 'Private Room',
      'a': 'Private rooms require server-generated access keys, invitations and server-side validation.',
    },
    <String, String>{
      'q': 'Crown / Demon and Color Star',
      'a': 'Stars and streamer crown levels are calculated from verified coin activity.',
    },
    <String, String>{
      'q': 'New ID trial',
      'a': 'Trial rewards must have an expiry and must not create real Coins or wallet credit.',
    },
    <String, String>{
      'q': 'Owner permanent ban',
      'a': 'Owner actions require a trusted server-side Owner role. A public account ID is not authorization.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _starSummaryFuture = _loadStarSummary();
    unawaited(_loadVipStoreData());
  }

  Future<void> _loadVipStoreData() async {
    final userId = Backend.currentUserId;
    if (userId == null) return;
    try {
      final client = Backend.client;
      final owner = await Backend.isZoonlOwner();
      final catalog = await client
          .from('zoonl_live_cosmetics')
          .select('zoonl_item_code,zoonl_item_name,item_type,media_url,sound_fx,color_theme_hex,min_level_req,coin_price,is_active,sort_order')
          .eq('project_name', 'ZOONL LIVE')
          .eq('is_active', true)
          .order('sort_order');
      final tiers = await client
          .from('prime_tiers')
          .select('id,tier_name,benefits,is_active,coin_price,duration_days')
          .eq('is_active', true)
          .order('id');
      final inventory = await client
          .from('zoonl_live_user_baggage')
          .select('id,zoonl_item_code,item_type,is_equipped,acquired_via,expires_at,created_at')
          .eq('project_name', 'ZOONL LIVE')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final prime = await client
          .from('user_prime_memberships')
          .select('id,prime_tier_id,started_at,expires_at,is_active')
          .eq('user_id', userId)
          .eq('is_active', true);
      final wallet = await client
          .from('wallets')
          .select('coins,diamonds')
          .eq('user_id', userId)
          .maybeSingle();
      final trial = await client
          .from('zoonl_user_trials')
          .select('started_at,expires_at,trial_status,svip_active')
          .eq('user_id', userId)
          .maybeSingle();
      final activeStyle = await client
          .from('zoonl_live_active_styles')
          .select('active_profile_bg_code,active_frame_code,active_entry_code,active_badge_code,active_chat_bubble_code')
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _isStoreOwner = owner;
        store.cosmeticsCatalog = (catalog as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
        store.primeTiers = (tiers as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
        store.userBaggage = (inventory as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
        store.memberships = (prime as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
        store.userTrial = trial == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(trial);
        if (activeStyle != null) {
          store.currentUser['activeProfileBgCode'] = activeStyle['active_profile_bg_code'];
          store.currentUser['activeFrameCode'] = activeStyle['active_frame_code'];
          store.currentUser['activeEntryCode'] = activeStyle['active_entry_code'];
          store.currentUser['activeBadgeCode'] = activeStyle['active_badge_code'];
          store.currentUser['activeChatBubbleCode'] = activeStyle['active_chat_bubble_code'];
        }
        if (wallet != null) {
          store.currentUser['coins'] = (wallet['coins'] as num?)?.toInt() ?? 0;
          store.currentUser['diamonds'] = (wallet['diamonds'] as num?)?.toInt() ?? 0;
        }
      });
      store.refresh();
    } catch (error) {
      _showMessage('VIP Store data could not load: $error');
    }
  }

  Future<void> _editCosmeticPrice(String itemCode, String itemName, int currentPrice) async {
    if (!_isStoreOwner) return;
    final controller = TextEditingController(text: currentPrice.toString());
    try {
      final price = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Set price • $itemName'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Coin price', helperText: 'Set 0 to make this item free'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 1000000000) return;
              Navigator.pop(dialogContext, value);
            }, child: const Text('Save price')),
          ],
        ),
      );
      if (price == null) return;
      await Backend.client.rpc('owner_set_zoonl_cosmetic_price', params: {
        'p_item_code': itemCode,
        'p_coin_price': price,
      });
      await _loadVipStoreData();
      _showMessage('$itemName price updated to $price coins.');
    } catch (error) {
      _showMessage('Price update failed: $error');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _editPrimeTierPrice(int tierId, String tierName, int currentPrice, int currentDays) async {
    if (!_isStoreOwner) return;
    final priceController = TextEditingController(text: currentPrice.toString());
    final daysController = TextEditingController(text: currentDays.toString());
    try {
      final values = await showDialog<List<int>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Configure $tierName'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: priceController, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coin price')),
            TextField(controller: daysController, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration in days')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final price = int.tryParse(priceController.text.trim());
              final days = int.tryParse(daysController.text.trim());
              if (price == null || days == null || price < 0 || price > 1000000000 || days < 1 || days > 3650) return;
              Navigator.pop(dialogContext, [price, days]);
            }, child: const Text('Save')),
          ],
        ),
      );
      if (values == null) return;
      await Backend.client.rpc('owner_set_prime_tier_price', params: {
        'p_tier_id': tierId,
        'p_coin_price': values[0],
        'p_duration_days': values[1],
      });
      await _loadVipStoreData();
      _showMessage('$tierName pricing saved.');
    } catch (error) {
      _showMessage('Prime price update failed: $error');
    } finally {
      priceController.dispose();
      daysController.dispose();
    }
  }

  Future<void> _buyPrimeTier(int tierId, String tierName) async {
    try {
      await Backend.client.rpc('buy_zoonl_prime_tier', params: {'p_tier_id': tierId});
      await _loadVipStoreData();
      _showMessage('$tierName activated on this account.');
    } catch (error) {
      _showMessage('Prime purchase failed: $error');
    }
  }

  Future<Map<String, dynamic>?> _loadStarSummary() async {
    final userId = Backend.currentUserId;
    if (userId == null) return null;
    final row = await Backend.client
        .from('streamer_gifting_summary')
        .select('daily_coins,weekly_coins,monthly_coins,star_rank')
        .eq('streamer_id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  void dispose() {
    shortCaptionCtrl.dispose();
    payoutAccountCtrl.dispose();
    agencyTrackCtrl.dispose();
    kycLegalNameCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Map<String, dynamic>? _findStreamer(String mode) {
    for (final Map<String, dynamic> streamer in store.streamers) {
      if (streamer['mode'] == mode) return streamer;
    }
    return null;
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
        return const FeatureHubScreen();
      case 1:
        return const FeatureHubScreen(roomTypeFilter: 'video');
      case 2:
        return _buildPkSection();
      case 3:
        return const FeatureHubScreen(roomTypeFilter: 'audio');
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
                children: filters.map((String filter) {
                  return ChoiceChip(
                    label: Text(filter),
                    selected: selectedVideoFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        selectedVideoFilter = filter;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: shortCaptionCtrl,
                decoration: const InputDecoration(
                  hintText: 'Video caption...',
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
                      _showMessage(
                        'Camera recording requires camera integration.',
                      );
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
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (store.isLiveMode) {
                          _showMessage(
                            'Short upload requires the production storage service.',
                          );
                          return;
                        }

                        final String caption =
                            shortCaptionCtrl.text.trim();

                        store.shortVideos.insert(
                          0,
                          <String, dynamic>{
                            'id':
                                'TEST-SV-${DateTime.now().millisecondsSinceEpoch}',
                            'author':
                                store.currentUser['name'] ?? 'Test User',
                            'authorId':
                                store.currentUser['id'] ?? '',
                            'caption': caption.isEmpty
                                ? 'Test short video'
                                : caption,
                            'filter': selectedVideoFilter,
                            'likes': 0,
                            'mode': 'TEST',
                          },
                        );

                        shortCaptionCtrl.clear();
                        store.refresh();
                        _showMessage('Short added in TEST mode.');
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Post Short'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (store.shortVideos.isEmpty)
          _emptyState(
            'No short videos yet',
            'Uploaded videos will appear here.',
          ),
        ...store.shortVideos.map((Map<String, dynamic> video) {
          return _luxuryCard(
            title:
                '${video['author']} • Filter: ${video['filter']}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child: Text('${video['caption']}')),
                TextButton.icon(
                  onPressed: () {
                    if (store.isLiveMode) {
                      _showMessage(
                        'Likes require the production backend.',
                      );
                      return;
                    }
                    video['likes'] =
                        ((video['likes'] as num?)?.toInt() ?? 0) + 1;
                    store.refresh();
                  },
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                  ),
                  label: Text('${video['likes']}'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLiveSection() {
    final Map<String, dynamic>? activeStreamer =
        _findStreamer('VIDEO');

    if (activeStreamer == null) {
      return _emptyState(
        'No video streamer available',
        'Live streamers will appear here when supplied by the server or added to the TEST session.',
      );
    }

    final Map<String, dynamic> crownInfo =
        store.resolveStreamerCrownOrDemon(
      (activeStreamer['receivedCoins'] as num?)?.toInt() ?? 0,
    );

    final Map<String, dynamic> starInfo = store.resolveColorStar(
      (store.currentUser['sentCoins'] as num?)?.toInt() ?? 0,
    );

    final List<dynamic> allGifters =
        (activeStreamer['giftersHistory'] as List<dynamic>?) ??
            <dynamic>[];

    final List<dynamic> filteredGifters = allGifters
        .where(
          (dynamic gifter) =>
              gifter is Map && gifter['period'] == historyPeriod,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title:
              '${activeStreamer['name']} (ID: ${activeStreamer['userId']}) • ${crownInfo['title']}',
          trailing: _buildThreeDotModerationButton(
            activeStreamer,
            activeStreamer['userId'].toString(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 6,
                children: <String>[
                  'DAILY',
                  'WEEKLY',
                  'MONTHLY',
                ].map((String period) {
                  return ChoiceChip(
                    label: Text(period),
                    selected: historyPeriod == period,
                    onSelected: (_) {
                      setState(() => historyPeriod = period);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                'Top 10 & All Senders ($historyPeriod): '
                '${filteredGifters.take(10).map((dynamic g) => '${g['name']} (${g['coins']})').join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD6B46A),
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
                        color: const Color(0xFF1D2B37),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD6B46A),
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
                          Text('Color Star: ${starInfo['label']}'),
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
                                onChanged: (bool value) {
                                  if (store.isLiveMode) {
                                    _showMessage(
                                      'Call settings require server authorization.',
                                    );
                                    return;
                                  }
                                  activeStreamer['videoCallOpen'] = value;
                                  store.refresh();
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
                          color: const Color(0xFF101923),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4BC2B0),
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
                              '${activeStreamer['guestName'] ?? 'No Guest'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: <String>['VIDEO', 'AUDIO']
                                      .contains(
                                activeStreamer['guestCallMode'],
                              )
                                  ? activeStreamer['guestCallMode']
                                      as String
                                  : 'VIDEO',
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
                              onChanged: (String? value) {
                                if (value == null ||
                                    store.isLiveMode) {
                                  return;
                                }
                                activeStreamer['guestCallMode'] = value;
                                store.refresh();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171D36),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9360F5).withOpacity(.5)),
                ),
                child: const Text(
                  'Camera colour filters are selected on the Pre-Live screen before Start. Face retouch controls stay hidden until they can process the outgoing LiveKit video, not just change a local slider.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              _buildGiftControls(activeStreamer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiftControls(Map<String, dynamic> streamer) {
    final gifts = store.giftCatalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Original Supabase Gift Catalog',
          style: TextStyle(
            color: Color(0xFFD6B46A),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('Available Coins: ${store.currentUser['coins'] ?? 0}'),
        const SizedBox(height: 8),
        if (gifts.isEmpty)
          const Text(
            'Active gift catalog is unavailable. Gift sending remains enabled when the server catalog is reachable.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: gifts.map((gift) {
              final name = (gift['gift_name'] ?? '').toString();
              final price = (gift['coin_price'] as num?)?.toInt() ?? 0;
              final image = (gift['image_url'] ?? gift['preview_url'] ?? '')
                  .toString();
              return OutlinedButton(
                onPressed: name.isEmpty || price <= 0
                    ? null
                    : () => _giftButton(streamer, name, price),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (image.startsWith('https://'))
                      Image.network(
                        image,
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.card_giftcard, size: 22),
                      )
                    else
                      const Icon(Icons.card_giftcard, size: 22),
                    const SizedBox(height: 3),
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$price coins',
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        if (store.isLiveMode)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Gift transactions are processed by the Supabase wallet RPC. Client balances are never edited locally.',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'TEST MODE: Gift transactions update only this test session.',
              style: TextStyle(
                color: Color(0xFFD6B46A),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _giftButton(
    Map<String, dynamic> streamer,
    String giftName,
    int coins,
  ) {
    return OutlinedButton(
      onPressed: () async {
        if (!store.isLiveMode) {
          final bool sent = store.sendGift(
            streamer: streamer,
            giftName: giftName,
            giftCoins: coins,
          );
          _showMessage(
            sent
                ? '$giftName sent in TEST mode.'
                : 'Insufficient test Coins or invalid test session.',
          );
          return;
        }

        final String roomId = (streamer['roomId'] ?? '').toString();
        if (roomId.isEmpty) {
          _showMessage('This streamer has no active Supabase live room.');
          return;
        }

        try {
          final gift = await Backend.client
              .from('gifts')
              .select('id, coin_price')
              .eq('gift_name', giftName)
              .eq('is_active', true)
              .maybeSingle();

          if (gift == null) {
            _showMessage('$giftName is not in the active Supabase gift catalog.');
            return;
          }

          final result = await Backend.client.rpc(
            'send_live_gift',
            params: <String, dynamic>{
              'p_gift_id': gift['id'],
              'p_room_id': roomId,
              'p_quantity': 1,
            },
          );

          final wallet = await Backend.client
              .from('wallets')
              .select('coins, diamonds')
              .eq('user_id', Backend.currentUserId!)
              .maybeSingle();

          if (wallet != null) {
            store.currentUser['coins'] =
                (wallet['coins'] as num?)?.toInt() ?? 0;
            store.currentUser['diamonds'] =
                (wallet['diamonds'] as num?)?.toInt() ?? 0;
            store.refresh();
          }
          _showMessage('$giftName sent successfully from the Supabase wallet.');
        } catch (error) {
          _showMessage('Gift failed: $error');
        }
      },
      child: Text('$giftName • $coins'),
    );
  }

  Widget _buildPkSection() => const PkBroadcastScreen();

  Widget _buildAudioSection() {
    // Audio is a broadcast room, not a separate phone-call flow.
    // Reuse the same Supabase + LiveKit room lifecycle, guest invitations,
    // seats, moderation and gifting as the video-live experience.
    return const FeatureHubScreen(roomTypeFilter: 'audio');
  }

  Future<void> _refreshCosmeticsData() async {
    final userId = Backend.currentUserId;
    if (userId == null) return;
    try {
      final rows = await Backend.client
          .from('zoonl_live_user_baggage')
          .select('id, zoonl_item_code, item_type, is_equipped, acquired_via, expires_at, created_at')
          .eq('project_name', 'ZOONL LIVE')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      store.userBaggage = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final wallet = await Backend.client
          .from('wallets')
          .select('coins, diamonds')
          .eq('user_id', userId)
          .maybeSingle();
      if (wallet != null) {
        store.currentUser['coins'] =
            (wallet['coins'] as num?)?.toInt() ?? 0;
        store.currentUser['diamonds'] =
            (wallet['diamonds'] as num?)?.toInt() ?? 0;
      }
      final activeStyle = await Backend.client
          .from('zoonl_live_active_styles')
          .select('active_profile_bg_code,active_frame_code,active_entry_code,active_badge_code,active_chat_bubble_code')
          .eq('user_id', userId)
          .maybeSingle();
      if (activeStyle != null) {
        store.currentUser['activeProfileBgCode'] = activeStyle['active_profile_bg_code'];
        store.currentUser['activeFrameCode'] = activeStyle['active_frame_code'];
        store.currentUser['activeEntryCode'] = activeStyle['active_entry_code'];
        store.currentUser['activeBadgeCode'] = activeStyle['active_badge_code'];
        store.currentUser['activeChatBubbleCode'] = activeStyle['active_chat_bubble_code'];
      }
      store.refresh();
    } catch (error) {
      _showMessage('Supabase inventory refresh failed: $error');
    }
  }

  Future<void> _buyCosmetic(String itemCode, String itemName) async {
    try {
      await Backend.client.rpc(
        'buy_zoonl_cosmetic',
        params: <String, dynamic>{'p_item_code': itemCode},
      );
      await _refreshCosmeticsData();
      _showMessage('$itemName added to your ZOONL LIVE inventory.');
    } catch (error) {
      _showMessage('Purchase not completed: $error');
    }
  }

  Future<void> _equipCosmetic(String itemCode, String itemName) async {
    try {
      await Backend.equipZoonlCosmetic(itemCode: itemCode);
      await _refreshCosmeticsData();
      _showMessage('$itemName equipped.');
    } catch (error) {
      _showMessage('Could not equip item: $error');
    }
  }

  Widget _buildVipHubSection() {
    final ownedCodes = store.userBaggage
        .where((item) {
          final expiry = item['expires_at'];
          final validExpiry = expiry == null ||
              (DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) ??
                  false);
          return validExpiry;
        })
        .map((item) => item['zoonl_item_code']?.toString() ?? '')
        .toSet();

    final equippedCodes = store.userBaggage.where((item) {
      if (item['is_equipped'] != true) return false;
      final expiry = item['expires_at'];
      return expiry == null ||
          (DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) ?? false);
    }).map((item) => item['zoonl_item_code']?.toString() ?? '').toSet();

    final activePrime = store.memberships.where((item) {
      if (item['is_active'] != true) return false;
      final expiry = item['expires_at'];
      return expiry == null ||
          (DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) ?? false);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title: 'Prime Membership',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(activePrime.isEmpty
                  ? 'No active Prime membership on this account.'
                  : 'Active Prime memberships: ${activePrime.length}'),
              if (store.userTrial.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    store.userTrial['trial_status'] == 'active' &&
                            store.userTrial['svip_active'] == true
                        ? 'SVIP Trial ACTIVE • expires ${store.userTrial['expires_at']}'
                        : 'SVIP Trial EXPIRED • trial cosmetics are in Backup',
                    style: const TextStyle(
                        color: Color(0xFFD6B46A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),
              ...store.primeTiers.map((tier) {
                final tierId = (tier['id'] as num?)?.toInt() ?? 0;
                final tierName = (tier['tier_name'] ?? 'Prime').toString();
                final price = (tier['coin_price'] as num?)?.toInt() ?? 0;
                final days = (tier['duration_days'] as num?)?.toInt() ?? 30;
                final benefits = tier['benefits'];
                final active = activePrime.any((m) =>
                    (m['prime_tier_id'] as num?)?.toInt() == tierId &&
                    (m['expires_at'] == null ||
                     (DateTime.tryParse(m['expires_at'].toString())?.isAfter(DateTime.now()) ?? false)));
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.workspace_premium, color: Color(0xFFB9AEFF)),
                  title: Text(tierName),
                  subtitle: Text('${price} coins • $days days • ' + (benefits is Map
                      ? benefits.entries.map((e) => '${e.key}: ${e.value}').join(' • ')
                      : 'Tier $tierId')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_isStoreOwner) IconButton(
                      tooltip: 'Owner: edit Prime price and duration',
                      icon: const Icon(Icons.edit, color: Color(0xFF8CEBFF), size: 18),
                      onPressed: () => _editPrimeTierPrice(tierId, tierName, price, days),
                    ),
                    if (active)
                      const Chip(label: Text('ACTIVE'), visualDensity: VisualDensity.compact)
                    else
                      TextButton(
                        onPressed: () => _buyPrimeTier(tierId, tierName),
                        child: const Text('BUY'),
                      ),
                  ]),
                );
              }),
              const SizedBox(height: 4),
              const Text(
                "Prime purchases debit wallet Coins on the server and activate a time-limited membership. The Owner controls each tier's price and duration.",
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
        _luxuryCard(
          title: 'ZOONL LIVE Frames • Entries • Backgrounds',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Coins: ${store.currentUser['coins'] ?? 0} • Owned items: ${ownedCodes.length}',
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final category in ['ALL', 'AVATAR_FRAME', 'ENTRY_EFFECT', 'PROFILE_BG', 'ID_BADGE', 'CHAT_BUBBLE'])
                  ChoiceChip(
                    label: Text(category == 'ALL' ? 'All' : category.replaceAll('_', ' ')),
                    selected: _storeFilter == category,
                    onSelected: (_) => setState(() => _storeFilter = category),
                  ),
              ]),
              if (_isStoreOwner)
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('OWNER CONTROL: change each item price below. Updates are verified by Supabase.',
                    style: TextStyle(color: Color(0xFF8CEBFF), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 8),
              if (store.cosmeticsCatalog.isEmpty)
                const Text('No active cosmetics are available from Supabase.')
              else
                ...store.cosmeticsCatalog.where((item) =>
                  _storeFilter == 'ALL' || item['item_type']?.toString() == _storeFilter
                ).map((item) {
                  final code = (item['zoonl_item_code'] ?? '').toString();
                  final name = (item['zoonl_item_name'] ?? 'Cosmetic').toString();
                  final type = (item['item_type'] ?? '').toString();
                  final price = (item['coin_price'] as num?)?.toInt() ?? 0;
                  final owned = ownedCodes.contains(code);
                  final equipped = equippedCodes.contains(code);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome,
                        color: Color(0xFFD6B46A)),
                    title: Text(name),
                    subtitle: Text(
                      '$type • ${price == 0 ? 'Reward / Owner item' : '$price coins'}',
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_isStoreOwner)
                        IconButton(
                          tooltip: 'Owner: change item price',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit, color: Color(0xFF8CEBFF), size: 18),
                          onPressed: code.isEmpty ? null : () => _editCosmeticPrice(code, name, price),
                        ),
                      if (equipped)
                        const Text('EQUIPPED', style: TextStyle(color: Color(0xFF8CEBFF), fontSize: 10))
                      else
                        OutlinedButton(
                          onPressed: code.isEmpty ? null : () => owned
                              ? _equipCosmetic(code, name)
                              : _buyCosmetic(code, name),
                          child: Text(owned ? 'Equip' : 'Buy'),
                        ),
                    ]),
                  );
                }),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _loadVipStoreData,
                icon: const Icon(Icons.sync),
                label: const Text('Refresh Store & Inventory'),
              ),
            ],
          ),
        ),
        _luxuryCard(
          title: 'VIP INVENTORY & BACKUP STORE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Current VIP: ${store.currentUser['vipTier']} • Coins: ${store.currentUser['coins']}',
              ),
              const SizedBox(height: 8),
              const Text(
                'VIP/SVIP real-money checkout is not enabled. No payment is taken here. Prime tiers above can be purchased only with existing wallet Coins.',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              if (store.userBaggage.isEmpty)
                const Text(
                  'No owned cosmetics in Supabase inventory.',
                  style: TextStyle(color: Colors.white60),
                ),
              ...store.userBaggage.map((item) {
                final code = (item['zoonl_item_code'] ?? '').toString();
                final catalogItem = store.cosmeticsCatalog.firstWhere(
                  (catalog) =>
                      catalog['zoonl_item_code']?.toString() == code,
                  orElse: () => <String, dynamic>{},
                );
                final trialName = <String, String>{
                  'ZOONL_TRIAL_FRAME_5D': 'New ID Trial Frame (5 Days)',
                  'ZOONL_TRIAL_ENTRY_5D': 'New ID Trial Entry (5 Days)',
                  'ZOONL_TRIAL_BACKGROUND_5D': 'New ID Trial Background (5 Days)',
                }[code];
                final name =
                    (catalogItem['zoonl_item_name'] ?? trialName ?? code).toString();
                final expiry = item['expires_at']?.toString();
                final expiryDate = expiry == null ? null : DateTime.tryParse(expiry);
                final expired = expiryDate != null && expiryDate.isBefore(DateTime.now());
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    expired
                        ? 'Expired • moved to Backup'
                        : expiry == null ? 'Permanent item' : 'Expires: $expiry',
                  ),
                  trailing: expired
                      ? const Text(
                          'BACKUP',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        )
                      : item['is_equipped'] == true
                          ? const Text(
                              'EQUIPPED',
                              style: TextStyle(color: Color(0xFFD6B46A), fontSize: 10),
                            )
                          : OutlinedButton(
                              onPressed: code.isEmpty
                                  ? null
                                  : () => _equipCosmetic(code, name),
                              child: const Text('Equip'),
                            ),
                );
              }),
            ],
          ),
        ),
        _luxuryCard(
          title: 'Private Rooms',
          child: Column(
            children: store.privateRooms.map(
              (Map<String, dynamic> room) {
                return ListTile(
                  leading: const Icon(
                    Icons.lock,
                    color: Color(0xFFD6B46A),
                  ),
                  title: Text('Private Room ${room['roomId']}'),
                  subtitle: const Text(
                    'Room key and access must be verified by the server.',
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
    if (store.inboxMessages.isEmpty) {
      return _emptyState(
        'Inbox is empty',
        'New messages and room invitations will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: store.inboxMessages.map(
        (Map<String, dynamic> message) {
          return _luxuryCard(
            title:
                'From: ${message['from']} (ID: ${message['fromId']})',
            child: Row(
              children: <Widget>[
                Expanded(child: Text('${message['text']}')),
                if (message['privateKey'] != null)
                  ElevatedButton(
                    onPressed: widget.onSwitchToLive,
                    child: const Text('Open Room'),
                  ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  Future<void> _pickKycDocument(String kind) async {
    if (registrationSubmitted || kycUploading) return;
    if (!_isAdultForKyc) {
      _showMessage('Host verification documents are available only after adult eligibility is confirmed.');
      return;
    }
    try {
      final picked = await _kycPicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked == null) return;
      final userId = Backend.currentUserId;
      if (userId == null) throw StateError('Login required.');
      setState(() { kycUploading = true; kycMessage = null; });
      final localFile = File(picked.path);
      if (await localFile.length() > 20 * 1024 * 1024) {
        throw StateError('Each KYC image must be smaller than 20 MB.');
      }
      final path = '$userId/host-kyc/$kind-${DateTime.now().microsecondsSinceEpoch}.jpg';
      await Backend.client.storage.from('host-kyc-private').upload(
        path,
        localFile,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
      if (!mounted) return;
      setState(() {
        if (kind == 'id-front') {
          kycFrontPath = path;
          kycFrontUploaded = true;
        } else if (kind == 'id-back') {
          kycBackPath = path;
          kycBackUploaded = true;
        } else {
          kycSelfiePath = path;
          kycCardSelfieUploaded = true;
        }
        kycMessage = '$kind uploaded securely.';
      });
    } catch (error) {
      if (mounted) setState(() => kycMessage = 'KYC upload failed: $error');
    } finally {
      if (mounted) setState(() => kycUploading = false);
    }
  }


  Future<void> _pickKycDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your real date of birth',
    );
    if (picked != null && mounted) {
      setState(() => kycDob =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Widget _kycDocumentCard({
    required String title,
    required String guidance,
    required IconData icon,
    required bool uploaded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF211735),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: uploaded ? const Color(0xFF4BC2B0) : const Color(0xFF6C4A82)),
      ),
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF34234A),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFFD6B46A), size: 31),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(guidance, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ])),
        const SizedBox(width: 6),
        Icon(uploaded ? Icons.check_circle : Icons.upload_file,
          color: uploaded ? const Color(0xFF4BC2B0) : const Color(0xFFD6B46A)),
        IconButton(
          tooltip: 'Choose from gallery',
          onPressed: kycUploading || registrationSubmitted ? null : onTap,
          icon: const Icon(Icons.photo_library_outlined, color: Color(0xFFD6B46A)),
        ),
      ]),
    );
  }

  Future<void> _submitKyc() async {
    if (registrationSubmitted || kycSubmitting) return;
    final dob = DateTime.tryParse(kycDob);
    if (!_isAdultForKyc || dob == null) {
      _showMessage('Host verification is only available to adults aged 18 or above.');
      return;
    }
    if (kycLegalNameCtrl.text.trim().length < 3) {
      _showMessage('Enter your legal name and real date of birth first.');
      return;
    }
    if (kycFrontPath == null || kycBackPath == null || kycSelfiePath == null) {
      _showMessage('Upload ID front, ID back and selfie with ID first.');
      return;
    }
    setState(() { kycSubmitting = true; kycMessage = null; });
    try {
      await Backend.client.rpc(
        'submit_host_verification',
        params: <String, dynamic>{
          'p_legal_name': kycLegalNameCtrl.text.trim(),
          'p_date_of_birth': kycDob,
          'p_country': kycCountry,
          'p_id_front_path': kycFrontPath,
          'p_id_back_path': kycBackPath,
          'p_selfie_with_id_path': kycSelfiePath,
        },
      );
      if (!mounted) return;
      setState(() {
        registrationSubmitted = true;
        kycMessage = 'Host verification submitted. Waiting for Owner review.';
      });
    } catch (error) {
      if (mounted) setState(() => kycMessage = 'Submission failed: $error');
    } finally {
      if (mounted) setState(() => kycSubmitting = false);
    }
  }

  Widget _walletBalanceTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF211735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C4A82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD6B46A), size: 20),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWalletAndEarningScreen() {
    final int coins =
        (store.currentUser['coins'] as num?)?.toInt() ?? 0;
    final int diamonds =
        (store.currentUser['diamonds'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _luxuryCard(
          title: 'Wallet • Live Supabase Balance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: _walletBalanceTile('COINS', coins.toString(), Icons.monetization_on)),
                  const SizedBox(width: 8),
                  Expanded(child: _walletBalanceTile('DIAMONDS', diamonds.toString(), Icons.diamond)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Balances are loaded from the authenticated wallet record. Coin additions and gift deductions are written by secured Supabase functions.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        _luxuryCard(
          title: 'STREAMER STAR RANK',
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _starSummaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gift-based star summary is unavailable.',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                    TextButton.icon(
                      onPressed: () => setState(() => _starSummaryFuture = _loadStarSummary()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('RETRY'),
                    ),
                  ],
                );
              }
              final data = snapshot.data ?? <String, dynamic>{};
              final rank = (data['star_rank'] ?? 'NO STAR').toString();
              final stars = rank.startsWith('5') ? 5
                  : rank.startsWith('4') ? 4
                  : rank.startsWith('3') ? 3
                  : rank.startsWith('2') ? 2
                  : rank.startsWith('1') ? 1 : 0;
              final daily = (data['daily_coins'] as num?)?.toInt() ?? 0;
              final weekly = (data['weekly_coins'] as num?)?.toInt() ?? 0;
              final monthly = (data['monthly_coins'] as num?)?.toInt() ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List<Widget>.generate(5, (index) => Icon(
                      index < stars ? Icons.star : Icons.star_border,
                      color: const Color(0xFFD6B46A),
                      size: 25,
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(rank, style: const TextStyle(
                    color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Daily $daily')),
                      Chip(label: Text('Weekly $weekly')),
                      Chip(label: Text('Monthly $monthly')),
                    ],
                  ),
                  const Text('Ranks are calculated from verified gifts received. They do not change wallet balances.',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _starSummaryFuture = _loadStarSummary()),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('REFRESH'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _luxuryCard(
          title: 'Top-up Status',
          child: const Text(
            'New coin purchases are currently disabled while the app\'s paid-entry game economy is reviewed. Existing wallet balances and transaction history remain visible.',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
        _luxuryCard(
          title: 'Wallet Transaction History',
          child: store.walletTransactions.isEmpty
              ? const Text('No wallet transactions found for this account.',
                  style: TextStyle(color: Colors.white60))
              : Column(
                  children: store.walletTransactions.take(20).map((tx) {
                    final rawAmount = (tx['amount'] as num?)?.toInt() ?? 0;
                    final type = (tx['transaction_type'] ?? 'transaction').toString();
                    final outgoing = type.contains('sent') ||
                        type.contains('purchase') ||
                        type.contains('withdrawal') ||
                        type.contains('spend');
                    final amount = outgoing ? -rawAmount.abs() : rawAmount.abs();
                    final currency = (tx['currency'] ?? '').toString().toUpperCase();
                    final description = (tx['description'] ?? '').toString();
                    final created = (tx['created_at'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                        color: amount >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      title: Text(
                        '${amount >= 0 ? '+' : ''}$amount $currency',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$type • $description\n$created',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
        ),
        _luxuryCard(
          title: 'Earning Folder — Direct / Agency Registration',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: registrationSubmitted ? null : _pickKycDateOfBirth,
                icon: const Icon(Icons.calendar_month),
                label: Text(kycDob.isEmpty ? 'SELECT DATE OF BIRTH' : 'DATE OF BIRTH: $kycDob'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Host verification and creator payouts are strictly for adults aged 18+. Document upload stays locked until adult eligibility is confirmed.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
              if (_isAdultForKyc) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: kycLegalNameCtrl,
                  enabled: !registrationSubmitted,
                  decoration: const InputDecoration(labelText: 'Legal name as shown on ID'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: kycCountry,
                  items: const <String>[
                    'United Arab Emirates',
                    'Saudi Arabia',
                    'Qatar',
                    'Kuwait',
                    'Bahrain',
                    'Oman',
                    'Pakistan',
                    'India',
                    'Bangladesh',
                    'United Kingdom',
                    'United States',
                    'Other',
                  ].map((String country) => DropdownMenuItem<String>(
                    value: country, child: Text(country),
                  )).toList(),
                  onChanged: (String? value) => setState(() => kycCountry = value ?? 'United Arab Emirates'),
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                const Text('DOCUMENT PHOTO GUIDE', style: TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                _kycDocumentCard(
                  title: '1. ID Front Side',
                  guidance: 'Keep the full front side visible, sharp and without glare.',
                  icon: Icons.credit_card,
                  uploaded: kycFrontUploaded,
                  onTap: () => _pickKycDocument('id-front'),
                ),
                _kycDocumentCard(
                  title: '2. ID Back Side',
                  guidance: 'Show the complete reverse side and all readable details.',
                  icon: Icons.badge_outlined,
                  uploaded: kycBackUploaded,
                  onTap: () => _pickKycDocument('id-back'),
                ),
                _kycDocumentCard(
                  title: '3. Selfie With ID',
                  guidance: 'Face and ID should both be clearly visible in one photo.',
                  icon: Icons.face_retouching_natural,
                  uploaded: kycCardSelfieUploaded,
                  onTap: () => _pickKycDocument('selfie-with-id'),
                ),
              ] else
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF211735),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFF6C4A82)),
                  ),
                  child: Text(
                    kycDob.isEmpty
                        ? 'Select your date of birth to check eligibility. No identity documents are requested at this stage.'
                        : 'This feature is available only to adults aged 18 or above. Identity document uploads are unavailable for under-18 accounts.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              if (kycMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(kycMessage!, style: const TextStyle(color: Color(0xFFD6B46A), fontSize: 11)),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: kycUploading || kycSubmitting ? null : _submitKyc,
                icon: const Icon(Icons.verified_user),
                label: Text(kycSubmitting ? 'Submitting...' : registrationSubmitted ? 'Verification Submitted' : 'SUBMIT HOST VERIFICATION'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payout account linking will be connected through an approved payment provider. Do not enter bank passwords, card security codes or full card details in this form.',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: agencyTrackCtrl,
                enabled: !registrationSubmitted,
                decoration: const InputDecoration(
                  labelText: 'Optional Agency / Track Number',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AgencyPortalScreen()),
                ),
                icon: const Icon(Icons.business_center),
                label: const Text('OPEN AGENCY REGISTRATION PORTAL'),
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
              color: const Color(0xFF1D2B37),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFD6B46A),
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
                          color: Color(0xFFD6B46A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          aiExpanded
                              ? 'ZOONL AI Assistant'
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
                        onChanged: (bool value) {
                          setState(() {
                            femaleVoiceEnabled = value;
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
                          color: Color(0xFFD6B46A),
                        ),
                        onTap: () {
                          setState(() {
                            selectedAiAnswer = item['a'] ?? '';
                          });
                        },
                      );
                    },
                  ),
                  const Text(
                    'Voice playback requires voice-service integration.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
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

  List<Color> _cosmeticGradientColors(String? raw) {
    final colors = <Color>[];
    for (final part in (raw ?? '').split(',')) {
      final hex = part.trim().replaceFirst('#', '');
      if (hex.length != 6) continue;
      try {
        colors.add(Color(int.parse('FF$hex', radix: 16)));
      } catch (_) {}
    }
    if (colors.length < 2) {
      return const [Color(0xFF29365E), Color(0xFF34245B), Color(0xFF153E4C)];
    }
    return colors.take(3).toList();
  }

  Widget _buildProfileAndSettingsScreen() {
    final bool isLive = store.currentUser['isLive'] == true;
    final String displayName =
        (store.currentUser['name'] ?? 'ZOONL User').toString();
    final String userId = (store.currentUser['id'] ?? '').toString();
    final String country =
        (store.currentUser['country'] ?? 'Not set').toString();
    final String bio = (store.currentUser['bio'] ?? '').toString();
    final String avatarUrl =
        (store.currentUser['avatarUrl'] ?? '').toString();
    final String profileBackgroundUrl =
        (store.currentUser['profileBackgroundUrl'] ?? '').toString();
    final activeBgCode = store.currentUser['activeProfileBgCode']?.toString() ?? '';
    final activeFrameCode = store.currentUser['activeFrameCode']?.toString() ?? '';
    Map<String, dynamic>? activeBgItem;
    Map<String, dynamic>? activeFrameItem;
    for (final item in store.cosmeticsCatalog) {
      if (item['zoonl_item_code']?.toString() == activeBgCode) activeBgItem = item;
      if (item['zoonl_item_code']?.toString() == activeFrameCode) activeFrameItem = item;
    }
    final hasEquippedBg = activeBgItem != null && store.userBaggage.any((item) {
      if (item['zoonl_item_code']?.toString() != activeBgCode || item['is_equipped'] != true) return false;
      final expiry = item['expires_at'];
      return expiry == null || (DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) ?? false);
    });
    final activeBgUrl = hasEquippedBg ? (activeBgItem?['media_url']?.toString() ?? '') : '';
    final effectiveBgUrl = activeBgUrl.startsWith('http') ? activeBgUrl : profileBackgroundUrl;
    final hasPremiumBg = hasEquippedBg;
    final hasEquippedFrame = activeFrameItem != null && store.userBaggage.any((item) {
      if (item['zoonl_item_code']?.toString() != activeFrameCode || item['is_equipped'] != true) return false;
      final expiry = item['expires_at'];
      return expiry == null || (DateTime.tryParse(expiry.toString())?.isAfter(DateTime.now()) ?? false);
    });
    final profileBgColors = _cosmeticGradientColors(activeBgItem?['color_theme_hex']?.toString());
    final frameColors = _cosmeticGradientColors(activeFrameItem?['color_theme_hex']?.toString());

    Future<void> openProfileEditor() async {
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const ProfileEditScreen(),
        ),
      );
      if (saved == true && mounted) {
        try {
          final authId = Backend.currentUserId;
          if (authId != null) {
            final profile = await Backend.client.from('profiles')
                .select('display_name,country,bio,avatar_url,profile_background_url,user_level')
                .eq('id', authId).maybeSingle();
            if (profile != null) {
              store.currentUser['name'] = profile['display_name'] ?? store.currentUser['name'];
              store.currentUser['country'] = profile['country'] ?? '';
              store.currentUser['bio'] = profile['bio'] ?? '';
              store.currentUser['avatarUrl'] = profile['avatar_url'] ?? '';
              store.currentUser['profileBackgroundUrl'] = profile['profile_background_url'] ?? '';
              store.currentUser['level'] = profile['user_level'] ?? store.currentUser['level'] ?? 1;
              store.refresh();
            }
          }
          _showMessage('Profile saved and refreshed.');
        } catch (error) {
          _showMessage('Profile saved. Refresh could not load: $error');
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        if (effectiveBgUrl.startsWith('http') || hasPremiumBg)
          Container(
            height: 136,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: profileBgColors),
              borderRadius: BorderRadius.circular(18),
              image: effectiveBgUrl.startsWith('http')
                  ? DecorationImage(
                      image: NetworkImage(effectiveBgUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(.32), BlendMode.darken),
                    )
                  : null,
              border: Border.all(color: const Color(0xFF8CEBFF).withOpacity(.7)),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(16),
            child: Text(
              hasPremiumBg
                  ? 'PROFILE BACKGROUND • ${activeBgItem?['zoonl_item_name'] ?? 'PREMIUM'}'
                  : 'PROFILE BACKGROUND',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        _luxuryCard(
          title: 'MY ZOONL PROFILE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 82,
                    height: 82,
                    padding: EdgeInsets.all(hasEquippedFrame ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasEquippedFrame ? LinearGradient(colors: frameColors) : null,
                      border: hasEquippedFrame
                          ? Border.all(color: const Color(0xFF8CEBFF), width: 1)
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF293B49),
                      backgroundImage: avatarUrl.startsWith('http') ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.startsWith('http')
                          ? null
                          : const Icon(Icons.person, size: 36, color: Color(0xFFB9AEFF)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Color(0xFFD6B46A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('User ID: ${userId.isEmpty ? 'Not assigned' : userId}'),
                        Text(
                          isLive ? 'LIVE NOW' : 'OFFLINE',
                          style: TextStyle(
                            color: isLive ? Colors.greenAccent : Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: openProfileEditor,
                    icon: const Icon(Icons.edit, color: Color(0xFFD6B46A)),
                  ),
                ],
              ),
              const Divider(height: 24),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const UserLevelScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF29365E), Color(0xFF141E35)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9B8CFF).withOpacity(.65)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFFB9AEFF), Color(0xFF58D6CE)]),
                        ),
                        child: Center(
                          child: Text(
                            '${store.currentUser['level'] ?? 1}',
                            style: const TextStyle(color: Color(0xFF10182E), fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ACCOUNT LEVEL', style: TextStyle(color: Color(0xFFC7D3F4), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            Text('LEVEL ${store.currentUser['level'] ?? 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            Text('VIP ${store.currentUser['vipTier'] ?? 'NONE'} • View level ladder',
                              style: const TextStyle(color: Color(0xFFB9C7E8), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFB9AEFF)),
                    ],
                  ),
                ),
              ),
              if (store.currentUser['activeBadgeCode']?.toString() == 'ZOONL_LUCKY_ID_01')
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF29365E), Color(0xFF34245B), Color(0xFF153E4C)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8CEBFF), width: 1.2),
                    boxShadow: [BoxShadow(color: const Color(0xFF8CEBFF).withOpacity(.12), blurRadius: 12)],
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF8CEBFF)),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ZOONL LUCKY ID', style: TextStyle(color: Color(0xFF8CEBFF), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                      Text(userId.isEmpty ? 'ID pending' : userId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                    ])),
                    const Icon(Icons.verified, color: Color(0xFF8CEBFF)),
                  ]),
                ),
              if ((store.currentUser['activeEntryCode'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('Room entry equipped: ${store.currentUser['activeEntryCode']}',
                    style: const TextStyle(color: Color(0xFFB9AEFF), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              _profileInfoRow(Icons.flag_outlined, 'Country', country),
              _profileInfoRow(Icons.info_outline, 'Bio',
                  bio.isEmpty ? 'Add a short introduction' : bio),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: openProfileEditor,
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('EDIT PROFILE'),
                ),
              ),
            ],
          ),
        ),
        _ProfileSocialPanel(
          userId: Backend.currentUserId ?? '',
          onOpenShortVideos: widget.onOpenShortVideos,
          onCreateShortVideo: widget.onCreateShortVideo,
          onOpenWallet: widget.onOpenWallet,
          onOpenPrime: widget.onOpenPrime,
        ),
        _luxuryCard(
          title: 'ACCOUNT & PRIVACY SETTINGS',
          child: Column(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: Color(0xFFD6B46A)),
                title: const Text('Profile information'),
                subtitle: const Text('Photo, display name, country and bio'),
                trailing: const Icon(Icons.chevron_right),
                onTap: openProfileEditor,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Friend list visibility'),
                subtitle: const Text('Choose whether your friend list is public'),
                value: store.currentUser['friendListPublic'] == true,
                onChanged: (bool value) {
                  if (store.isLiveMode) {
                    _showMessage('Privacy changes need verified server support.');
                    return;
                  }
                  store.currentUser['friendListPublic'] = value;
                  store.refresh();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: Color(0xFFD6B46A)),
                title: const Text('Linked accounts'),
                subtitle: Text(
                  (store.currentUser['linkedAccounts'] as List<dynamic>? ??
                          <dynamic>[])
                      .join(', ')
                      .isEmpty
                      ? 'Email / phone / social accounts'
                      : (store.currentUser['linkedAccounts'] as List<dynamic>).join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMessage(
                  'Account linking is managed through secure authentication settings.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security, color: Color(0xFFD6B46A)),
                title: const Text('Settings Center'),
                subtitle: const Text('Account, privacy, notifications and appearance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsCenterScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFFD6B46A)),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildThreeDotModerationButton(
    Map<String, dynamic> streamer,
    String targetUserId,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (String action) {
        if (store.isLiveMode) {
          _showMessage(
            'Moderation in LIVE mode requires server authorization.',
          );
          return;
        }

        final List<dynamic> admins =
            streamer['roomAdmins'] as List<dynamic>? ??
                <dynamic>[];

        store.moderateUser(
          streamer: streamer,
          targetUserId: targetUserId,
          action: action,
          actorIsStreamer:
              store.currentUser['id']?.toString() ==
                  streamer['userId']?.toString(),
          actorIsAdmin: admins
              .map((dynamic id) => id.toString())
              .contains(
                store.currentUser['id']?.toString(),
              ),
          actorVipTier:
              store.currentUser['vipTier']?.toString() ?? 'NONE',
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

  Widget _emptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _luxuryCard(
          title: title,
          child: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
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
        color: const Color(0xFF17232E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF354653),
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
                    color: Color(0xFFD6B46A),
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