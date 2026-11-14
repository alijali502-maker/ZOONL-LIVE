
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
        _show('Login सफल हुआ।');
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
      prefixIcon: Icon(icon, color: const Color(0xFFBD78FF)),
      filled: true,
      fillColor: const Color(0xFF191426),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF302342)),
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
              decoration: _input('Full Name', Icons.person_outline),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            decoration: _input('Email Address', Icons.email_outlined),
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
            decoration: _input('Password', Icons.lock_outline).copyWith(
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
            validator: (v) =>
                (v ?? '').length >= 6
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
                  style: TextStyle(color: Color(0xFFC58AFF)),
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
              decoration: _input('Full Name', Icons.person_outline),
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
            decoration: _input('Enter OTP', Icons.password),
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
              style: TextStyle(color: Color(0xFFC58AFF)),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _sendPhoneOtp,
            child: const Text(
              'Resend OTP',
              style: TextStyle(color: Color(0xFFC58AFF)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback action) {
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 88,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF211331),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 48,
                    color: Color(0xFFD4A0FF),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ZOONL LIVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _register ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 25),
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
                const SizedBox(height: 22),
                if (_phoneMode) _phoneForm() else _emailForm(),
                const SizedBox(height: 15),
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
                const SizedBox(height: 15),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF49365F))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF49365F))),
                  ],
                ),
                const SizedBox(height: 15),
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
                const SizedBox(height: 20),
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

                      