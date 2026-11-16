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
tickerTimer = Timer.periodic(
const Duration(seconds: 5),
() {
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

void sendGift({
required Map<String, dynamic> streamer,
required String giftName,
required int giftCoins,
}) {
final String senderId = currentUser['id']?.toString() ?? '';

if (senderId.isEmpty ||  
    giftName.trim().isEmpty ||  
    giftCoins <= 0 ||  
    isPermanentlyBannedByOwner(senderId)) {  
  return;  
}  

if (!streamers.contains(streamer)) return;  

final int currentCoins =  
    (currentUser['coins'] as num?)?.toInt() ?? 0;  

// Owner's unlimited balance is a privilege, not a fake wallet credit.  
if (!isOwner) {  
  if (currentCoins < giftCoins) return;  
  currentUser['coins'] = currentCoins - giftCoins;  
}  

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

// Only the receiving streamer receives the earning balance.  
final double payoutGain = giftCoins * 0.65 / 100.0;  
final double streamerBalance =  
    (streamer['walletBalance'] as num?)?.toDouble() ?? 0.0;  
streamer['walletBalance'] = streamerBalance + payoutGain;  

final List<Map<String, dynamic>> history =  
    _convertMaps(  
  (streamer['giftersHistory'] as List<dynamic>?) ?? <dynamic>[],  
);  

history.insert(0, <String, dynamic>{  
  'userId': senderId,  
  'name': currentUser['name']?.toString() ?? 'User',  
  'coins': giftCoins,  
  'period': 'DAILY',  
  'createdAt': DateTime.now().toIso8601String(),  
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
};  

if (activeGlobalGiftBanner == null) {  
  activeGlobalGiftBanner = banner;  
} else {  
  _giftTickerQueue.add(banner);  
}  

notifyListeners();

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

final String safeMode = mode.toUpperCase() == 'AUDIO'  
    ? 'AUDIO'  
    : 'VIDEO';  

currentUser['isLive'] = goLive;  
currentUser['liveMode'] = safeMode;  
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
if (targetUserId.trim().isEmpty ||
targetUserId == streamer['userId']?.toString()) {
return;
}

final bool owner = isOwner;  
final bool streamerOwner =  
    currentUser['id']?.toString() ==  
    streamer['userId']?.toString();  

// Do not trust a caller-supplied streamer flag by itself.  
final bool canActAsStreamer = owner || streamerOwner;  
final bool canActAsAdmin = actorIsAdmin &&  
    ((streamer['roomAdmins'] as List<dynamic>?)  
            ?.map((dynamic id) => id.toString())  
            .contains(currentUser['id']?.toString()) ??  
        false);  

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
      if (!booted.contains(targetUserId)) booted.add(targetUserId);  
      break;  
  }  
} else if (canActAsAdmin) {  
  final bool hasVip =  
      actorVipTier == 'VIP' || actorVipTier == 'SVIP';  
  if (hasVip && action == 'MUTE' && !muted.contains(targetUserId)) {  
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
margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
'Lv.${banner['senderLevel']} ${banner['senderName']} → '
'${banner['giftName']} → ${banner['streamerName']} '
'[${banner['streamerCrown']}]',
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
        onSelected: (_) => setState(() => topTabIndex = index),  
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
                      style: TextStyle(color: Color(0xFF00E676)),  
                    ),  
                    onTap: () {  
                      Navigator.pop(context);  
                      setState(() {  
                        bottomIndex = 0;  
                        topTabIndex = 1;  
                      });  
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
        BoxShadow(color: Colors.black54, blurRadius: 8),  
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
welcome['title']?.toString() ?? 'Welcome to ZOONL LIVE',
style: const TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
color: Color(0xFFE6C47A),
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
Color(0xFFE6C47A),
Color(0xFF7C4DFF),
],
),
borderRadius: BorderRadius.circular(24),
),
child: const Row(
children: <Widget>[
Icon(Icons.videocam, color: Colors.black, size: 20),
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
icon: const Icon(Icons.account_balance_wallet_outlined),
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
backgroundColor: const Color(0xFF140E28),
builder: (BuildContext sheetContext) {
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
title: const Text('1. Live Section (Video Broadcast)'),
subtitle: const Text(
'Verified Streamer Lv.1+ | Normal User Lv.5+',
),
onTap: () {
Navigator.pop(sheetContext);
if (!store.canStartLive()) {
_showMessage('Live ke liye Level 5 ya verified streamer status chahiye.');
return;
}
store.toggleLiveStatus(goLive: true, mode: 'VIDEO');
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
title: const Text('2. Audio Section (6 / 8 Seats)'),
subtitle: const Text(
'Streamer + / Call Join Accept-Reject Control',
),
onTap: () {
Navigator.pop(sheetContext);
if (!store.canStartLive()) {
_showMessage('Live ke liye Level 5 ya verified streamer status chahiye.');
return;
}
store.toggleLiveStatus(goLive: true, mode: 'AUDIO');
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
title: const Text('3. Private Room (Key + Inbox Invite)'),
subtitle: const Text(
'Private Room service connection required',
),
onTap: () {
Navigator.pop(sheetContext);
_showMessage(
'Private Room abhi secure server key service se connected nahi hai. Local key create nahi ki gayi.',
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
TextEditingController(text: 'EasyPaisa - 03001234567');

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
'Streamer ko gift value ka 65% earning calculation ke mutabiq milta hai. Real payout ke liye server-side ledger aur approved payout system zaroori hai.',
},
<String, String>{
'q': 'Direct Hosting vs Agency/Track registration?',
'a':
'Direct hosting ya agency route ke liye KYC aur payout details submit hoti hain. Approval server par verify hona chahiye.',
},
<String, String>{
'q': 'Level 1 vs Level 5 Live rule kya hai?',
'a':
'Verified Streamer Level 1 se live aa sakta hai, jabke normal user ko live broadcast ke liye kam az kam Level 5 chahiye.',
},
<String, String>{
'q': 'Admin Mute & Blacklist ka rule?',
'a':
'Streamer Mute, Unmute, Blacklist aur Boot kar sakta hai. Streamer ka Admin VIP/SVIP hone par Mute aur Unmute kar sakta hai.',
},
<String, String>{
'q': 'Private Room kaise kaam karta hai?',
'a':
'Private Room ke liye secure server-generated key, invitation aur server-side validation zaroori hai.',
},
<String, String>{
'q': 'Crown / Demon aur Color Star kaise badalte hain?',
'a':
'10k=1 Star, 50k=2 Star, 200k=3 Star, 1M=4 Star, 2M=Big Star. Streamer par Heart/Demon aur phir Crown level apply hota hai.',
},
<String, String>{
'q': 'New ID 5-Day Trial ka kya hota hai?',
'a':
'Nayi ID ko 5 din ke liye trial rewards diye ja sakte hain. Expiry ke baad trial rewards disable hone chahiye.',
},
<String, String>{
'q': 'Owner 10001 Permanent Ban kaise kaam karta hai?',
'a':
'Permanent ban sirf trusted Owner permission ke zariye server par apply hona chahiye. Public ID akeli authority ka proof nahi hai.',
},
];

@override
void dispose() {
shortCaptionCtrl.dispose();
payoutAccountCtrl.dispose();
agencyTrackCtrl.dispose();
super.dispose();
}

void _showMessage(String message) {
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
if (widget.bottomIndex == 2) return _buildWalletAndEarningScreen();
if (widget.bottomIndex == 3) return _buildSupportAiScreen();
if (widget.bottomIndex == 4) return _buildProfileAndSettingsScreen();

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
            children: filters.map((String filter) {  
              return ChoiceChip(  
                label: Text(filter),  
                selected: selectedVideoFilter == filter,  
                onSelected: (_) {  
                  setState(() => selectedVideoFilter = filter);  
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
                  setState(() => recordingShort = !recordingShort);  
                  _showMessage(  
                    'Camera recording service abhi connect nahi hai. Yeh sirf UI state hai.',  
                  );  
                },  
                icon: Icon(  
                  recordingShort ? Icons.stop : Icons.fiber_manual_record,  
                ),  
                label: Text(  
                  recordingShort ? 'Stop Recording' : 'Record Video',  
                ),  
              ),  
              const SizedBox(width: 10),  
              Expanded(  
                child: FilledButton.icon(  
                  onPressed: () {  
                    final String caption =  
                        shortCaptionCtrl.text.trim();  

                    store.shortVideos.insert(  
                      0,  
                      <String, dynamic>{  
                        'id': 'SV-${DateTime.now().millisecondsSinceEpoch}',  
                        'author': store.currentUser['name'],  
                        'authorId': store.currentUser['id'],  
                        'caption': caption.isEmpty  
                            ? 'New ZOONL Short'  
                            : caption,  
                        'filter': selectedVideoFilter,  
                        'likes': 0,  
                      },  
                    );  

                    shortCaptionCtrl.clear();  
                    store.notifyListeners();  
                    _showMessage(  
                      'Short local demo list mein add hui hai. Server upload abhi connected nahi.',  
                    );  
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
    ...store.shortVideos.map((Map<String, dynamic> video) {  
      return _luxuryCard(  
        title: '${video['author']} • Filter: ${video['filter']}',  
        child: Row(  
          mainAxisAlignment: MainAxisAlignment.spaceBetween,  
          children: <Widget>[  
            Expanded(child: Text('${video['caption']}')),  
            TextButton.icon(  
              onPressed: () {  
                video['likes'] =  
                    ((video['likes'] as num?)?.toInt() ?? 0) + 1;  
                store.notifyListeners();  
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
    'Jab koi video streamer live hoga, woh yahan nazar aayega.',  
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

final List<dynamic> filteredGifters = allGifters.where(  
  (dynamic gifter) => gifter is Map &&  
      gifter['period'] == historyPeriod,  
).toList();  

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
            children: <String>['DAILY', 'WEEKLY', 'MONTHLY']  
                .map((String period) {  
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,  
                    children: <Widget>[  
                      Text(  
                        'Streamer Live (${camMuted ? "Cam Off" : "Cam On"} • ${micMuted ? "Mic Off" : "Mic On"})',  
                        style: const TextStyle(  
                          fontWeight: FontWeight.bold,  
                        ),  
                      ),  
                      Text('Color Star: ${starInfo['label']}'),  
                      Row(  
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,  
                        children: <Widget>[  
                          IconButton(  
                            icon: Icon(  
                              micMuted ? Icons.mic_off : Icons.mic,  
                            ),  
                            onPressed: () {  
                              setState(() => micMuted = !micMuted);  
                            },  
                          ),  
                          IconButton(  
                            icon: Icon(  
                              camMuted  
                                  ? Icons.videocam_off  
                                  : Icons.videocam,  
                            ),  
                            onPressed: () {  
                              setState(() => camMuted = !camMuted);  
                            },  
                          ),  
                          Switch(  
                            value: activeStreamer['videoCallOpen'] == true,  
                            onChanged: (bool value) {  
                              activeStreamer['videoCallOpen'] = value;  
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,  
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
                          value: <String>['VIDEO', 'AUDIO'].contains(  
                            activeStreamer['guestCallMode'],  
                          )  
                              ? activeStreamer['guestCallMode'] as String  
                              : 'VIDEO',  
                          items: const <DropdownMenuItem<String>>[  
                            DropdownMenuItem(  
                              value: 'VIDEO',  
                              child: Text('Video Call'),  
                            ),  
                            DropdownMenuItem(  
                              value: 'AUDIO',  
                              child: Text('Audio Call'),  
                            ),  
                          ],  
                          onChanged: (String? value) {  
                            if (value == null) return;  
                            activeStreamer['guestCallMode'] = value;  
                            store.notifyListeners();  
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
            'VIP Beauty Filter Controls (UI only)',  
            style: TextStyle(  
              color: Color(0xFFE6C47A),  
              fontWeight: FontWeight.bold,  
            ),  
          ),  
          Slider(  
            value: skinSmooth,  
            onChanged: (double value) {  
              setState(() => skinSmooth = value);  
            },  
          ),  
          Slider(  
            value: faceSize,  
            onChanged: (double value) {  
              setState(() => faceSize = value);  
            },  
          ),  
          Slider(  
            value: eyeSize,  
            onChanged: (double value) {  
              setState(() => eyeSize = value);  
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
              _showMessage(  
                'Local gift demo updated. Real coin transaction and animation require backend integration.',  
              );  
            },  
            icon: const Icon(Icons.card_giftcard),  
            label: const Text('Send Demo Gift (200k Coins)'),  
          ),  
        ],  
      ),  
    ),  
  ],  
);

}

Widget _buildPkSection() {
final int slots = pkModeSelected == '6P'
? 6
: pkModeSelected == '4GRID'
? 4
: pkModeSelected == '3P'
? 3
: 2;

return ListView(  
  padding: const EdgeInsets.all(12),  
  children: <Widget>[  
    _luxuryCard(  
      title: 'PK Battle Arena (6P • 3P • 2P • Friend Train • 4-Grid)',  
      child: Column(  
        crossAxisAlignment: CrossAxisAlignment.start,  
        children: <Widget>[  
          Wrap(  
            spacing: 8,  
            children: <String>['6P', '3P', '2P', 'TRAIN', '4GRID']  
                .map((String mode) {  
              return ChoiceChip(  
                label: Text(mode),  
                selected: pkModeSelected == mode,  
                onSelected: (_) {  
                  setState(() => pkModeSelected = mode);  
                },  
              );  
            }).toList(),  
          ),  
          const SizedBox(height: 10),  
          Text('Selected PK Mode: $pkModeSelected'),  
          const SizedBox(height: 8),  
          Wrap(  
            spacing: 8,  
            runSpacing: 8,  
            children: List<Widget>.generate(slots, (int index) {  
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
                child: Text('Slot ${index + 1} ($pkModeSelected)'),  
              );  
            }),  
          ),  
          const SizedBox(height: 8),  
          const Text(  
            'PK invitations, live score sync and participant connections are not connected in this local screen.',  
            style: TextStyle(color: Colors.white70, fontSize: 12),  
          ),  
        ],  
      ),  
    ),  
  ],  
);

}

Widget _buildAudioSection() {
final Map<String, dynamic>? audioRoom = _findStreamer('AUDIO');

if (audioRoom == null) {  
  return _emptyState(  
    'No audio room available',  
    'Jab koi audio streamer live hoga, woh yahan nazar aayega.',  
  );  
}  

final List<Map<String, dynamic>> seats =  
    (audioRoom['seats'] as List<dynamic>? ?? <dynamic>[])  
        .whereType<Map>()  
        .map((Map seat) => Map<String, dynamic>.from(seat))  
        .toList();  

final List<dynamic> requests =  
    audioRoom['pendingCallRequests'] as List<dynamic>? ??  
        <dynamic>[];  

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
                  audioRoom['plusOpen'] != true;  
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
                  audioRoom['callRequestOpen'] != true;  
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
            itemBuilder: (_, int index) {  
              final Map<String, dynamic> seat = seats[index];  
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
          ...requests.map((dynamic request) {  
            if (request is! Map) return const SizedBox.shrink();  

            return ListTile(  
              title: Text(  
                'Call Join Request: ${request['name']}',  
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
                      final List<dynamic> current =  
                          audioRoom['pendingCallRequests']  
                              as List<dynamic>;  
                      current.remove(request);  
                      _showMessage(  
                        'Request accepted locally. LiveKit seat connection is not yet attached.',  
                      );  
                      store.notifyListeners();  
                    },  
                  ),  
                  IconButton(  
                    icon: const Icon(  
                      Icons.cancel,  
                      color: Colors.redAccent,  
                    ),  
                    onPressed: () {  
                      (audioRoom['pendingCallRequests']  
                              as List<dynamic>)  
                          .remove(request);  
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
_showMessage(
'VIP/SVIP payment service connected nahi hai. Payment ke baghair VIP activate nahi kiya jayega.',
);
},
child: const Text('VIP / SVIP Top-Up'),
),
const SizedBox(height: 8),
...store.backupStore.map((Map<String, dynamic> item) {
return ListTile(
title: Text('${item['name']} (${item['type']})'),
trailing: Switch(
value: item['equipped'] == true,
onChanged: (bool value) {
item['equipped'] = value;
store.notifyListeners();
},
),
);
}),
],
),
),
_luxuryCard(
title: 'Private Rooms (Secure Server Connection Required)',
child: Column(
children: store.privateRooms.map(
(Map<String, dynamic> room) {
return ListTile(
leading: const Icon(
Icons.lock,
color: Color(0xFFE6C47A),
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

Widget _buildWalletAndEarningScreen() {
final int nowDay = DateTime.now().day;
final bool inPayoutWindow = nowDay >= 1 && nowDay <= 5;

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
            'Streamer Wallet Balance: \$'  
            '${((store.currentUser['walletBalance'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',  
          ),  
          Text(  
            inPayoutWindow  
                ? 'Payout Window Open (1–5 Tareekh).'  
                : 'Payout Window: Mahina khatam hone ke baad 1 se 5 tareekh tak.',  
            style: const TextStyle(color: Color(0xFFE6C47A)),  
          ),  
          const SizedBox(height: 6),  
          const Text(  
            'Displayed balance is local demo data. Actual payout requires server ledger verification.',  
            style: TextStyle(fontSize: 11, color: Colors.white60),  
          ),  
        ],  
      ),  
    ),  
    _luxuryCard(  
      title: 'Earning Folder — Direct / Agency Registration',  
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
            ].map((String country) {  
              return DropdownMenuItem<String>(  
                value: country,  
                child: Text(country),  
              );  
            }).toList(),  
            onChanged: (String? value) {  
              setState(() => kycCountry = value ?? 'Pakistan');  
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
                onPressed: () => _showMessage(  
                  'ID Front upload ke liye secure file picker/storage integration chahiye. Abhi file upload nahi hui.',  
                ),  
                child: Text(  
                  kycFrontUploaded ? 'Front ID ✓' : 'Upload ID Front',  
                ),  
              ),  
              OutlinedButton(  
                onPressed: () => _showMessage(  
                  'ID Back upload ke liye secure file picker/storage integration chahiye. Abhi file upload nahi hui.',  
                ),  
                child: Text(  
                  kycBackUploaded ? 'Back ID ✓' : 'Upload ID Back',  
                ),  
              ),  
              OutlinedButton(  
                onPressed: () => _showMessage(  
                  'Card selfie upload ke liye secure file picker/storage integration chahiye. Abhi file upload nahi hui.',  
                ),  
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
              labelText: 'Mobile Wallet / Bank Account',  
            ),  
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
          ElevatedButton(  
            onPressed: registrationSubmitted  
                ? null  
                : () {  
                    if (payoutAccountCtrl.text.trim().isEmpty) {  
                      _showMessage('Payout account enter karein.');  
                      return;  
                    }  
                    _showMessage(  
                      'KYC application backend se connected nahi hai. Abhi details submit ya lock nahi hui.',  
                    );  
                  },  
            child: Text(  
              registrationSubmitted  
                  ? 'Registration Submitted'  
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
onTap: () => setState(() => aiExpanded = !aiExpanded),
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
mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
? 'ZOONL AI Assistant'
: 'AI Support (Tap to Open)',
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),
],
),
Icon(
aiExpanded ? Icons.expand_less : Icons.expand_more,
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
setState(() => femaleVoiceEnabled = value);
},
),
],
),
Text(
selectedAiAnswer,
style: const TextStyle(color: Colors.white),
),
const SizedBox(height: 10),
...aiQuickPrompts.map((Map<String, String> item) {
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
}),
const Text(
'Voice playback is not connected in this file.',
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
Text('Official Hosting Email: ${store.officialHostingEmail}'),
Text('Official Hosting Contact: ${store.officialHostingContact}'),
],
),
),
],
);
}

Widget _buildProfileAndSettingsScreen() {
final bool isOwner = store.isOwner;
final bool isLive = store.currentUser['isLive'] == true;
final dynamic offlineValue = store.currentUser['offlineSince'];
final DateTime? offlineSince =
offlineValue is DateTime ? offlineValue : null;

final List<dynamic> linkedAccounts =  
    store.currentUser['linkedAccounts'] as List<dynamic>? ??  
        <dynamic>[];  

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
                : 'Status: OFFLINE ${offlineSince != null ? "(Since ${offlineSince.hour}:${offlineSince.minute.toString().padLeft(2, '0')})" : ""}',  
            style: TextStyle(  
              color: isLive ? Colors.greenAccent : Colors.orangeAccent,  
            ),  
          ),  
          SwitchListTile(  
            title: const Text('Friend List Public / Private'),  
            value: store.currentUser['friendListPublic'] == true,  
            onChanged: (bool value) {  
              store.currentUser['friendListPublic'] = value;  
              store.notifyListeners();  
            },  
          ),  
          Text('Linked Accounts: ${linkedAccounts.join(", ")}'),  
        ],  
      ),  
    ),  
    if (isOwner)  
      _luxuryCard(  
        title: 'Owner 10001 Sovereign Control',  
        child: Column(  
          crossAxisAlignment: CrossAxisAlignment.start,  
          children: <Widget>[  
            const Text(  
              'Owner identity: trusted role flag required. Public ID alone is not authorization.',  
            ),  
            const SizedBox(height: 8),  
            ElevatedButton.icon(  
              onPressed: () {  
                store.ownerPermanentBan(  
                  '99901',  
                  reason: 'Permanent Streamer/Fraud Ban by Owner',  
                );  
                _showMessage('Owner ban request processed locally.');  
              },  
              icon: const Icon(Icons.gpp_bad),  
              label: const Text('Permanent Ban (Owner Only)'),  
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
final List<dynamic> admins =
streamer['roomAdmins'] as List<dynamic>? ?? <dynamic>[];

store.moderateUser(  
      streamer: streamer,  
      targetUserId: targetUserId,  
      action: action,  
      actorIsStreamer:  
          store.currentUser['id']?.toString() ==  
          streamer['userId']?.toString(),  
      actorIsAdmin: admins  
          .map((dynamic id) => id.toString())  
          .contains(store.currentUser['id']?.toString()),  
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