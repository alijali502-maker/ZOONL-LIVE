import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // Login
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Registration
  static Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  // Logout
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Current User
  static User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // Login Status
  static bool get isLoggedIn {
    return currentUser != null;
  }

  // Auth Changes
  static Stream<AuthState> get authChanges {
    return _supabase.auth.onAuthStateChange;
  }
}