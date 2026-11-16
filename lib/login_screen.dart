
import 'dart:math' as math;
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

  String get _normalizedCountryCode =>
      _countryCode.text.trim().replaceAll(' ', '');

  String get _normalizedPhone {
    var number = _phone.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (number.startsWith('0')) {
      number = number.substring(1);
    }
    return number;
  }

  String get _fullPhone =>
      '$_normalizedCountryCode$_normalizedPhone';

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
          backgroundColor: const Color(0xFF211735),
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
        final result = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            if (_name.text.trim().isNotEmpty)
              'display_name': _name.text.trim(),
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

      if (message.contains('already registered') ||
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
          if (_register && _name.text.trim().isNotEmpty)
            'display_name': _name.text.trim(),
        },
      );

      if (!mounted) return;
      setState(() => _otpSent = true);
      _show('OTP भेजने का अनुरोध सफल हुआ। SMS जाँचें।');
    } on AuthException catch (error) {
      _show(error.message);
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
      await _supabase.auth.signInWithOAuth(provider);
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
      await _supabase.auth.resetPasswordForEmail(email);
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

  Widget _logoBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF42166B),
            Color(0xFF1B0D30),
            Color(0xFF090713),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE6C47A).withOpacity(0.65),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9636F5).withOpacity(0.3),
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
              _tag('CREATOR VIP', const Color(0xFFE6C47A)),
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
              color: Color(0xFFFFE6A8),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [
                Shadow(
                  color: Color(0xFFB65CFF),
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
              color: Color(0xFFE6C47A),
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
            ),
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
              textCapitalization: TextCapitalization.words,
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
                  if (_phoneMode) _phoneForm() else _emailForm(),
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
                        color: Color(0xFFD0A4FF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: Color(0xFF49365F)),
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
                        child: Divider(color: Color(0xFF49365F)),
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
    final gold = const Color(0xFFFFD982);
    final purple = const Color(0xFFB65CFF);
    final pink = const Color(0xFFFF65C8);

    final glow = Paint()
      ..color = purple.withOpacity(0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    canvas.drawCircle(center, 82, glow);

    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFE7A5),
          Color(0xFFB65CFF),
          Color(0xFFFF65C8),
          Color(0xFFFFE7A5),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: 78),
      );

    canvas.drawCircle(center, 77, outer);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withOpacity(0.7);

    canvas.drawCircle(center, 68, inner);

    // Crown above the Z.
    final crownPath = Path()
      ..moveTo(center.dx - 38, center.dy - 53)
      ..lineTo(center.dx - 43, center.dy - 78)
      ..lineTo(center.dx - 20, center.dy - 64)
      ..lineTo(center.dx, center.dy - 88)
      ..lineTo(center.dx + 20, center.dy - 64)
      ..lineTo(center.dx + 43, center.dy - 78)
      ..lineTo(center.dx + 38, center.dy - 53)
      ..close();

    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF0B5),
          Color(0xFFE6B957),
          Color(0xFF9D5B19),
        ],
      ).createShader(
        Rect.fromLTWH(
          center.dx - 45,
          center.dy - 90,
          90,
          40,
        ),
      );

    canvas.drawPath(crownPath, crownPaint);

    final crownLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFF0C0);

    canvas.drawPath(crownPath, crownLine);

    // Large stylized Z.
    final zPath = Path()
      ..moveTo(center.dx - 36, center.dy - 35)
      ..lineTo(center.dx + 35, center.dy - 35)
      ..lineTo(center.dx - 32, center.dy + 31)
      ..lineTo(center.dx + 37, center.dy + 31);

    final zPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF0B5),
          Color(0xFFFFD05A),
          Color(0xFFB65CFF),
          Color(0xFFFF65C8),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: 90,
          height: 90,
        ),
      );

    canvas.drawPath(zPath, zPaint);

    // Broadcast signal arcs.
    final signalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = pink;

    for (int i = 0; i < 3; i++) {
      final radius = 47.0 + i * 10;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(center.dx + 47, center.dy - 20),
          radius: radius,
        ),
        -0.8,
        1.0,
        false,
        signalPaint..color = pink.withOpacity(1 - i * 0.22),
      );
    }

    // Small decorative stars.
    final starPaint = Paint()..color = gold;
    final points = [
      Offset(center.dx - 65, center.dy - 12),
      Offset(center.dx + 62, center.dy + 43),
      Offset(center.dx - 50, center.dy + 51),
      Offset(center.dx + 10, center.dy - 96),
    ];

    for (final point in points) {
      canvas.drawCircle(point, 2.5, starPaint);
      canvas.drawLine(
        Offset(point.dx - 5, point.dy),
        Offset(point.dx + 5, point.dy),
        starPaint,
      );
      canvas.drawLine(
        Offset(point.dx, point.dy - 5),
        Offset(point.dx, point.dy + 5),
        starPaint,
      );
    }

    // Small central jewel on the crown.
    final jewel = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFB5E8),
          Color(0xFFB65CFF),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(center.dx, center.dy - 67),
          radius: 7,
        ),
      );

    canvas.drawCircle(
      Offset(center.dx, center.dy - 67),
      6,
      jewel,
    );
  }

  @override
  bool shouldRepaint(covariant ZoonlLogoPainter oldDelegate) => false;
}
