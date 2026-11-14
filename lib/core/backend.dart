import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class Backend {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static Future<List> fetchZoonlLiveFeed() async {
    final response = await client
        .from('zoonl_live_feed')
        .select()
        .order('created_at', ascending: false);
    if (response is List) {
      return List.from(response);
    }
    return [];
  }

  static Future<dynamic> sendZoonlLiveGift({
    required String senderId,
    required String receiverId,
    required String giftCode,
    required int coins,
  }) async {
    final response = await client.from('zoonl_live_gifts').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'gift_code': giftCode,
      'coins': coins,
    }).select();
    return response;
  }

  static Future<dynamic> equipZoonlCosmetic({
    required String userId,
    required String itemCode,
  }) async {
    final response = await client.from('zoonl_user_cosmetics').upsert({
      'user_id': userId,
      'item_code': itemCode,
      'is_equipped': true,
    }).select();
    return response;
  }
}

