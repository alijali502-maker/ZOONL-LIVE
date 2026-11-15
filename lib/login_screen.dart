import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;

  const LoginScreen({
    super.key,
    this.onAuthenticated,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _countryCode = TextEditingController(text: '+971');

  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _register = false;
  bool _hidePassword = true;
  bool _phoneMode = false;
  bool _otpSent = false;

  String get _fullPhone =>
      '${_countryCode.text.trim()}${_phone.text.trim()}';

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: const Color(0xFF211735),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _authenticated() {
    if (!mounted) return;
    widget.onAuthenticated?.call();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final email = _email.text.trim().toLowerCase();

    try {
      if (_register) {
        final result = await _supabase.auth.signUp(
          email: email,
          password: _password.text,
          data: {
            if (_name.text.trim().isNotEmpty)
              'display_name': _name.text.trim(),
          },
        );

        if (result.session == null) {
          _show(
            'Registration सफल। Email verification करके Login करें। '
            'आपका ZOONL ID सिस्टम द्वारा बनाया जाएगा।',
          );
        } else {
          _show('Account बन गया।');
          _authenticated();
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );

        _show('Login सफल हुआ।');
        _authenticated();
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();

      if (m.contains('already registered') ||
          m.contains('user already exists') ||
          m.contains('already been registered')) {
        _show('यह Email पहले से registered है। Login करें।');
      } else if (m.contains('invalid login credentials')) {
        _show('Email या Password सही नहीं है।');
      } else if (m.contains('email not confirmed')) {
        _show('पहले Email verification link खोलें।');
      } else {
        _show(e.message);
      }
    } catch (e) {
      _show('अनुरोध पूरा नहीं हुआ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    if (_countryCode.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      _show('Country Code और Mobile Number भरें।');
      return;
    }

    if (!RegExp(r'^\+[1-9][0-9]{0,3}$')
        .hasMatch(_countryCode.text.trim())) {
      _show('सही Country Dial Code लिखें। उदाहरण: +971');
      return;
    }

    if (!RegExp(r'^[0-9]{6,15}$')
        .hasMatch(_phone.text.trim())) {
      _show('सही Mobile Number लिखें।');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _supabase.auth.signInWithOtp(
        phone: _fullPhone,
        shouldCreateUser: _register,
        data: {
          if (_register && _name.text.trim().isNotEmpty)
            'display_name': _name.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _otpSent = true);
      }

      _show('OTP भेजने का अनुरोध सफल हुआ। SMS जाँचें।');
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('OTP भेजा नहीं जा सका: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final token = _otp.text.trim();

    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(token)) {
      _show('सही OTP लिखें।');
      return;
    }

    setState(() => _loading = true);

    try {
      await _supabase.auth.verifyOTP(
        phone: _fullPhone,
        token: token,
        type: OtpType.sms,
      );

      _show('Mobile Number Verification सफल हुआ।');
      _authenticated();
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('OTP Verification पूरा नहीं हुआ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialLogin(OAuthProvider provider) async {
    setState(() => _loading = true);

    try {
      await _supabase.auth.signInWithOAuth(provider);
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('Social Login पूरा नहीं हुआ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim().toLowerCase();

    if (!email.contains('@') || !email.contains('.')) {
      _show('पहले सही Email Address भरें।');
      return;
    }

    setState(() => _loading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _show('Password reset link के लिए Email जाँचें।');
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('Password reset पूरा नहीं हुआ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFFBD78FF),
      ),
      filled: true,
      fillColor: const Color(0xFF191426),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF302342),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFB65CFF),
          width: 1.4,
        ),
      ),
    );
  }

  Widget _socialButton(
    String title,
    IconData icon,
    OAuthProvider provider,
  ) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : () => _socialLogin(provider),
      icon: Icon(icon),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF49365F)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _liveStreamerWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5A238C),
            Color(0xFF28123D),
            Color(0xFF130B20),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE6C47A).withOpacity(0.55),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9636F5).withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2E63),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'LIVE STAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6C47A).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE6C47A).withOpacity(0.45),
                  ),
                ),
                child: const Text(
                  'CREATOR VIP',
                  style: TextStyle(
                    color: Color(0xFFE6C47A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE6C47A),
                      Color(0xFFDA65C8),
                      Color(0xFF9636F5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDA65C8).withOpacity(0.4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF1A102B),
                  child: Icon(
                    Icons.face_retouching_natural,
                    size: 46,
                    color: Color(0xFFFFC6EB),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6C47A),
                ),
                child: const Icon(
                  Icons.mic,
                  size: 15,
                  color: Color(0xFF191026),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'ZOONL LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Welcome to Live Streamer & Creator Arena',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE6C47A),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _register
                ? 'Create your creator account & get your permanent ZOONL ID'
                : 'Sign in to enter live rooms, gifts & VIP stage',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_register) ...[
            TextFormField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: _input(
                'Full Name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Email Address',
              Icons.email_outlined,
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              return s.contains('@') && s.contains('.')
                  ? null
                  : 'सही Email Address भरें';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _hidePassword,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Password',
              Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _hidePassword = !_hidePassword,
                ),
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white70,
                ),
              ),
            ),
            validator: (v) => (v ?? '').length >= 6
                ? null
                : 'Password कम से कम 6 characters का रखें',
          ),
          if (!_register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: Color(0xFFC58AFF),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _primaryButton(
            _register ? 'CREATE ACCOUNT' : 'LOGIN',
            _submit,
          ),
        ],
      ),
    );
  }

  Widget _phoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_otpSent) ...[
          if (_register) ...[
            TextField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: _input(
                'Full Name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              SizedBox(
                width: 105,
                child: TextField(
                  controller: _countryCode,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input('Code', Icons.flag),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input(
                    'Mobile Number',
                    Icons.phone_android,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _primaryButton('SEND OTP', _sendPhoneOtp),
        ] else ...[
          Text(
            'OTP भेजा गया: $_fullPhone',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Enter OTP',
              Icons.password,
            ),
          ),
          const SizedBox(height: 15),
          _primaryButton('VERIFY OTP', _verifyPhoneOtp),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _otpSent = false;
                      _otp.clear();
                    });
                  },
            child: const Text(
              'Change Number',
              style: TextStyle(
                color: Color(0xFFC58AFF),
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _sendPhoneOtp,
            child: const Text(
              'Resend OTP',
              style: TextStyle(
                color: Color(0xFFC58AFF),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(
    String label,
    VoidCallback action,
  ) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9636F5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    _countryCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090713),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF23113A),
              Color(0xFF090713),
              Color(0xFF06040D),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _liveStreamerWelcomeBanner(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _modeButton(
                          'EMAIL',
                          !_phoneMode,
                          () => setState(() {
                            _phoneMode = false;
                            _otpSent = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _modeButton(
                          'PHONE OTP',
                          _phoneMode,
                          () => setState(() {
                            _phoneMode = true;
                            _otpSent = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_phoneMode)
                    _phoneForm()
                  else
                    _emailForm(),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _password.clear();
                              _otp.clear();
                              _otpSent = false;
                            }),
                    child: Text(
                      _register
                          ? 'Already registered? Login'
                          : 'New user? Create an account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD0A4FF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Color(0xFF49365F),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Color(0xFF49365F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _socialButton(
                    'Continue with Google',
                    Icons.g_mobiledata,
                    OAuthProvider.google,
                  ),
                  const SizedBox(height: 10),
                  _socialButton(
                    'Continue with Facebook',
                    Icons.facebook,
                    OAuthProvider.facebook,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your permanent ZOONL ID is assigned by the registration system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return OutlinedButton(
      onPressed: _loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFF542CA0)
            : const Color(0xFF191426),
        foregroundColor: Colors.white,
        side: BorderSide(
          color: selected
              ? const Color(0xFFB65CFF)
              : const Color(0xFF302342),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      child: Text(label),
    );
  }
}