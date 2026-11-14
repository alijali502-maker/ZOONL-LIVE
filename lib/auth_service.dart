
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Email Login
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Email Registration
  static Future<AuthResponse> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  // Phone OTP
  static Future<void> sendPhoneOtp({
    required String phone,
    bool shouldCreateUser = false,
  }) async {
    await _supabase.auth.signInWithOtp(
      phone: phone.trim(),
      shouldCreateUser: shouldCreateUser,
    );
  }

  // Verify Phone OTP
  static Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return _supabase.auth.verifyOTP(
      phone: phone.trim(),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  // Google Login
  static Future<bool> loginWithGoogle({
    required String redirectTo,
  }) async {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  // Facebook Login
  static Future<bool> loginWithFacebook({
    required String redirectTo,
  }) async {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: redirectTo,
    );
  }

  // Forgot Password
  static Future<void> resetPassword({
    required String email,
    required String redirectTo,
  }) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  // Logout
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Current User
  static User? get currentUser => _supabase.auth.currentUser;

  // Login Status
  static bool get isLoggedIn => currentUser != null;

  // Auth Changes
  static Stream<AuthState> get authChanges =>
      _supabase.auth.onAuthStateChange;
}
