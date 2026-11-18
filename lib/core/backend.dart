import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authChanges =>
      client.auth.onAuthStateChange;

  // Initialize Supabase
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (supabaseUrl.trim().isEmpty ||
        supabaseAnonKey.trim().isEmpty) {
      throw ArgumentError(
        'Supabase URL और Anon Key जरूरी हैं।',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl.trim(),
      anonKey: supabaseAnonKey.trim(),
    );
  }

  // RPC / query responses can be a List or a single Map.
  static List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (response is Map) {
      return <Map<String, dynamic>>[
        Map<String, dynamic>.from(response),
      ];
    }
    return <Map<String, dynamic>>[];
  }

  // Fetch ZOONL LIVE Feed
  static Future<List<Map<String, dynamic>>> fetchZoonlLiveFeed({
    int limit = 50,
  }) async {
    try {
      final dynamic response = await client
          .from('zoonl_live_feed')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return _asRows(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception('Live Feed लोड नहीं हो सकी: $e');
    }
  }

  // Send ZOONL LIVE Gift
  //
  // SECURITY: the sender is ALWAYS the logged-in user (auth.uid() on the
  // server). Coins are NEVER sent by the client; the server looks up the
  // price from the gift catalog, checks the balance and deducts it in
  // one transaction. See supabase_zoonl_setup.sql.
  static Future<List<Map<String, dynamic>>> sendZoonlLiveGift({
    required String receiverId,
    required String giftCode,
  }) async {
    final String receiver = receiverId.trim();
    final String code = giftCode.trim();

    if (receiver.isEmpty || code.isEmpty) {
      throw ArgumentError(
        'Receiver ID और Gift Code जरूरी हैं।',
      );
    }

    final String? me = currentUserId;
    if (me == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    if (me == receiver) {
      throw ArgumentError(
        'आप खुद को Gift नहीं भेज सकते।',
      );
    }

    try {
      final dynamic response = await client.rpc(
        'send_zoonl_gift',
        params: <String, dynamic>{
          'p_receiver': receiver,
          'p_gift_code': code,
        },
      );

      return _asRows(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception('Gift भेजने में समस्या हुई: $e');
    }
  }

  // Equip ZOONL Cosmetic
  //
  // SECURITY: the server equips the item only if the logged-in user
  // already owns it. The client cannot choose another user's ID.
  static Future<List<Map<String, dynamic>>> equipZoonlCosmetic({
    required String itemCode,
  }) async {
    final String code = itemCode.trim();

    if (code.isEmpty) {
      throw ArgumentError('Item Code जरूरी है।');
    }

    if (currentUserId == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    try {
      final dynamic response = await client.rpc(
        'equip_zoonl_cosmetic',
        params: <String, dynamic>{
          'p_item_code': code,
        },
      );

      return _asRows(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Cosmetic Equip करने में समस्या हुई: $e',
      );
    }
  }

  // Trusted role checks. These RPCs are authoritative; client IDs are not.
  static Future<bool> isZoonlOwner() async {
    if (currentUserId == null) return false;
    final dynamic result = await client.rpc('is_zoonl_owner');
    return result == true;
  }

  static Future<bool> isZoonlAdminAllowed(String permissionKey) async {
    if (currentUserId == null || permissionKey.trim().isEmpty) {
      return false;
    }
    final dynamic result = await client.rpc(
      'is_zoonl_admin_allowed',
      params: <String, dynamic>{
        'p_permission_key': permissionKey.trim(),
      },
    );
    return result == true;
  }

  // Read-only portal access to existing application tables.
  // Table names are allow-listed; row access is still enforced by Supabase RLS.
  static Future<List<Map<String, dynamic>>> fetchPortalRows(
    String tableName, {
    int limit = 50,
  }) async {
    const Set<String> allowedTables = <String>{
      'owner_admin_permissions',
      'agency_applications',
      'profiles',
      'wallet_transactions',
      'wallets',
      'gifts',
      'live_rooms',
      'owner_control_settings',
    };
    if (!allowedTables.contains(tableName)) {
      throw ArgumentError('Portal table is not allow-listed.');
    }
    if (currentUserId == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }
    final dynamic response = await client
        .from(tableName)
        .select()
        .limit(limit.clamp(1, 100).toInt());
    return _asRows(response);
  }

  // Sign Out
  static Future<void> logout() async {
    await client.auth.signOut();
  }
}
