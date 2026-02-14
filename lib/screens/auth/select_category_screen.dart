import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../main_screen.dart';

class SelectCategoryScreen extends StatefulWidget {
  final bool isUpdateMode;

  const SelectCategoryScreen({super.key, this.isUpdateMode = false});

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final user = FirebaseAuth.instance.currentUser!;
  late final Box _settingsBox;

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

  String get _categoriesCacheKey => 'user_categories_$uid';

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _loadExistingCategories();
  }

  Future<void> _loadExistingCategories() async {
    final cached = _settingsBox.get(_categoriesCacheKey);
    if (cached is List) {
      final values = cached
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && categories.contains(e))
          .toSet()
          .toList();
      if (values.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          selected
            ..clear()
            ..addAll(values);
        });
        return;
      }
    }

    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final existing = data['categories'];
    if (existing is! List) return;
    final values = existing
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty && categories.contains(e))
        .toSet()
        .toList();
    await _settingsBox.put(_categoriesCacheKey, values);
    if (!mounted) return;
    setState(() {
      selected
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> saveCategories() async {
    if (selected.length < 3) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'categories': selected,
      'followers': 0,
      'following': 0,
      'posts': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': true,
    }, SetOptions(merge: true));
    await _settingsBox.put(_categoriesCacheKey, List<String>.from(selected));

    if (!mounted) return;

    if (widget.isUpdateMode) {
      Navigator.pop(context, true);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isUpdateMode ? 'Update Categories' : 'Select Categories'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personalize your feed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Select at least 3 categories'),
              const SizedBox(height: 16),
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
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: selected.length >= 3 && !loading ? saveCategories : null,
                  child: loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          widget.isUpdateMode
                              ? 'Update (${selected.length}/3)'
                              : 'Continue (${selected.length}/3)',
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
