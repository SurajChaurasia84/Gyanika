// ================= CREATE USERNAME SCREEN =================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'select_category_screen.dart';

class CreateUsernameScreen extends StatefulWidget {
  const CreateUsernameScreen({super.key});

  @override
  State<CreateUsernameScreen> createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();

  Timer? _debounce;
  bool checking = false;
  bool? isAvailable;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  List<String> suggestions = [];

  /// ---------------- USERNAME CHANGE ----------------
  void onUsernameChanged(String value) {
    final username = value.toLowerCase().trim();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      checkUsername(username);
      generateSuggestions(username);
    });
  }

  /// ---------------- CHECK USERNAME ----------------
  Future<void> checkUsername(String value) async {
    if (value.length < 4) {
      setState(() => isAvailable = null);
      return;
    }

    final regex = RegExp(r'^[a-z0-9._]+$');
    if (!regex.hasMatch(value)) {
      setState(() => isAvailable = false);
      return;
    }

    setState(() => checking = true);

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: value)
        .limit(1)
        .get();

    setState(() {
      isAvailable = snap.docs.isEmpty;
      checking = false;
    });
  }

  /// ---------------- SUGGESTIONS ----------------
  void generateSuggestions(String base) {
    if (base.length < 3) {
      setState(() => suggestions.clear());
      return;
    }

    setState(() {
      suggestions = [
        "${base}_edu",
        "${base}_official",
        "${base}01",
        "$base.in",
        "real_$base",
      ];
    });
  }

  /// ---------------- SAVE USERNAME ----------------
  Future<void> saveUsername() async {
    if (isAvailable != true) return;

    final username = _usernameController.text.trim().toLowerCase();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'username': username,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectCategoryScreen()),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Username")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Choose a unique username",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text("Letters, numbers, . and _ only"),
              const SizedBox(height: 20),

              /// USERNAME FIELD
              TextField(
                controller: _usernameController,
                onChanged: onUsernameChanged,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  prefixText: '@ ',
                  labelText: "Username",
                  border: const OutlineInputBorder(),
                  suffixIcon: checking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : isAvailable == null
                          ? null
                          : Icon(
                              isAvailable!
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  isAvailable! ? Colors.green : Colors.red,
                            ),
                ),
              ),

              const SizedBox(height: 8),

              if (isAvailable == false)
                const Text(
                  "Username not available",
                  style: TextStyle(color: Colors.red),
                ),

              if (isAvailable == true)
                const Text(
                  "Username available",
                  style: TextStyle(color: Colors.green),
                ),

              /// SUGGESTIONS
              if (suggestions.isNotEmpty && isAvailable != true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestions.map((s) {
                      return ActionChip(
                        label: Text("@$s"),
                        onPressed: () {
                          _usernameController.text = s;
                          onUsernameChanged(s);
                        },
                      );
                    }).toList(),
                  ),
                ),

              const Spacer(),

              /// CONTINUE BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isAvailable == true ? saveUsername : null,
                  child: const Text("Continue"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
