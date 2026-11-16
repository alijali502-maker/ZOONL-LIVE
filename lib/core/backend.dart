
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

  // Send ZOONL LIVE Gift
  static Future<List<Map<String, dynamic>>>
      sendZoonlLiveGift({
    required String senderId,
    required String receiverId,
    required String giftCode,
    required int coins,
  }) async {
    final sender = senderId.trim();
    final receiver = receiverId.trim();
    final code = giftCode.trim();

    if (sender.isEmpty ||
        receiver.isEmpty ||
        code.isEmpty) {
      throw ArgumentError(
        'Sender ID, Receiver ID और Gift Code जरूरी हैं।',
      );
    }

    if (sender == receiver) {
      throw ArgumentError(
        'आप खुद को Gift नहीं भेज सकते।',
      );
    }

    if (coins <= 0) {
      throw ArgumentError(
        'Gift Coins की संख्या शून्य से अधिक होनी चाहिए।',
      );
    }

    if (currentUser == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    try {
      final response = await client
          .from('zoonl_live_gifts')
          .insert({
            'sender_id': sender,
            'receiver_id': receiver,
            'gift_code': code,
            'coins': coins,
          })
          .select();

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException {
      rethrow;
    } catch (e) {
      throw Exception('Gift भेजने में समस्या हुई: $e');
    }
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

    if (currentUser == null) {
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
