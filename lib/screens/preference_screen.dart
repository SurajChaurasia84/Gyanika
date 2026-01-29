import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final searchCtrl = TextEditingController();

  List<String> selected = [];

  String? selectedStream;

  final Map<String, List<String>> streamPreferences = {
    'LKG/UKG': ['ABCD', '0-9'],
    'Class 1-5': [
      'Hindi',
      'English',
      'Maths',
      'Science',
      'Environmental Studies',
      'General Knowledge',
      'Moral Science',
    ],
    'Class 6-8': [
      'Hindi',
      'English',
      'Maths',
      'Science',
    ],
    'Class 9-10th': [
      'Hindi',
      'English',
      'Mathematics',
      'Science',
      'Social Science',
    ],
    'Class 11-12th': [
      'Hindi',
      'English',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
    ],
    'JEE': [
      'Mathematics',
      'Physics',
      'Chemistry',
    ],
    'NEET': [
      'Botany',
      'Zoology',
      'Physics',
      'Chemistry',
    ],
    'CUET': [
      'English',
      'Hindi',
      'Mathematics',
      'Physics',
      'Chemistry',
    ],
    'College': ['B.Tech', 'B.E', 'B.Sc', 'BCA', 'B.Com', 'BBA', 'BA'],
    'GATE': [
      'Computer Science & IT',
      'Mechanical Engineering',
      'Electrical Engineering',
      'Electronics & Communication',
      'Civil Engineering',
    ],
    'SSC': [
      'General Intelligence & Reasoning',
      'Quantitative Aptitude (Mathematics)',
      'General Awareness',
      'English Comprehension',
    ],
  };

  List<String> get allOptions =>
      streamPreferences.values.expand((e) => e).toList();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data != null) {
      selected = List<String>.from(data['preferences'] ?? []);
      selectedStream = data['preferenceStream'];
      setState(() {});
    }
  }

  Future<void> _savePreferences() async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'preferences': selected,
      'preferenceStream': selectedStream,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final List<String> filteredSuggestions = searchCtrl.text.isEmpty
        ? []
        : allOptions
              .where(
                (e) =>
                    e.toLowerCase().contains(searchCtrl.text.toLowerCase()) &&
                    !selected.contains(e),
              )
              .toList();

    final List<String> popular = selectedStream == null
        ? []
        : streamPreferences[selectedStream]!;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Preferences'),
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _savePreferences,
            child: const Text('Save'),
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /// 🔍 SEARCH
            TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search interests',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (value.isEmpty) return;
                if (!selected.contains(value)) {
                  setState(() => selected.add(value));
                }
                searchCtrl.clear();
              },
            ),

            /// 🔎 SUGGESTIONS
            if (filteredSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: filteredSuggestions.map((s) {
                  return ActionChip(
                    label: Text(s),
                    onPressed: () {
                      setState(() {
                        selected.add(s);
                        searchCtrl.clear();
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 10),

            /// 🔹 SELECT STREAM (SINGLE)
            Text(
              'Select stream',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              children: streamPreferences.keys.map((stream) {
                final isSelected = stream == selectedStream;
                return ChoiceChip(
                  label: Text(stream),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      selectedStream = stream;
                      selected.clear();
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            /// ⭐ POPULAR (STREAM BASED)
            if (popular.isNotEmpty) ...[
              Text(
                'Related interests',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(.6),
                ),
              ),
              const SizedBox(height: 10),

              /// ✅ SELECTED
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: selected.map((item) {
                  return Chip(
                    label: Text(item),
                    backgroundColor: primary,
                    labelStyle: const TextStyle(color: Colors.white),
                    deleteIcon: const Icon(Icons.close, color: Colors.white),
                    onDeleted: () => setState(() => selected.remove(item)),
                  );
                }).toList(),
              ),

              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: popular.map((pref) {
                  final added = selected.contains(pref);
                  return ActionChip(
                    label: Text(pref),
                    onPressed: added
                        ? null
                        : () => setState(() => selected.add(pref)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
