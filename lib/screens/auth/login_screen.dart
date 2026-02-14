import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool isPasswordVisible = false;
  bool _sendingReset = false;
  DateTime? _lastResetSentAt;
  Timer? _cooldownTimer;
  static const Duration _resetCooldown = Duration(seconds: 60);

  int get _cooldownLeftSeconds {
    if (_lastResetSentAt == null) return 0;
    final endsAt = _lastResetSentAt!.add(_resetCooldown);
    final remaining = endsAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  bool get _canSendReset => !_sendingReset && _cooldownLeftSeconds == 0;

  void _startCooldownTicker() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownLeftSeconds == 0) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  Future login() async {
    if (email.text.isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }

    setState(() => loading = true);

    try {
      final user = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      if (!user.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email before login')),
        );
        setState(() => loading = false);
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (!_canSendReset) {
      final left = _cooldownLeftSeconds;
      if (left > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please wait ${left}s before requesting again')),
        );
      }
      return;
    }

    final mail = email.text.trim();
    if (mail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    try {
      setState(() => _sendingReset = true);
      if (!mounted) return;
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Confirm reset'),
            content: Text('Send password reset link to\n$mail ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Send link'),
              ),
            ],
          );
        },
      );

      if (shouldSend != true) {
        if (mounted) setState(() => _sendingReset = false);
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: mail);
      if (!mounted) return;
      setState(() {
        _sendingReset = false;
        _lastResetSentAt = DateTime.now();
      });
      _startCooldownTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent to your email')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _sendingReset = false);
      final message = e.code == 'invalid-email'
          ? 'Please enter a valid email'
          : 'Unable to send reset email right now';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process request right now')),
      );
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2364), Color(0xFF090D1A)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.transparent),
              ),
              Positioned(
                top: -80,
                right: -60,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                  SizedBox(
                        height: 120,
                        child: Image.asset('assets/src/icon.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 82),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: email,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.50)),
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.78)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          prefixIcon: const Icon(Iconsax.sms, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        style: const TextStyle(color: Colors.white),
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.50)),
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.78)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          prefixIcon: const Icon(Iconsax.lock, color: Colors.white),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible ? Iconsax.eye : Iconsax.eye_slash,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: (loading || !_canSendReset)
                              ? null
                              : _forgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(
                              _canSendReset ? 0.92 : 0.55,
                            ),
                            disabledForegroundColor: Colors.white.withOpacity(0.55),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _sendingReset
                                ? 'Sending...'
                                : _cooldownLeftSeconds > 0
                                ? 'Forgot password? (${_cooldownLeftSeconds}s)'
                                : 'Forgot password?',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4E6BFF), Color(0xFF7A6BFF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x554E6BFF),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Colors.white.withOpacity(0.9)),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GyanikaSignupScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
