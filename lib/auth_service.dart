import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authChanges =>
      _supabase.auth.onAuthStateChange;

  // ---------- Helpers ----------

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static void _requireRedirect(String redirectTo) {
    if (redirectTo.trim().isEmpty) {
      throw ArgumentError('OAuth redirect URL जरूरी है।');
    }
  }

  // Email Login
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email और Password जरूरी हैं।');
    }

    return _supabase.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  // Email Registration
  static Future<AuthResponse> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!_emailRegex.hasMatch(normalizedEmail) || password.length < 6) {
      throw ArgumentError(
        'सही Email और कम से कम 6 characters का Password दें।',
      );
    }

    final name = fullName?.trim();

    return _supabase.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: {
        if (name != null && name.isNotEmpty) 'display_name': name,
      },
    );
  }

  // Phone OTP
  static Future<void> sendPhoneOtp({
    required String phone,
    bool shouldCreateUser = false,
    String? fullName,
  }) async {
    final normalizedPhone = phone.trim();

    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(normalizedPhone)) {
      throw ArgumentError(
        'International format में सही Phone Number दें। उदाहरण: +971501234567',
      );
    }

    final name = fullName?.trim();

    await _supabase.auth.signInWithOtp(
      phone: normalizedPhone,
      shouldCreateUser: shouldCreateUser,
      data: {
        if (shouldCreateUser && name != null && name.isNotEmpty)
          'display_name': name,
      },
    );
  }

  // Verify Phone OTP
  static Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final normalizedPhone = phone.trim();
    final normalizedToken = token.trim();

    if (normalizedPhone.isEmpty ||
        !RegExp(r'^[0-9]{4,8}$').hasMatch(normalizedToken)) {
      throw ArgumentError('सही Phone Number और OTP दें।');
    }

    return _supabase.auth.verifyOTP(
      phone: normalizedPhone,
      token: normalizedToken,
      type: OtpType.sms,
    );
  }

  // Google Login
  static Future<bool> loginWithGoogle({
    required String redirectTo,
  }) async {
    _requireRedirect(redirectTo);

    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  // Facebook Login
  static Future<bool> loginWithFacebook({
    required String redirectTo,
  }) async {
    _requireRedirect(redirectTo);

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
    final normalizedEmail = email.trim().toLowerCase();

    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw ArgumentError('सही Email Address दें।');
    }

    if (redirectTo.trim().isEmpty) {
      throw ArgumentError('Redirect URL जरूरी है।');
    }

    await _supabase.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: redirectTo,
    );
  }

  // Update Password after password recovery
  static Future<UserResponse> updatePassword({
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError(
        'Password कम से कम 6 characters का होना चाहिए।',
      );
    }

    return _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Logout
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Link another supported identity to the current account.
  // The provider must be supported and configured in Supabase,
  // and "Manual Linking" must be enabled in the Supabase dashboard.
  static Future<bool> linkIdentity(
    OAuthProvider provider, {
    required String redirectTo,
  }) async {
    if (currentUser == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    _requireRedirect(redirectTo);

    return _supabase.auth.linkIdentity(
      provider,
      redirectTo: redirectTo,
    );
  }

  // Unlink an identity from the current account.
  static Future<void> unlinkIdentity(
    UserIdentity identity,
  ) async {
    final user = currentUser;

    if (user == null) {
      throw StateError('पहले Login करना जरूरी है।');
    }

    // Supabase requires at least 2 identities to unlink one.
    final identities = user.identities;
    if (identities != null && identities.length < 2) {
      throw StateError(
        'कम से कम एक Login method जुड़ा रहना जरूरी है।',
      );
    }

    await _supabase.auth.unlinkIdentity(identity);
  }

  // Refresh current session
  static Future<AuthResponse> refreshSession() async {
    return _supabase.auth.refreshSession();
  }
}
