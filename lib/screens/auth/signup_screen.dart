import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import 'email_verification_screen.dart';

class GyanikaSignupScreen extends StatefulWidget {
  const GyanikaSignupScreen({super.key});

  @override
  State<GyanikaSignupScreen> createState() => _GyanikaSignupScreenState();
}

class _GyanikaSignupScreenState extends State<GyanikaSignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;
  bool isPasswordVisible = false;

  Future<void> signup() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => loading = true);

    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final User user = userCred.user!;
      await user.updateDisplayName(nameController.text.trim());
      await user.reload();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      await user.sendEmailVerification();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EmailVerificationScreen(user: user)),
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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
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
                    children: [
                      const SizedBox(height: 80),
                      SizedBox(
                        height: 120,
                        child: Image.asset('assets/src/icon.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 52),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter your name',
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
                          prefixIcon: const Icon(Iconsax.user, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
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
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        style: const TextStyle(color: Colors.white),
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
                      const SizedBox(height: 20),
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
                            onPressed: loading ? null : signup,
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
                                    'Create Account',
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
                            'Already have an account? ',
                            style: TextStyle(color: Colors.white.withOpacity(0.9)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Login',
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
