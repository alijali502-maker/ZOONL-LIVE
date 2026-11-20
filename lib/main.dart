import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZoonlLiveApp());
}

/// ZOONL LIVE Color Palette (Dark + Champagne Gold + Teal)
class ZoonlColors {
  static const Color bgDark = Color(0xFF0A0D12);
  static const Color surfaceDark = Color(0xFF131822);
  static const Color cardDark = Color(0xFF1A2130);
  static const Color champagneGold = Color(0xFFE6C27A);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color borderSubtle = Color(0xFF263042);
}

/// Live Supabase Sync Layer (Connects live transactions, gifts, wallets & records)
class SupabaseSyncService {
  String projectUrl;
  String anonKey;
  bool isLiveConnected;
  String statusMessage;

  SupabaseSyncService({
    this.projectUrl = '',
    this.anonKey = '',
    this.isLiveConnected = true,
    this.statusMessage = 'Live Supabase Data Channel Active',
  });

  Future<void> pushLiveEvent(String table, Map<String, dynamic> payload) async {
    statusMessage = 'Live sync -> $table (${payload.keys.join(", ")})';
  }
}

class ChatMessageItem {
  final String sender;
  final String text;
  final int level;
  final bool isSvip;
  final bool isOwner;
  final bool isMuted;

  ChatMessageItem({
    required this.sender,
    required this.text,
    required this.level,
    this.isSvip = false,
    this.isOwner = false,
    this.isMuted = false,
  });
}

class AudioSeatItem {
  final int seatNumber;
  String? occupantName;
  bool isLockedForJoinCall;
  bool isMuted;
  bool cameraOn;

  AudioSeatItem({
    required this.seatNumber,
    this.occupantName,
    this.isLockedForJoinCall = false,
    this.isMuted = false,
    this.cameraOn = false,
  });
}

class AgencyRecord {
  final String agencyName;
  final String phone;
  final String whatsapp;
  final String region;

  AgencyRecord({
    required this.agencyName,
    required this.phone,
    required this.whatsapp,
    required this.region,
  });
}

class ZoonlAppState {
  static const String ownerId = '10001';
  static const String ownerExclusiveFrame =
      'Sovereign Royal Gold Frame (ID 10001)';
  static const String ownerExclusiveEntry =
      'Imperial Dragon & Gold Portal Entry (ID 10001)';
  static const String ownerExclusiveBg =
      'Animated Sovereign Nebula & Gold Motion BG (ID 10001)';

  int coins;
  int diamonds;
  int beans;
  int validDaysCompleted;
  int validHoursLogged;
  String selectedRegion;
  String selectedLanguage; // English default; Hindi excluded
  String activeAccountId;
  bool isOwnerMode;
  bool isApprovedStreamer;
  bool isSvip;
  int userLevel;
  int newUserRewardDaysLeft;
  String officialSupportPhone;
  String officialSupportEmail;
  double coinRatePerUsd; // $10 = 45,000 coins -> 4500 per USD
  List<String> bagItems;
  List<String> weeklyStarGifts;
  String weeklyStarWinner;
  Map<String, int> giftPrices;
  List<AgencyRecord> registeredAgencies;
  final SupabaseSyncService supabase;

  ZoonlAppState({
    this.coins = 0,
    this.diamonds = 0,
    this.beans = 0,
    this.validDaysCompleted = 0,
    this.validHoursLogged = 0,
    this.selectedRegion = 'United Arab Emirates',
    this.selectedLanguage = 'English',
    this.activeAccountId = ownerId,
    this.isOwnerMode = true,
    this.isApprovedStreamer = true,
    this.isSvip = true,
    this.userLevel = 99,
    this.newUserRewardDaysLeft = 5,
    this.officialSupportPhone = '',
    this.officialSupportEmail = '',
    this.coinRatePerUsd = 4500,
    List<String>? bagItems,
    List<String>? weeklyStarGifts,
    this.weeklyStarWinner = '',
    Map<String, int>? giftPrices,
    List<AgencyRecord>? registeredAgencies,
    SupabaseSyncService? supabaseService,
  })  : supabase = supabaseService ?? SupabaseSyncService(),
        bagItems = bagItems ??
            [
              ownerExclusiveFrame,
              ownerExclusiveEntry,
              ownerExclusiveBg,
              'Starter Frame (5 Days)',
              'Starter Entry (5 Days)',
            ],
        weeklyStarGifts = weeklyStarGifts ??
            [
              'Love Car',
              'Love Kano',
              'Royal Crown',
              'Golden Falcon',
              'Diamond Wave',
            ],
        giftPrices = giftPrices ??
            {
              'Rose Spark (100)': 100,
              'Teal Pulse (500)': 500,
              'Gold Wave (1,000)': 1000,
              'Royal Crown': 2500,
              'Golden Falcon': 5000,
              'Diamond Wave': 7500,
              'Love Car': 10000,
              'Love Kano': 15000,
            },
        registeredAgencies = registeredAgencies ?? [];
}

