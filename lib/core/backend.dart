
import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  static SupabaseClient get client =>
      Supabase.instance.client;

  static User? get currentUser =>
      client.auth.currentUser;

  static bool get isLoggedIn =>
      currentUser != null;

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

  // Fetch the authenticated user's profile
  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final user = currentUser;

    if (user == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response;
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception('Profile लोड नहीं हो सकी: $e');
    }
  }

  // Fetch ZOONL LIVE Feed
  static Future<List<Map<String, dynamic>>>
      fetchZoonlLiveFeed() async {
    try {
      final response = await client
          .from('zoonl_live_feed')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception('Live Feed लोड नहीं हो सकी: $e');
    }
  }

  // Send Gift
  // Wallet debit and receiver credit must be handled by
  // a secure server-side transaction, not by this client.
  static Future<List<Map<String, dynamic>>>
      sendZoonlLiveGift({
    required String senderId,
    required String receiverId,
    required String giftCode,
    required int coins,
  }) async {
    throw UnsupportedError(
      'Gift transaction अभी सुरक्षित Server-side Wallet '
      'से जुड़ी नहीं है। Gift भेजना फिलहाल उपलब्ध नहीं है।',
    );
  }

  // Equip ZOONL Cosmetic
  static Future<List<Map<String, dynamic>>>
      equipZoonlCosmetic({
    required String userId,
    required String itemCode,
  }) async {
    final id = userId.trim();
    final code = itemCode.trim();

    if (id.isEmpty || code.isEmpty) {
      throw ArgumentError(
        'User ID और Item Code जरूरी हैं।',
      );
    }

    final user = currentUser;

    if (user == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    try {
      final response = await client
          .from('zoonl_user_cosmetics')
          .upsert({
            'user_id': id,
            'item_code': code,
            'is_equipped': true,
          })
          .select();

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception(
        'Cosmetic Equip करने में समस्या हुई: $e',
      );
    }
  }

  // Sign Out
  static Future<void> logout() async {
    await client.auth.signOut();
  }
}
