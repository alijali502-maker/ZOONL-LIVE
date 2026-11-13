
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'core/app_config.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ZoonlApp());
}

const Color bg = Color(0xFF080611);
const Color panel = Color(0xFF171126);
const Color panel2 = Color(0xFF211735);
const Color purple = Color(0xFF9360F5);
const Color purple2 = Color(0xFF542CA0);
const Color gold = Color(0xFFE6C47A);
const Color muted = Color(0xFFAAA1BC);
const Color pink = Color(0xFFDA65C8);

class ZoonlApp extends StatelessWidget {
  const ZoonlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (supabase.auth.currentSession == null) {
            return const LoginScreen();
          }
          return MainScreen(
            key: ValueKey(supabase.auth.currentUser?.id),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SupabaseClient db = Supabase.instance.client;
  final AudioPlayer audioPlayer = AudioPlayer();

  int tab = 0;
  bool loading = true;
  bool sendingGift = false;

  Map<String, dynamic> profile = {};
  Map<String, dynamic> publicProfile = {};
  Map<String, dynamic> wallet = {};

  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> gifts = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> memberships = [];

  String? profileError;
  String? walletError;
  String? roomsError;
  String? giftsError;
  String? transactionError;

  String get userId => db.auth.currentUser?.id ?? '';

  int get coins => _number(wallet['coins']);
  int get diamonds => _number(wallet['diamonds']);

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _value(dynamic value, [String fallback = 'Not available']) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (userId.isEmpty) return;

    if (mounted) {
      setState(() {
        loading = true;
        profileError = null;
        walletError = null;
        roomsError = null;
        giftsError = null;
        transactionError = null;
      });
    }

    await Future.wait([
      _loadProfile(),
      _loadPublicProfile(),
      _loadWallet(),
      _loadRooms(),
      _loadGifts(),
      _loadTransactions(),
      _loadMemberships(),
    ]);

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final result = await db
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      profile = result ?? {};
    } catch (e) {
      profileError = e.toString();
      profile = {};
    }
  }

  Future<void> _loadPublicProfile() async {
    try {
      final result = await db
          .from('user_public_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      publicProfile = result ?? {};
    } catch (_) {
      publicProfile = {};
    }
  }

  Future<void> _loadWallet() async {
    try {
      final result = await db
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      wallet = result ?? {};
    } catch (e) {
      walletError = e.toString();
      wallet = {};
    }
  }

  Future<void> _loadRooms() async {
    try {
      final result = await db
          .from('live_rooms')
          .select()
          .eq('is_live', true)
          .order('created_at', ascending: false)
          .limit(50);

      rooms = List<Map<String, dynamic>>.from(result);
    } catch (e) {
      roomsError = e.toString();
      rooms = [];
    }
  }

  Future<void> _loadGifts() async {
    try {
      final result = await db
          .from('gifts')
          .select()
          .eq('is_active', true)
          .order('coin_price')
          .limit(100);

      gifts = List<Map<String, dynamic>>.from(result);
    } catch (e) {
      giftsError = e.toString();
      gifts = [];
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final result = await db
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      transactions = List<Map<String, dynamic>>.from(result);
    } catch (e) {
      transactionError = e.toString();
      transactions = [];
    }
  }

  Future<void> _loadMemberships() async {
    try {
      final result = await db
          .from('user_prime_memberships')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(10);

      memberships = List<Map<String, dynamic>>.from(result);
    } catch (_) {
      memberships = [];
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: panel2,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _friendlyError(Object error) {
    final text = error.toString().toUpperCase();

    if (text.contains('LOGIN_REQUIRED')) {
      return 'पहले Login करें।';
    }
    if (text.contains('ROOM_NOT_FOUND')) {
      return 'यह Live Room उपलब्ध नहीं है।';
    }
    if (text.contains('ROOM_NOT_LIVE')) {
      return 'यह Room अभी Live नहीं है।';
    }
    if (text.contains('CANNOT_SEND_GIFT_TO_SELF')) {
      return 'आप अपने ही Room में Gift नहीं भेज सकते।';
    }
    if (text.contains('ROOM_ACCESS_REQUIRED')) {
      return 'इस Private Room की अनुमति जरूरी है।';
    }
    if (text.contains('GIFT_NOT_AVAILABLE')) {
      return 'यह Gift अभी उपलब्ध नहीं है।';
    }
    if (text.contains('INVALID_QUANTITY')) {
      return 'Gift की Quantity सही नहीं है।';
    }
    if (text.contains('INSUFFICIENT_COINS')) {
      return 'आपके Wallet में पर्याप्त Coins नहीं हैं।';
    }
    if (text.contains('SENDER_WALLET_NOT_FOUND')) {
      return 'आपका Wallet रिकॉर्ड नहीं मिला।';
    }

    return 'Gift नहीं भेजा जा सका: $error';
  }

  Future<void> _playGiftSound(Map<String, dynamic> gift) async {
    final url = gift['sound_url']?.toString() ?? '';
    if (url.isEmpty) return;

    try {
      await audioPlayer.stop();
      await audioPlayer.setUrl(url);
      await audioPlayer.play();
    } catch (_) {
      // Sound unavailable होने पर Gift transaction प्रभावित नहीं होगा।
    }
  }

  Future<void> sendGift(Map<String, dynamic> gift,
      {Map<String, dynamic>? selectedRoom}) async {
    final availableRooms = rooms.where((room) {
      return room['owner_id']?.toString() != userId;
    }).toList();

    if (availableRooms.isEmpty) {
      _message('अभी Gift भेजने के लिए कोई दूसरा Active Live Room नहीं मिला।');
      return;
    }

    final giftId = gift['id']?.toString();
    if (giftId == null || giftId.isEmpty) {
      _message('इस Gift की ID उपलब्ध नहीं है।');
      return;
    }

    String? roomId = selectedRoom?['id']?.toString();
    if (roomId == null ||
        !availableRooms.any((room) => room['id'].toString() == roomId)) {
      roomId = availableRooms.first['id'].toString();
    }

    int quantity = 1;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sendingGift,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final total = _number(gift['coin_price']) * quantity;

            return AlertDialog(
              backgroundColor: panel,
              title: const Text(
                'Send Gift',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _giftImage(gift, size: 90),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _value(gift['gift_name'], 'Gift'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Choose Live Room'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: roomId,
                    isExpanded: true,
                    dropdownColor: panel2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: availableRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room['id'].toString(),
                        child: Text(
                          _value(room['room_name'], 'Live Room'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: sendingGift
                        ? null
                        : (value) {
                            dialogSetState(() => roomId = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  const Text('Quantity'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: quantity,
                    dropdownColor: panel2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 5, 10, 20, 50].map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: sendingGift
                        ? null
                        : (value) {
                            if (value != null) {
                              dialogSetState(() => quantity = value);
                            }
                          },
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Total: $total Coins',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Your balance: $coins Coins',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sendingGift
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: purple,
                  ),
                  onPressed: sendingGift
                      ? null
                      : () async {
                          if (roomId == null) return;

                          dialogSetState(() => sendingGift = true);

                          try {
                            final response = await db.rpc(
                              'send_live_gift',
                              params: {
                                'p_gift_id': giftId,
                                'p_room_id': roomId,
                                'p_quantity': quantity,
                              },
                            );

                            final result = response is Map
                                ? Map<String, dynamic>.from(response)
                                : <String, dynamic>{};

                            if (result['success'] != true) {
                              throw Exception('GIFT_SEND_FAILED');
                            }

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }

                            await _playGiftSound(gift);
                            await loadData();

                            if (!mounted) return;

                            final giftName = _value(
                              result['gift_name'],
                              _value(gift['gift_name'], 'Gift'),
                            );
                            final deducted =
                                _number(result['coins_deducted']);
                            final received =
                                _number(result['diamonds_received']);

                            _message(
                              '$giftName भेजा गया। '
                              '$deducted Coins कटे। '
                              'Host को $received Diamonds मिले।',
                            );

                            _showGiftSuccess(gift, giftName, quantity);
                          } catch (e) {
                            if (dialogContext.mounted) {
                              dialogSetState(() => sendingGift = false);
                            }
                            _message(_friendlyError(e));
                          }
                        },
                  child: sendingGift
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SEND GIFT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGiftSuccess(
    Map<String, dynamic> gift,
    String giftName,
    int quantity,
  ) {
    if (!mounted) return;

    final animationUrl =
        gift['animation_url']?.toString() ??
        gift['image_url']?.toString() ??
        '';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: panel,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (animationUrl.isNotEmpty)
                SizedBox(
                  height: 130,
                  child: Image.network(
                    animationUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.card_giftcard,
                            size: 75, color: gold),
                  ),
                )
              else
                const Icon(Icons.card_giftcard, size: 75, color: gold),
              const SizedBox(height: 12),
              const Text(
                'GIFT SENT SUCCESSFULLY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text('$giftName x$quantity'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      homePage(),
      livePage(),
      walletPage(),
      giftsPage(),
      profilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF21143A), bg],
          ),
        ),
        child: SafeArea(child: pages[tab]),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF110D1C),
        indicatorColor: purple.withOpacity(0.25),
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: gold),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv, color: gold),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: gold),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined),
            selectedIcon: Icon(Icons.card_giftcard, color: gold),
            label: 'Gifts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: gold),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget header(String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [purple, purple2],
            ),
          ),
          child: const Icon(Icons.bolt, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                subtitle ?? 'LIVE SOCIAL WORLD',
                style: const TextStyle(
                  color: gold,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: loading ? null : loadData,
          icon: const Icon(Icons.refresh, color: gold),
        ),
      ],
    );
  }

  Widget homePage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('ZOONL LIVE'),
          const SizedBox(height: 22),
          Container(
            height: 195,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7445B8),
                  Color(0xFF351C59),
                  Color(0xFF171126),
                ],
              ),
              border: Border.all(color: gold.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: purple.withOpacity(0.25),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.public,
                    size: 120,
                    color: Colors.white12,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZOONL EXCLUSIVE',
                      style: TextStyle(
                        color: gold,
                        letterSpacing: 2,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'YOUR WORLD.\nYOUR STAGE.',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect with the world.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _metric('Coins', coins, Icons.monetization_on),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _metric('Diamonds', diamonds, Icons.diamond),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _metric('Live Rooms', rooms.length, Icons.live_tv),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _heading('Explore ZOONL', 'Your live social world'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _feature(
                  Icons.live_tv,
                  'LIVE ROOMS',
                  'Watch creators',
                  const Color(0xFF6339A5),
                  () => setState(() => tab = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _feature(
                  Icons.card_giftcard,
                  'GIFT CENTER',
                  'Send virtual gifts',
                  const Color(0xFF8B3C83),
                  () => setState(() => tab = 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _feature(
                  Icons.account_balance_wallet,
                  'MY WALLET',
                  'Coins and Diamonds',
                  const Color(0xFF795D30),
                  () => setState(() => tab = 2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _feature(
                  Icons.person,
                  'MY PROFILE',
                  'Your ZOONL identity',
                  const Color(0xFF315E73),
                  () => setState(() => tab = 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _heading('Live Now', 'Rooms currently broadcasting'),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: CircularProgressIndicator(color: gold))
          else if (rooms.isEmpty)
            _empty('No Active Live Rooms', 'Live Rooms will appear here when available.')
          else
            ...rooms.take(3).map(_roomCard),
        ],
      ),
    );
  }

  Widget livePage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('LIVE ROOMS', subtitle: 'DISCOVER LIVE CREATORS'),
          const SizedBox(height: 22),
          _heading('LIVE NOW', '${rooms.length} active rooms'),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator(color: gold))
          else if (rooms.isEmpty)
            _empty(
              'No Live Rooms Found',
              roomsError ?? 'जब कोई Host Live होगा, उसका Room यहाँ दिखाई देगा।',
            )
          else
            ...rooms.map(_roomCard),
        ],
      ),
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final ownerId = room['owner_id']?.toString() ?? '';
    final isMine = ownerId == userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: purple.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: purple2.withOpacity(0.4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.live_tv, color: gold, size: 29),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value(room['room_name'], 'ZOONL Live Room'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_value(room['room_type'], 'Live')}  •  '
                  '${_number(room['viewer_count'])} viewers',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFFFF626D),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (!isMine)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                setState(() => tab = 3);
                if (gifts.isNotEmpty) {
                  sendGift(gifts.first, selectedRoom: room);
                } else {
                  _message('Gift Catalog में अभी कोई Gift उपलब्ध नहीं है।');
                }
              },
              child: const Text('Gift'),
            )
          else
            const Text(
              'YOUR ROOM',
              style: TextStyle(color: gold, fontSize: 9),
            ),
        ],
      ),
    );
  }

  Widget walletPage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('MY WALLET', subtitle: 'COINS AND DIAMONDS'),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(
                colors: [Color(0xFF6840A7), Color(0xFF211735)],
              ),
              border: Border.all(color: gold.withOpacity(0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR BALANCE',
                  style: TextStyle(color: Colors.white70, letterSpacing: 2),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: gold, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$coins',
                        style: const TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text('COINS', style: TextStyle(color: gold)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 30),
                Row(
                  children: [
                    const Icon(Icons.diamond, color: pink, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$diamonds',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text('DIAMONDS', style: TextStyle(color: pink)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _heading('Wallet History', 'Your latest transactions'),
          const SizedBox(height: 10),
          if (walletError != null)
            _empty('Wallet Error', walletError!)
          else if (transactions.isEmpty)
            _empty('No Transactions', 'आपकी Wallet history यहाँ दिखाई देगी।')
          else
            ...transactions.map(_transactionCard),
        ],
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> row) {
    final amount = _number(row['amount']);
    final currency = _value(row['currency'], '');
    final type = _value(row['transaction_type'], 'Transaction');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            amount < 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: amount < 0 ? pink : const Color(0xFF6DDBA5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _value(row['description'], 'Wallet transaction'),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$amount $currency',
            style: TextStyle(
              color: amount < 0 ? pink : const Color(0xFF6DDBA5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget giftsPage() {
    return RefreshIndicator(
      onRefresh: loadData,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
        children: [
          header('GIFT CENTER', subtitle: 'SEND LOVE TO LIVE CREATORS'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF653C91), Color(0xFF241532)],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, size: 42, color: gold),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VIRTUAL GIFTS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$coins Coins available',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _heading('Gift Collection', '${gifts.length} available gifts'),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator(color: gold))
          else if (gifts.isEmpty)
            _empty('No Gifts Available', giftsError ?? 'Active Gifts यहाँ दिखाई देंगे।')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                childAspectRatio: 0.79,
              ),
              itemBuilder: (context, index) {
                return _giftCard(gifts[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _giftCard(Map<String, dynamic> gift) {
    final name = _value(gift['gift_name'], 'Gift');
    final price = _number(gift['coin_price']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(child: _giftImage(gift, size: 100)),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: gold, size: 16),
              const SizedBox(width: 4),
              Text('$price Coins', style: const TextStyle(color: gold)),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              onPressed: () => sendGift(gift),
              child: const Text('SEND'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftImage(Map<String, dynamic> gift, {double size = 70}) {
    final animation = gift['animation_url']?.toString() ?? '';
    final image = gift['image_url']?.toString() ?? '';
    final url = animation.isNotEmpty ? animation : image;

    if (url.isEmpty) {
      return Icon(Icons.card_giftcard, size: size * 0.65, color: gold);
    }

    return Image.network(
      url,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Icon(Icons.card_giftcard, size: size * 0.65, color: gold);
      },
    );
  }

  Widget profilePage() {
    final displayName = _value(
      profile['display_name'],
      _value(profile['username'], 'ZOONL Member'),
    );
    final zoonlId = _value(publicProfile['zoonl_id']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 100),
      children: [
        header('MY PROFILE', subtitle: 'YOUR ZOONL IDENTITY'),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: purple.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: purple2,
                child: Icon(Icons.person, size: 43, color: gold),
              ),
              const SizedBox(height: 13),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'ZOONL ID: $zoonlId',
                style: const TextStyle(color: gold, letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Text(
                db.auth.currentUser?.email ?? '',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _profileInfo('User Level', _value(profile['user_level'], '0')),
        _profileInfo('Country', _value(profile['country'])),
        _profileInfo('Verified', profile['is_verified'] == true ? 'Yes' : 'No'),
        _profileInfo('PRIME Memberships', '${memberships.length}'),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () async {
            await db.auth.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('SIGN OUT'),
          style: OutlinedButton.styleFrom(
            foregroundColor: pink,
            side: const BorderSide(color: pink),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _profileInfo(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _metric(String title, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 22),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(title, style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _feature(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: gold, size: 25),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _empty(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: gold, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

