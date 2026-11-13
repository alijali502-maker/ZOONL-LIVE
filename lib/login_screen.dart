
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
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _register = false;
  bool _hidePassword = true;

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
        );

        if (result.session == null) {
          _show(
            'Registration सफल। Email में verification link खोलें, '
            'फिर Login करें। ZOONL ID अपने आप बनेगी।',
          );
        } else {
          _show('Account बन गया। आपका ZOONL ID अपने आप बन गया है।');
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
        _show('यह Email पहले से registered है। Register के बजाय Login करें।');
      } else if (m.contains('invalid login credentials')) {
        _show('Email या Password सही नहीं है।');
      } else if (m.contains('email not confirmed')) {
        _show('पहले अपने Email में verification link खोलें।');
      } else {
        _show(e.message);
      }
    } catch (_) {
      _show('अनुरोध पूरा नहीं हुआ। Internet जाँचकर फिर कोशिश करें।');
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
      _show('Password reset link भेजने का अनुरोध किया गया है। Email जाँचें।');
    } on AuthException catch (e) {
      _show(e.message);
    } catch (_) {
      _show('Password reset अभी पूरा नहीं हुआ। फिर कोशिश करें।');
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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
            child: Form(
              key: _formKey,
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
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 17),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autofillHints: _register
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
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
                    validator: (v) =>
                        (v ?? '').length >= 6
                            ? null
                            : 'Password कम से कम 6 characters का रखें',
                    onFieldSubmitted: (_) {
                      if (!_loading) _submit();
                    },
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
                    )
                  else
                    const SizedBox(height: 18),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9636F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _register ? 'CREATE ACCOUNT' : 'LOGIN',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _password.clear();
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
                  const Text(
                    'Your permanent ZOONL ID is created automatically after registration.',
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
