
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ZoonlLive());
}

const Color bg = Color(0xFF090D13);
const Color surface = Color(0xFF151D27);
const Color gold = Color(0xFFC9AD7A);
const Color white = Color(0xFFF3EEE5);
const Color grey = Color(0xFF9AA6B3);

// Existing Supabase tables. No demo records are created here.
const List<String> zoonlTables = [
  'profiles',
  'level_definitions',
  'prime_tiers',
  'user_prime_memberships',
  'wallets',
  'wallet_transactions',
  'gift_catalog',
  'gift_sends',
  'entry_effects',
  'user_entry_preferences',
  'reward_catalog',
  'reward_claims',
  'live_rooms',
  'live_room_members',
  'call_history',
  'level_effect_catalog',
  'user_level_effects',
  'profile_visual_effect_catalog',
  'user_profile_visuals',
  'room_entry_effect_catalog',
  'room_display_settings',
  'room_showcase_status',
];

class ZoonlLive extends StatelessWidget {
  const ZoonlLive({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZOONL LIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          surface: surface,
        ),
        useMaterial3: true,
      ),
      home: const LiveDataScreen(),
    );
  }
}

class LiveDataScreen extends StatefulWidget {
  const LiveDataScreen({super.key});

  @override
  State<LiveDataScreen> createState() => _LiveDataScreenState();
}

class _LiveDataScreenState extends State<LiveDataScreen> {
  final client = Supabase.instance.client;

  bool loading = true;
  String? connectionError;
  final Map<String, List<Map<String, dynamic>>> records = {};
  final Map<String, String> tableErrors = {};

  @override
  void initState() {
    super.initState();
    loadOriginalData();
  }

  Future<void> loadOriginalData() async {
    setState(() {
      loading = true;
      connectionError = null;
      records.clear();
      tableErrors.clear();
    });

    try {
      for (final table in zoonlTables) {
        try {
          final result = await client
              .from(table)
              .select()
              .limit(100);

          records[table] = List<Map<String, dynamic>>.from(result);
        } catch (e) {
          tableErrors[table] = e.toString();
        }
      }
    } catch (e) {
      connectionError = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = records.values.fold<int>(
      0,
      (sum, rows) => sum + rows.length,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surface,
        title: const Text(
          'ZOONL LIVE',
          style: TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadOriginalData,
            icon: const Icon(Icons.refresh, color: gold),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: gold),
            )
          : RefreshIndicator(
              onRefresh: loadOriginalData,
              color: gold,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(total),
                  if (connectionError != null)
                    _errorCard('Connection', connectionError!),
                  const SizedBox(height: 12),
                  for (final table in zoonlTables)
                    _tableCard(table),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORIGINAL SUPABASE DATA',
            style: TextStyle(
              color: gold,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$total',
            style: const TextStyle(
              color: white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Records loaded from accessible tables',
            style: TextStyle(color: grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in: ${client.auth.currentUser == null ? "No" : "Yes"}',
            style: const TextStyle(color: grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(String table) {
    final rows = records[table];
    final error = tableErrors[table];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF303A46)),
      ),
      child: ExpansionTile(
        iconColor: gold,
        collapsedIconColor: grey,
        title: Text(
          table,
          style: const TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          error != null
              ? 'Not accessible'
              : '${rows?.length ?? 0} records loaded',
          style: TextStyle(
            color: error != null ? Colors.orangeAccent : grey,
            fontSize: 11,
          ),
        ),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            )
          else if (rows == null || rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No records returned by Supabase.',
                style: TextStyle(color: grey),
              ),
            )
          else
            for (int i = 0; i < rows.length; i++)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D141D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  rows[i].entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join('\n'),
                  style: const TextStyle(
                    color: white,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _errorCard(String title, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$title: $error',
        style: const TextStyle(color: Colors.orangeAccent),
      ),
    );
  }
}
