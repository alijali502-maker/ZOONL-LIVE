import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // IMPORTANT: यह deep link आपके app के setup से मेल खाना चाहिए
  // (AndroidManifest / Info.plist) और Supabase Dashboard ->
  // Authentication -> URL Configuration -> Redirect URLs में add होना चाहिए।
  static const String _mobileRedirect =
      'io.supabase.flutter://login-callback/';

  String? get _redirectTo => kIsWeb ? null : _mobileRedirect;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _countryCode = TextEditingController(text: '+971');
  DateTime? _dateOfBirth;

  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _register = false;
  bool _hidePassword = true;
  bool _phoneMode = false;
  bool _otpSent = false;

  String get _normalizedCountryCode {
    final code = _countryCode.text.trim().replaceAll(' ', '');
    if (code.isEmpty || code.startsWith('+')) return code;
    return '+$code';
  }

  String get _normalizedPhone {
    var number = _phone.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (number.startsWith('0')) {
      number = number.substring(1);
    }
    return number;
  }

  String get _fullPhone =>
      '$_normalizedCountryCode$_normalizedPhone';

  String get _dobValue => _dateOfBirth == null
      ? ''
      : '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'CONFIRM DATE OF BIRTH',
    );
    if (value != null && mounted) setState(() => _dateOfBirth = value);
  }

  Widget _dateOfBirthField() => InkWell(
    onTap: _loading ? null : _pickDateOfBirth,
    borderRadius: BorderRadius.circular(15),
    child: InputDecorator(
      decoration: _input('Date of Birth', Icons.calendar_month),
      child: Text(
        _dateOfBirth == null ? 'Select your date of birth' : _dobValue,
        style: TextStyle(color: _dateOfBirth == null ? Colors.white54 : Colors.white),
      ),
    ),
  );

  bool get _validPhone =>
      RegExp(r'^\+[1-9][0-9]{0,2}$').hasMatch(_normalizedCountryCode) &&
      RegExp(r'^[0-9]{6,15}$').hasMatch(_normalizedPhone);

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: const Color(0xFF1D2B37),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _authenticated() {
    if (mounted) widget.onAuthenticated?.call();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final email = _email.text.trim().toLowerCase();
      final password = _password.text;

      if (_register) {
        if (_name.text.trim().isEmpty || _dateOfBirth == null) {
          _show('Full Name और Date of Birth भरें।');
          return;
        }
        final result = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _redirectTo,
          data: {
            'display_name': _name.text.trim(),
            'date_of_birth': _dobValue,
          },
        );

        if (!mounted) return;

        if (result.session == null) {
          _show('Registration सफल। पहले Email verification करें।');
        } else {
          _show('Account सफलतापूर्वक बन गया।');
          _authenticated();
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        _show('Login सफल हुआ।');
        _authenticated();
      }
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();

      if (message.contains('signups not allowed') ||
          message.contains('signup is disabled') ||
          message.contains('signups are disabled')) {
        _show(
          'Supabase Auth में नए अकाउंट बनाने की अनुमति बंद है। '
          'मौजूदा अकाउंट Login कर सकते हैं; नए ID के लिए Auth signup '
          'अनुमति चालू होना जरूरी है।',
        );
      } else if (message.contains('already registered') ||
          message.contains('user already exists') ||
          message.contains('already been registered')) {
        _show('यह Email पहले से registered है। Login करें।');
      } else if (message.contains('invalid login credentials')) {
        _show('Email या Password सही नहीं है।');
      } else if (message.contains('email not confirmed')) {
        _show('पहले Email verification link खोलें।');
      } else {
        _show(error.message);
      }
    } catch (error) {
      _show('अनुरोध पूरा नहीं हुआ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    if (_loading) return;

    if (_register && (_name.text.trim().isEmpty || _dateOfBirth == null)) {
      _show('Full Name और Date of Birth भरें।');
      return;
    }

    if (!_validPhone) {
      _show('सही Country Code और Mobile Number भरें।');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _supabase.auth.signInWithOtp(
        phone: _fullPhone,
        shouldCreateUser: _register,
        data: {
          if (_register) ...{
            'display_name': _name.text.trim(),
            'date_of_birth': _dobValue,
          },
        },
      );

      if (!mounted) return;
      setState(() => _otpSent = true);
      _show('OTP भेजने का अनुरोध सफल हुआ। SMS जाँचें।');
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();

      if (message.contains('signups not allowed') ||
          message.contains('signup is disabled') ||
          message.contains('signups are disabled')) {
        _show(
          'Supabase Auth में नए अकाउंट बनाने की अनुमति बंद है। '
          'नया Phone ID बनाने के लिए Auth signup अनुमति चालू होना जरूरी है।',
        );
      } else if (message.contains('user not found')) {
        _show('यह Number registered नहीं है। पहले Account बनाएँ।');
      } else {
        _show(error.message);
      }
    } catch (error) {
      _show('OTP भेजा नहीं जा सका: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (_loading) return;

    final token = _otp.text.trim();

    if (!_validPhone ||
        !RegExp(r'^[0-9]{4,8}$').hasMatch(token)) {
      _show('Mobile Number और OTP दोबारा जाँचें।');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _supabase.auth.verifyOTP(
        phone: _fullPhone,
        token: token,
        type: OtpType.sms,
      );

      if (!mounted) return;
      _show('Mobile Number Verification सफल हुआ।');
      _authenticated();
    } on AuthException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('OTP Verification पूरा नहीं हुआ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialLogin(OAuthProvider provider) async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final launched = await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: _redirectTo,
      );

      if (!launched) {
        _show('Login page खोला नहीं जा सका। दोबारा कोशिश करें।');
      }
    } on AuthException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('Social Login पूरा नहीं हुआ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_loading) return;

    final email = _email.text.trim().toLowerCase();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _show('पहले सही Email Address भरें।');
      return;
    }

    setState(() => _loading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectTo,
      );
      if (!mounted) return;
      _show('Password reset link के लिए Email जाँचें।');
    } on AuthException catch (error) {
      _show(error.message);
    } catch (error) {
      _show('Password reset पूरा नहीं हुआ: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: const Color(0xFF9B8CFF)),
      filled: true,
      fillColor: const Color(0xFF0D1426),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF17232E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF58D6CE),
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
        side: const BorderSide(color: Color(0xFF2C3B59)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _logoBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2A4A),
            Color(0xFF0D1426),
            Color(0xFF070B17),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF9B8CFF).withOpacity(0.65),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF58D6CE).withOpacity(0.3),
            blurRadius: 26,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _tag('● LIVE STAGE', const Color(0xFFFF2E63)),
              const Spacer(),
              _tag('CREATOR VIP', const Color(0xFF9B8CFF)),
            ],
          ),
          const SizedBox(height: 10),

          // Original graphical logo, drawn directly in Flutter.
          SizedBox(
            height: 225,
            width: double.infinity,
            child: CustomPaint(
              painter: ZoonlLogoPainter(),
              child: const SizedBox.expand(),
            ),
          ),

          const Text(
            'ZOONL LIVE',
            style: TextStyle(
              color: Color(0xFFE4E8FF),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [
                Shadow(
                  color: Color(0xFF58D6CE),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Welcome to Live Streamer & Creator Arena',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9B8CFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _register
                ? 'Create your account and get your permanent ZOONL ID'
                : 'Enter the world of live rooms, gifts and VIP stage',
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

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
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
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              style: const TextStyle(color: Colors.white),
              decoration: _input('Full Name', Icons.person_outline),
              validator: (value) => (value ?? '').trim().isNotEmpty ? null : 'Full Name जरूरी है',
            ),
            const SizedBox(height: 12),
            _dateOfBirthField(),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            decoration: _input('Email Address', Icons.email_outlined),
            validator: (value) {
              final email = (value ?? '').trim();
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(email)
                  ? null
                  : 'सही Email Address भरें';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _hidePassword,
            autofillHints: _register
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            style: const TextStyle(color: Colors.white),
            decoration: _input('Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _hidePassword = !_hidePassword);
                },
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white70,
                ),
              ),
            ),
            validator: (value) => (value ?? '').length >= 6
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
                  style: TextStyle(color: Color(0xFF79D7C8)),
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
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: _input('Full Name', Icons.person_outline),
            ),
            const SizedBox(height: 12),
            _dateOfBirthField(),
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
                  autofillHints: const [
                    AutofillHints.telephoneNumber,
                  ],
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
              style: TextStyle(color: Color(0xFF79D7C8)),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _sendPhoneOtp,
            child: const Text(
              'Resend OTP',
              style: TextStyle(color: Color(0xFF79D7C8)),
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
          backgroundColor: const Color(0xFF58D6CE),
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

  Widget _modeButton(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return OutlinedButton(
      onPressed: _loading ? null : onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFF1B2A4A)
            : const Color(0xFF0D1426),
        foregroundColor: Colors.white,
        side: BorderSide(
          color: selected
              ? const Color(0xFF58D6CE)
              : const Color(0xFF17232E),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      child: Text(label),
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

  Widget _authGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xAA090909),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF202020),
              Color(0xFF090909),
              Color(0xFF050505),
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
                  _logoBanner(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _modeButton(
                          'EMAIL',
                          !_phoneMode,
                          () {
                            setState(() {
                              _phoneMode = false;
                              _otpSent = false;
                              _otp.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _modeButton(
                          'PHONE OTP',
                          _phoneMode,
                          () {
                            setState(() {
                              _phoneMode = true;
                              _otpSent = false;
                              _otp.clear();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _authGlass(child: _phoneMode ? _phoneForm() : _emailForm()),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _register = !_register;
                              _password.clear();
                              _otp.clear();
                              _otpSent = false;
                            });
                          },
                    child: Text(
                      _register
                          ? 'Already registered? Login'
                          : 'New user? Create an account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD2CEFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: Color(0x66FFFFFF)),
                      ),
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
                      Expanded(
                        child: Divider(color: Color(0xFF2C3B59)),
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
                    'Your permanent ZOONL ID is assigned by the secure registration system.',
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
}

// Custom illustrated ZOONL LIVE emblem.
class ZoonlLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / 220.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    final glow = Paint()
      ..color = const Color(0xFF786BFF).withOpacity(.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(center, 82, glow);

    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = const SweepGradient(colors: [
        Color(0xFF8CEBFF), Color(0xFF8F7BFF), Color(0xFFE4E8FF),
        Color(0xFF58D6CE), Color(0xFF8CEBFF),
      ]).createShader(Rect.fromCircle(center: center, radius: 78));
    canvas.drawCircle(center, 77, outer);

    final shield = Path()
      ..moveTo(center.dx, center.dy - 63)
      ..lineTo(center.dx + 53, center.dy - 38)
      ..lineTo(center.dx + 47, center.dy + 26)
      ..quadraticBezierTo(center.dx + 27, center.dy + 58, center.dx, center.dy + 67)
      ..quadraticBezierTo(center.dx - 27, center.dy + 58, center.dx - 47, center.dy + 26)
      ..lineTo(center.dx - 53, center.dy - 38)
      ..close();
    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF263B68), Color(0xFF151E3C), Color(0xFF10182E)],
      ).createShader(Rect.fromCenter(center: center, width: 112, height: 140));
    canvas.drawPath(shield, shieldPaint);
    canvas.drawPath(shield, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB6B4FF));

    // A broadcast aperture and play core, rather than a single-letter mark.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF69E4DF);
    canvas.drawCircle(center, 34, ringPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 46), -2.5, 1.15, false, ringPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 46), .35, 1.15, false, ringPaint);

    final play = Path()
      ..moveTo(center.dx - 10, center.dy - 17)
      ..quadraticBezierTo(center.dx - 14, center.dy - 20, center.dx - 14, center.dy - 11)
      ..lineTo(center.dx - 14, center.dy + 15)
      ..quadraticBezierTo(center.dx - 14, center.dy + 22, center.dx - 7, center.dy + 17)
      ..lineTo(center.dx + 17, center.dy + 3)
      ..quadraticBezierTo(center.dx + 24, center.dy - 1, center.dx + 17, center.dy - 6)
      ..close();
    canvas.drawPath(play, Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE4E8FF), Color(0xFF79E8E0)],
      ).createShader(Rect.fromCircle(center: center, radius: 30)));

    final crown = Path()
      ..moveTo(center.dx - 34, center.dy - 65)
      ..lineTo(center.dx - 28, center.dy - 82)
      ..lineTo(center.dx - 10, center.dy - 70)
      ..lineTo(center.dx, center.dy - 88)
      ..lineTo(center.dx + 10, center.dy - 70)
      ..lineTo(center.dx + 28, center.dy - 82)
      ..lineTo(center.dx + 34, center.dy - 65)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFC7C2FF));
    canvas.drawPath(crown, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFE7E9FF));

    final dot = Paint()..color = const Color(0xFF8CEBFF);
    for (final point in [
      Offset(center.dx - 59, center.dy - 8),
      Offset(center.dx + 59, center.dy - 8),
      Offset(center.dx, center.dy + 82),
    ]) {
      canvas.drawCircle(point, 3, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
