// ================= SELECT CATEGORY SCREEN =================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../main.dart'; // 👈 GyanikaApp / MyApp

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({super.key});

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final user = FirebaseAuth.instance.currentUser!;

  final List<String> categories = [
    'Mathematics',
    'Science',
    'Technology',
    'General Knowledge',
    'Computer',
    'Engineering',
    'Environment',
    'Social Science',
    'Logical Reasoning',
    'Other',
  ];

  final List<String> selected = [];

  bool loading = false;

  /// ---------------- SAVE CATEGORIES + USER DOC ----------------
  Future<void> saveCategories() async {
    if (selected.length < 3) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      /// 🔑 BASIC IDENTITY
      'uid': uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',

      /// 🎯 PERSONALIZATION
      'categories': selected,

      /// 📊 COUNTERS
      'followers': 0,
      'following': 0,
      'posts': 0,

      /// 🕒 META
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': true,
    }, SetOptions(merge: true)); // 👈 VERY IMPORTANT

    if (!mounted) return;

    /// 🚀 FINAL ENTRY → MAIN APP
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GyanikaApp()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Categories")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personalize your feed",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text("Select at least 3 categories"),
              const SizedBox(height: 16),

              /// 🏷 CATEGORY CHIPS
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories.map((cat) {
                    final isSelected = selected.contains(cat);
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: Colors.indigo.shade200,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            if (!selected.contains(cat)) {
                              selected.add(cat);
                            }
                          } else {
                            selected.remove(cat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),

              /// ✅ CONTINUE BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      selected.length >= 3 && !loading ? saveCategories : null,
                  child: loading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text("Continue (${selected.length}/3)"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