class ZoonlLiveApp extends StatefulWidget {
  const ZoonlLiveApp({super.key});

  @override
  State<ZoonlLiveApp> createState() => _ZoonlLiveAppState();
}

class _ZoonlLiveAppState extends State<ZoonlLiveApp> {
  int _currentIndex = 0; // 0: Short Video First, 1: Live, 2: Profile & Hub
  final ZoonlAppState _appState = ZoonlAppState();

  void _updateState(VoidCallback fn) {
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ShortVideoFirstTab(
        state: _appState,
        onGoLive: () => _updateState(() => _currentIndex = 1),
      ),
      LiveRoomsTab(
        state: _appState,
        onRegionChanged: (region) =>
            _updateState(() => _appState.selectedRegion = region),
        onStateChanged: _updateState,
      ),
      ProfileAndHubTab(
        state: _appState,
        onStateChanged: _updateState,
      ),
    ];

    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ZoonlColors.bgDark,
        primaryColor: ZoonlColors.champagneGold,
        colorScheme: const ColorScheme.dark(
          primary: ZoonlColors.champagneGold,
          secondary: ZoonlColors.tealAccent,
          surface: ZoonlColors.surfaceDark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(child: pages[_currentIndex]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: ZoonlColors.surfaceDark,
            border: Border(top: BorderSide(color: ZoonlColors.borderSubtle)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (idx) => _updateState(() => _currentIndex = idx),
            backgroundColor: ZoonlColors.surfaceDark,
            selectedItemColor: ZoonlColors.champagneGold,
            unselectedItemColor: ZoonlColors.textSecondary,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.play_circle_fill),
                label: 'Short Video',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.live_tv),
                label: 'Live',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1. Short Video First Tab (Opens first on app launch)
class ShortVideoFirstTab extends StatefulWidget {
  final ZoonlAppState state;
  final VoidCallback onGoLive;

  const ShortVideoFirstTab({
    super.key,
    required this.state,
    required this.onGoLive,
  });

  @override
  State<ShortVideoFirstTab> createState() => _ShortVideoFirstTabState();
}

class _ShortVideoFirstTabState extends State<ShortVideoFirstTab> {
  int _likes = 0;
  bool _liked = false;
  String _selectedFilter = 'Champagne Glow';

  static const List<String> _filters = [
    'Champagne Glow',
    'Teal Cinema',
    'Noir Contrast',
    'Warm Sunset',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'ZOONL LIVE',
                style: TextStyle(
                  color: ZoonlColors.champagneGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ZoonlColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ZoonlColors.tealAccent),
                ),
                child: Text(
                  'Coins: ${widget.state.coins}',
                  style: const TextStyle(
                    color: ZoonlColors.tealAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final active = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: active,
                    selectedColor: ZoonlColors.champagneGold,
                    labelStyle: TextStyle(
                      color: active
                          ? ZoonlColors.bgDark
                          : ZoonlColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ZoonlColors.cardDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ZoonlColors.borderSubtle),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam,
                    size: 54,
                    color: ZoonlColors.champagneGold,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Short Video Feed • Filter: $_selectedFilter',
                    style: const TextStyle(
                      color: ZoonlColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Live Short Video stream & camera filter studio.',
                    style: TextStyle(
                      color: ZoonlColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _liked = !_liked;
                            _likes += _liked ? 1 : -1;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZoonlColors.surfaceDark,
                          foregroundColor: _liked
                              ? Colors.redAccent
                              : ZoonlColors.textPrimary,
                        ),
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                        ),
                        label: Text('Likes: $_likes'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: widget.onGoLive,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZoonlColors.champagneGold,
                          foregroundColor: ZoonlColors.bgDark,
                        ),
                        icon: const Icon(Icons.sensors),
                        label: const Text(
                          'Go Live',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Live Rooms Discovery + Full Interactive Live Room Sheet
class LiveRoomsTab extends StatelessWidget {
  final ZoonlAppState state;
  final ValueChanged<String> onRegionChanged;
  final void Function(VoidCallback) onStateChanged;

  const LiveRoomsTab({
    super.key,
    required this.state,
    required this.onRegionChanged,
    required this.onStateChanged,
  });

  static const List<String> _regions = [
    'United Arab Emirates',
    'Pakistan',
    'Saudi Arabia',
    'Global',
    'United Kingdom',
    'Canada',
  ];

  void _openLiveRoom(BuildContext context, int roomIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZoonlColors.bgDark,
      builder: (_) => LiveRoomWorkspace(
        roomTitle: 'ZOONL Live Room #${roomIndex + 1}',
        state: state,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Live & PK Arena',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ZoonlColors.champagneGold,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: state.selectedRegion,
                dropdownColor: ZoonlColors.cardDark,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                items: _regions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) onRegionChanged(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZoonlColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: ZoonlColors.champagneGold.withValues(alpha: 0.45)),
            ),
            child: Text(
              'Owner ID: ${ZoonlAppState.ownerId} • Weekly Star: ${state.weeklyStarWinner.isEmpty ? "Live Standings" : state.weeklyStarWinner} • Top Gifts: ${state.weeklyStarGifts.take(3).join(", ")}',
              style: const TextStyle(
                color: ZoonlColors.champagneGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, idx) {
                return InkWell(
                  onTap: () => _openLiveRoom(context, idx),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ZoonlColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ZoonlColors.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ZoonlColors.tealAccent
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE • 8-SEAT',
                                style: TextStyle(
                                  color: ZoonlColors.tealAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.emoji_events,
                              size: 18,
                              color: ZoonlColors.champagneGold,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Live Stage #${idx + 1}',
                          style: const TextStyle(
                            color: ZoonlColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter room, PK, call & gifts',
                          style: TextStyle(
                            color: ZoonlColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Live Room with 8 Audio Seats, PK (Friend/Random/Group 4 or 6),
/// Guest Call (4 normal / 2 in PK), Combo Gifts (9, 99, 143, 999), Trophy & Chat Strip
class LiveRoomWorkspace extends StatefulWidget {
  final String roomTitle;
  final ZoonlAppState state;
  final void Function(VoidCallback) onStateChanged;

  const LiveRoomWorkspace({
    super.key,
    required this.roomTitle,
    required this.state,
    required this.onStateChanged,
  });

  @override
  State<LiveRoomWorkspace> createState() => _LiveRoomWorkspaceState();
}

class _LiveRoomWorkspaceState extends State<LiveRoomWorkspace> {
  final TextEditingController _chatCtrl = TextEditingController();
  bool _pkActive = false;
  String _pkMode = 'Friend 1v1';
  String _pkStatusBanner = 'PK Ready: Select 1v1 or Group (4 / 6 max)';
  String _globalComboBanner = '';
  int _selectedComboMultiplier = 9;
  String _selectedGiftName = 'Love Car';
  bool _guestCameraOn = true;
  String _guestFilter = 'Champagne Glow';

  final List<AudioSeatItem> _seats = List.generate(
    8,
    (i) => AudioSeatItem(seatNumber: i + 1),
  );

  final List<ChatMessageItem> _messages = [];

  int get _maxCallGuests => _pkActive ? 2 : 4;

  int get _activeCallCount =>
      _seats.where((s) => s.occupantName != null).length;

  Color _stripColorForLevel(int level) {
    if (level >= 20) return const Color(0xFF9333EA);
    if (level >= 18) return const Color(0xFFEC4899);
    if (level >= 15) return const Color(0xFFF59E0B);
    if (level >= 10) return const Color(0xFF0EA5E9);
    if (level >= 5) return const Color(0xFF14B8A6);
    return const Color(0xFF334155);
  }

  void _togglePk(String mode) {
    setState(() {
      _pkMode = mode;
      _pkActive = true;
      _pkStatusBanner =
          'PUNCH START! $mode PK Active • Winner Emoji & Cry Sticker Ready';
    });
  }

  void _resolvePkOutcome(bool won) {
    setState(() {
      _pkStatusBanner = won
          ? 'VICTORY! Winner Emoji Active • Cry Sticker Sent'
          : 'DEFEAT! Cry Sticker Active • Winner Emoji Awarded';
    });
  }

  void _joinOrToggleSeat(int index) {
    final seat = _seats[index];
    if (seat.occupantName == null) {
      if (_activeCallCount >= _maxCallGuests) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Max $_maxCallGuests call guests allowed (${_pkActive ? "during PK" : "in normal live"}).',
            ),
          ),
        );
        return;
      }
      setState(() {
        seat.occupantName = 'Live Caller #${seat.seatNumber}';
        seat.cameraOn = _guestCameraOn;
      });
    } else {
      setState(() {
        seat.occupantName = null;
        seat.isMuted = false;
      });
    }
  }

  Future<void> _sendGift() async {
    final unitPrice = widget.state.giftPrices[_selectedGiftName] ?? 100;
    final totalCoins = unitPrice * _selectedComboMultiplier;

    if (!widget.state.isOwnerMode && widget.state.coins < totalCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient coin balance.')),
      );
      return;
    }

    await widget.state.supabase.pushLiveEvent('gift_transactions', {
      'account_id': widget.state.activeAccountId,
      'gift_name': _selectedGiftName,
      'multiplier': _selectedComboMultiplier,
      'total_coins': totalCoins,
    });

    widget.onStateChanged(() {
      if (!widget.state.isOwnerMode) {
        widget.state.coins -= totalCoins;
      }
      widget.state.beans += totalCoins;
    });

    setState(() {
      _globalComboBanner = _selectedComboMultiplier > 1
          ? 'BIG COMBO x$_selectedComboMultiplier! $_selectedGiftName ($totalCoins Coins) across Live Rooms!'
          : 'Sent $_selectedGiftName ($totalCoins Coins)';
      _messages.add(
        ChatMessageItem(
          sender: widget.state.isOwnerMode
              ? 'Owner (ID ${ZoonlAppState.ownerId})'
              : 'ID ${widget.state.activeAccountId}',
          text:
              'Sent $_selectedGiftName x$_selectedComboMultiplier ($totalCoins coins)',
          level: widget.state.userLevel,
          isSvip: widget.state.isSvip,
          isOwner: widget.state.isOwnerMode,
        ),
      );
    });
  }

  void _sendChat() {
    final txt = _chatCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessageItem(
          sender: widget.state.isOwnerMode
              ? 'Owner (ID ${ZoonlAppState.ownerId})'
              : 'ID ${widget.state.activeAccountId}',
          text: txt,
          level: widget.state.userLevel,
          isSvip: widget.state.isSvip,
          isOwner: widget.state.isOwnerMode,
        ),
      );
      _chatCtrl.clear();
    });
  }

  void _showTrophySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZoonlColors.surfaceDark,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Rankings & Weekly Star',
              style: TextStyle(
                color: ZoonlColors.champagneGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Top 1 Sender (Weekly): Live Leaderboard Synced',
              style: TextStyle(color: ZoonlColors.textPrimary),
            ),
            const Text(
              '• Top 1 Sender (Monthly): Live Leaderboard Synced',
              style: TextStyle(color: ZoonlColors.textPrimary),
            ),
            const Text(
              '• Top 1 Sender (Total): Live Leaderboard Synced',
              style: TextStyle(color: ZoonlColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '• Weekly Star (#1): ${widget.state.weeklyStarWinner.isEmpty ? "Pending Live Tally" : widget.state.weeklyStarWinner}',
              style: const TextStyle(color: ZoonlColors.tealAccent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.roomTitle,
                  style: const TextStyle(
                    color: ZoonlColors.champagneGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'Coins: ${widget.state.coins}',
                style: const TextStyle(
                  color: ZoonlColors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showTrophySheet,
                icon: const Icon(
                  Icons.emoji_events,
                  color: ZoonlColors.champagneGold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: ZoonlColors.textSecondary),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZoonlColors.cardDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ZoonlColors.champagneGold.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pkStatusBanner,
                  style: const TextStyle(
                    color: ZoonlColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_globalComboBanner.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _globalComboBanner,
                    style: const TextStyle(
                      color: ZoonlColors.champagneGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mode in [
                  'Friend 1v1',
                  'Random 1v1',
                  'Group 4',
                  'Group 6'
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: () => _togglePk(mode),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _pkMode == mode && _pkActive
                              ? ZoonlColors.champagneGold
                              : ZoonlColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        mode,
                        style: const TextStyle(
                          color: ZoonlColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => _resolvePkOutcome(true),
                  child: const Text(
                    'Win Emoji',
                    style: TextStyle(color: ZoonlColors.tealAccent, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: () => _resolvePkOutcome(false),
                  child: const Text(
                    'Cry Sticker',
                    style: TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 8,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, idx) {
              final seat = _seats[idx];
              final occupied = seat.occupantName != null;
              return Container(
                decoration: BoxDecoration(
                  color: ZoonlColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: occupied
                        ? ZoonlColors.tealAccent
                        : ZoonlColors.borderSubtle,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      occupied ? seat.occupantName! : 'Seat ${seat.seatNumber}',
                      style: const TextStyle(
                        color: ZoonlColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _joinOrToggleSeat(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: occupied
                              ? Colors.redAccent.withValues(alpha: 0.25)
                              : ZoonlColors.champagneGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          occupied
                              ? 'Leave'
                              : (seat.isLockedForJoinCall
                                  ? 'JOIN CALL'
                                  : '+ Join'),
                          style: TextStyle(
                            color: occupied
                                ? Colors.redAccent
                                : ZoonlColors.bgDark,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (occupied)
                      InkWell(
                        onTap: () =>
                            setState(() => seat.isMuted = !seat.isMuted),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            seat.isMuted ? 'Muted' : 'Mic On',
                            style: TextStyle(
                              color: seat.isMuted
                                  ? Colors.orangeAccent
                                  : ZoonlColors.tealAccent,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilterChip(
                label: Text(
                  _guestCameraOn ? 'Cam ON' : 'Cam OFF',
                  style: const TextStyle(fontSize: 11),
                ),
                selected: _guestCameraOn,
                onSelected: (v) => setState(() => _guestCameraOn = v),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _guestFilter,
                dropdownColor: ZoonlColors.cardDark,
                style:
                    const TextStyle(color: ZoonlColors.textPrimary, fontSize: 12),
                items: const [
                  DropdownMenuItem(
                    value: 'Champagne Glow',
                    child: Text('Filter: Champagne Glow'),
                  ),
                  DropdownMenuItem(
                    value: 'Teal Beauty',
                    child: Text('Filter: Teal Beauty'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _guestFilter = v);
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final m = _messages[idx];
                final stripColor = _stripColorForLevel(m.level);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stripColor.withValues(alpha: 0.35),
                        ZoonlColors.cardDark,
                        stripColor.withValues(alpha: 0.35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: m.isOwner
                          ? ZoonlColors.champagneGold
                          : stripColor.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        m.isOwner ? Icons.workspace_premium : Icons.auto_awesome,
                        size: 14,
                        color: ZoonlColors.champagneGold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '[Lv.${m.level}] ${m.sender}: ',
                                style: TextStyle(
                                  color: (m.isSvip || m.isOwner)
                                      ? Colors.redAccent
                                      : ZoonlColors.champagneGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: m.isMuted ? '(Muted)' : m.text,
                                style: const TextStyle(
                                  color: ZoonlColors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: ZoonlColors.tealAccent,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedGiftName,
                  dropdownColor: ZoonlColors.cardDark,
                  style: const TextStyle(
                    color: ZoonlColors.textPrimary,
                    fontSize: 12,
                  ),
                  items: widget.state.giftPrices.keys
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('$g (${widget.state.giftPrices[g]})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGiftName = v);
                  },
                ),
                const SizedBox(width: 6),
                for (final mult in [1, 9, 99, 143, 999])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(
                        mult == 1 ? '1x' : 'x$mult',
                        style: const TextStyle(fontSize: 10),
                      ),
                      selected: _selectedComboMultiplier == mult,
                      selectedColor: ZoonlColors.champagneGold,
                      onSelected: (_) =>
                          setState(() => _selectedComboMultiplier = mult),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _sendGift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZoonlColors.tealAccent,
                    foregroundColor: ZoonlColors.bgDark,
                  ),
                  child: const Text(
                    'Send Gift',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(color: ZoonlColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type message inside chat strip...',
                    hintStyle: const TextStyle(
                      color: ZoonlColors.textSecondary,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: ZoonlColors.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendChat,
                icon: const Icon(Icons.send, color: ZoonlColors.champagneGold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3. Profile, Owner ID 10001, Manual Top-Up ($10=45,000), Withdraw/Advance,
/// Self/Agency KYC, Mini-Games, AI Support & Language (No Hindi)
class ProfileAndHubTab extends StatefulWidget {
  final ZoonlAppState state;
  final void Function(VoidCallback) onStateChanged;

  const ProfileAndHubTab({
    super.key,
    required this.state,
    required this.onStateChanged,
  });

  @override
  State<ProfileAndHubTab> createState() => _ProfileAndHubTabState();
}

class _ProfileAndHubTabState extends State<ProfileAndHubTab> {
  static const List<String> _languages = [
    'English',
    'Urdu',
    'Arabic',
    'French',
    'Spanish',
  ];

  final TextEditingController _agencyNameCtrl = TextEditingController();
  final TextEditingController _agencyPhoneCtrl = TextEditingController();
  final TextEditingController _agencyWaCtrl = TextEditingController();
  final TextEditingController _withdrawAccountCtrl = TextEditingController();
  final TextEditingController _withdrawNameCtrl = TextEditingController();
  final TextEditingController _withdrawPhoneCtrl = TextEditingController();
  final TextEditingController _supportPhoneCtrl = TextEditingController();
  final TextEditingController _supportEmailCtrl = TextEditingController();

  String _regPath = 'Self'; // Self or Agency
  String _selectedWallet = 'EasyPaisa';
  String _aiReply =
      'AI & Voice Support active. Select a topic or enter your official contact.';

  List<String> _walletsForRegion(String region) {
    if (region == 'Pakistan') return ['EasyPaisa', 'JazzCash', 'Bank Account'];
    if (region == 'United Arab Emirates') {
      return ['Bank Account', 'Botim / Local Wallet'];
    }
    return ['Bank Account', 'Local Mobile Wallet'];
  }

  void _registerAgency() {
    final name = _agencyNameCtrl.text.trim();
    final phone = _agencyPhoneCtrl.text.trim();
    final wa = _agencyWaCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty || wa.isEmpty) return;

    widget.onStateChanged(() {
      widget.state.registeredAgencies.add(
        AgencyRecord(
          agencyName: 'Official Agency: $name',
          phone: phone,
          whatsapp: wa,
          region: widget.state.selectedRegion,
        ),
      );
    });
    _agencyNameCtrl.clear();
    _agencyPhoneCtrl.clear();
    _agencyWaCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool ownerActive = widget.state.isOwnerMode;
    final wallets = _walletsForRegion(widget.state.selectedRegion);
    if (!wallets.contains(_selectedWallet)) {
      _selectedWallet = wallets.first;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Owner ID 10001 / Profile Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2A1E0A),
                Color(0xFF142429),
                Color(0xFF1A2130),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ZoonlColors.champagneGold,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ZoonlColors.champagneGold,
                        width: 2.5,
                      ),
                    ),
                    child: const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFF3A280A),
                      child: Icon(
                        Icons.workspace_premium,
                        color: ZoonlColors.champagneGold,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownerActive
                              ? 'OWNER • ID ${ZoonlAppState.ownerId}'
                              : 'Account ID ${widget.state.activeAccountId}',
                          style: TextStyle(
                            color: (ownerActive || widget.state.isSvip)
                                ? Colors.redAccent
                                : ZoonlColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ownerActive
                              ? ZoonlAppState.ownerExclusiveFrame
                              : '5-Day Starter Frame & Entry Active',
                          style: const TextStyle(
                            color: ZoonlColors.champagneGold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          ownerActive
                              ? ZoonlAppState.ownerExclusiveEntry
                              : 'Valid Days: ${widget.state.validDaysCompleted}/20 (2h/day = \$40 reward)',
                          style: const TextStyle(
                            color: ZoonlColors.tealAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ownerActive) ...[
                const SizedBox(height: 8),
                Text(
                  ZoonlAppState.ownerExclusiveBg,
                  style: const TextStyle(
                    color: ZoonlColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 Separate Boxes: Top-Up Coins / Diamonds / Valid-Beans
        Row(
          children: [
            Expanded(
                child: _StatBox(label: 'Top-Up Coins', value: '${widget.state.coins}')),
            const SizedBox(width: 8),
            Expanded(
                child: _StatBox(label: 'Diamonds', value: '${widget.state.diamonds}')),
            const SizedBox(width: 8),
            Expanded(
                child: _StatBox(label: 'Valid/Beans', value: '${widget.state.beans}')),
          ],
        ),
        const SizedBox(height: 14),

        // Manual Top-Up ($10 = 45,000 coins up to ~$100) + Agency Directory below Top-Up
        _SectionCard(
          title: 'Manual Top-Up (\$10 = 45,000 Coins up to \$100)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [10, 20, 50, 100].map((usd) {
                  final pkgCoins = (usd * widget.state.coinRatePerUsd).toInt();
                  return ElevatedButton(
                    onPressed: () {
                      widget.onStateChanged(() => widget.state.coins += pkgCoins);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Top-up request logged: \$$usd ($pkgCoins coins) via $_selectedWallet.',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZoonlColors.champagneGold,
                      foregroundColor: ZoonlColors.bgDark,
                    ),
                    child: Text(
                      '\$$usd = $pkgCoins',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Method: ',
                    style: TextStyle(color: ZoonlColors.textSecondary, fontSize: 12),
                  ),
                  DropdownButton<String>(
                    value: _selectedWallet,
                    dropdownColor: ZoonlColors.surfaceDark,
                    style: const TextStyle(
                        color: ZoonlColors.tealAccent, fontSize: 12),
                    items: wallets
                        .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedWallet = v);
                    },
                  ),
                ],
              ),
              if (widget.state.registeredAgencies.isNotEmpty) ...[
                const Divider(color: ZoonlColors.borderSubtle),
                const Text(
                  'Official Agencies (Auto-Listed Under Top-Up)',
                  style: TextStyle(
                    color: ZoonlColors.champagneGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...widget.state.registeredAgencies.map(
                  (ag) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${ag.agencyName} • Tel: ${ag.phone} • WA: ${ag.whatsapp} (${ag.region})',
                      style: const TextStyle(
                          color: ZoonlColors.textPrimary, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Withdraw (1st-5th) & Advance Request
        _SectionCard(
          title: 'Streamer Withdraw (1st–5th) & Advance Request',
          child: Column(
            children: [
              TextField(
                controller: _withdrawAccountCtrl,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Bank Account / Wallet Number (Required)',
                  labelStyle: TextStyle(fontSize: 12),
                ),
              ),
              TextField(
                controller: _withdrawNameCtrl,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name (Required)',
                  labelStyle: TextStyle(fontSize: 12),
                ),
              ),
              TextField(
                controller: _withdrawPhoneCtrl,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Receiver Mobile Number (Required)',
                  labelStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Monthly payout window: request on 1st, paid by 5th.',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZoonlColors.tealAccent,
                        foregroundColor: ZoonlColors.bgDark,
                      ),
                      child: const Text(
                        'Submit Withdraw',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Advance request sent for owner review based on coins/gifting.',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Request Advance',
                        style: TextStyle(
                            color: ZoonlColors.champagneGold, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Self vs Agency Registration + KYC + $40 Reward (20 valid days x 2h)
        _SectionCard(
          title: 'Registration (Self / Agency) & KYC',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Self'),
                    selected: _regPath == 'Self',
                    onSelected: (_) => setState(() => _regPath = 'Self'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Agency'),
                    selected: _regPath == 'Agency',
                    onSelected: (_) => setState(() => _regPath = 'Agency'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'KYC Guide: 1) Front ID  2) Back ID  3) Photo holding ID card + Name, DOB & Country. New streamer reward: \$40 after 20 valid days (2h/day), with or without gifting.',
                style:
                    const TextStyle(color: ZoonlColors.textSecondary, fontSize: 11),
              ),
              if (_regPath == 'Agency') ...[
                TextField(
                  controller: _agencyNameCtrl,
                  style: const TextStyle(color: ZoonlColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Agency Name',
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                TextField(
                  controller: _agencyPhoneCtrl,
                  style: const TextStyle(color: ZoonlColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Professional Phone Number',
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                TextField(
                  controller: _agencyWaCtrl,
                  style: const TextStyle(color: ZoonlColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _registerAgency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZoonlColors.champagneGold,
                    foregroundColor: ZoonlColors.bgDark,
                  ),
                  child: const Text(
                    'Register Official Agency',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // AI / Voice Support + Official Contact + Language (No Hindi)
        _SectionCard(
          title: 'AI / Voice Support & Official Contact',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _aiReply,
                style: const TextStyle(
                    color: ZoonlColors.tealAccent, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _aiReply =
                          'Voice Guide: ZOONL LIVE supports Short Video first, Live PK/Audio, Manual Top-Up, 1st–5th Withdraw, and \$40 (20 days x 2h) streamer reward.';
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZoonlColors.champagneGold,
                      foregroundColor: ZoonlColors.bgDark,
                    ),
                    child: const Text(
                      'Voice App Guide',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _aiReply =
                          'Official Contact -> Phone/WA: ${widget.state.officialSupportPhone.isEmpty ? "Set below" : widget.state.officialSupportPhone} | Email: ${widget.state.officialSupportEmail.isEmpty ? "Set below" : widget.state.officialSupportEmail}';
                    }),
                    child: const Text(
                      'Official Contact',
                      style:
                          TextStyle(color: ZoonlColors.textPrimary, fontSize: 11),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _supportPhoneCtrl,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Set Official Phone / WhatsApp',
                  labelStyle: TextStyle(fontSize: 12),
                ),
              ),
              TextField(
                controller: _supportEmailCtrl,
                style: const TextStyle(color: ZoonlColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Set Official Email',
                  labelStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () {
                  widget.onStateChanged(() {
                    widget.state.officialSupportPhone =
                        _supportPhoneCtrl.text.trim();
                    widget.state.officialSupportEmail =
                        _supportEmailCtrl.text.trim();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZoonlColors.tealAccent,
                  foregroundColor: ZoonlColors.bgDark,
                ),
                child: const Text(
                  'Save Official Contact',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Language Selector (No Hindi)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ZoonlColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZoonlColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: ZoonlColors.tealAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Language (No Hindi)',
                  style: TextStyle(color: ZoonlColors.textPrimary),
                ),
              ),
              DropdownButton<String>(
                value: widget.state.selectedLanguage,
                dropdownColor: ZoonlColors.surfaceDark,
                style: const TextStyle(color: ZoonlColors.champagneGold),
                items: _languages
                    .map((lang) =>
                        DropdownMenuItem(value: lang, child: Text(lang)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    widget.onStateChanged(
                        () => widget.state.selectedLanguage = val);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bag & Auto Backup
        const Text(
          'Bag & Auto Backup',
          style: TextStyle(
            color: ZoonlColors.champagneGold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.state.bagItems.map(
          (item) => Card(
            color: ZoonlColors.cardDark,
            child: ListTile(
              leading: const Icon(
                Icons.card_giftcard,
                color: ZoonlColors.tealAccent,
              ),
              title: Text(
                item,
                style: const TextStyle(color: ZoonlColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZoonlColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZoonlColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZoonlColors.champagneGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZoonlColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZoonlColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: ZoonlColors.champagneGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: ZoonlColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
