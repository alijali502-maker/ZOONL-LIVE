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
}