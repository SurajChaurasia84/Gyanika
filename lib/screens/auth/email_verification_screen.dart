import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'username_setup.dart';
// import '../main_screen.dart'; // ✅ your MainScreen

class EmailVerificationScreen extends StatefulWidget {
  final User user;

  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  int resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  /// 🔹 Check email verification every 2 seconds
  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await widget.user.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        _timer?.cancel();

        /// 🔹 Update Firestore verified status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'verified': true});

        if (!mounted) return;

        /// ✅ Redirect to main screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CreateUsernameScreen()),
          (route) => false,
        );
      }
    });
  }

  /// 🔹 Resend verification email with cooldown
  Future<void> _resendEmail() async {
    if (resendCooldown > 0) return;

    await widget.user.sendEmailVerification();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Verification email sent")),
    );

    setState(() => resendCooldown = 30);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => resendCooldown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              size: 90,
              color: Colors.indigo,
            ),
            const SizedBox(height: 20),
            Text(
              "We’ve sent a verification link to:\n\n${widget.user.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              "Please verify your email to continue.\n"
              "You will be redirected automatically after verification.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            /// 🔄 Resend Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: resendCooldown == 0 ? _resendEmail : null,
                child: Text(
                  resendCooldown == 0
                      ? "Resend Email"
                      : "Resend in $resendCooldown s",
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🚪 Logout Button
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
