import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  /// SEARCH
  final searchCtrl = TextEditingController();

  /// USER SELECTED
  List<String> selected = [];

  /// POPULAR LIST
  final List<String> popularPreferences = [
    'SSC',
    'UPSC',
    'Science',
    'Math',
    'High School',
    'Intermediate',
    'Technology',
    'Programming',
    'DSA',
    'Data Science',
    'Teaching',
    'Software Development',
    'Web Development',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['preferences'] != null) {
      selected = List<String>.from(data['preferences']);
      setState(() {});
    }
  }

  Future<void> _savePreferences() async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'preferences': selected,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Preferences'),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _savePreferences,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Save'),
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /// TITLE
            // Text(
            //   'Your preferences',
            //   style: theme.textTheme.headlineSmall
            //       ?.copyWith(fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 12),

            /// SEARCH
            TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Areas you want to work in or learn about',
                prefixIcon: const Icon(Iconsax.search_normal),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.isEmpty) return;
                if (!selected.contains(value)) {
                  setState(() => selected.add(value));
                }
                searchCtrl.clear();
              },
            ),

            const SizedBox(height: 16),

            /// SELECTED CHIPS
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: selected.map((item) {
                return Chip(
                  label: Text(item),
                  backgroundColor: primary,
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIcon: const Icon(Icons.close, color: Colors.white),
                  onDeleted: () =>
                      setState(() => selected.remove(item)),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            /// POPULAR
            Text(
              'Popular career interests',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: popularPreferences.map((pref) {
                final isAdded = selected.contains(pref);

                return ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pref),
                      const SizedBox(width: 4),
                      Icon(
                        isAdded ? Iconsax.tick_circle : Icons.add,
                        size: 16,
                      ),
                    ],
                  ),
                  backgroundColor: theme.colorScheme.surface,
                  onPressed: isAdded
                      ? null
                      : () => setState(() => selected.add(pref)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
