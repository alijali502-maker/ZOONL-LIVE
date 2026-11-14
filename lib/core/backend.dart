import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  static SupabaseClient get db => Supabase.instance.client;

  static Future<void> initialize({
    required String supabaseUrl,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
    );
  }

  static User? get currentUser => db.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Future<List>> fetchZoonlLiveFeed() async {
    final response = await db
        .from('zoonl_api_full_feed')
        .select()
        .order('sort_order', ascending: true);
    return List>.from(response);
  }

  static Future<dynamic> sendZoonlLiveGift({
    required String senderId,
    required String receiverId,
    required String giftCode,
  }) async {
    return await db.rpc('zoonl_send_live_gift', params: {
      'p_sender_id': senderId,
      'p_receiver_id': receiverId,
      'p_zoonl_gift_code': giftCode,
    });
  }

  static Future<dynamic> equipZoonlCosmetic({
    required String userId,
    required String itemCode,
  }) async {
    return await db.rpc('zoonl_equip_cosmetic', params: {
      'p_user_id': userId,
      'p_zoonl_item_code': itemCode,
    });
  }
}
