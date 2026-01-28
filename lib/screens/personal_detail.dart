import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalDetailScreen extends StatefulWidget {
  const PersonalDetailScreen({super.key});

  @override
  State<PersonalDetailScreen> createState() => _PersonalDetailScreenState();
}

class _PersonalDetailScreenState extends State<PersonalDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();

  String gender = '';
  List<String> selectedLanguages = [];

  bool loading = false;
  late final String uid;

  final List<String> allLanguages = [
    'English',
    'Hindi',
    'Telugu',
    'Tamil',
    'Marathi',
    'French',
    'Japanese',
  ];

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return;

    final name = (data['name'] ?? '').split(' ');
    _firstName.text = name.isNotEmpty ? name.first : '';
    _lastName.text = name.length > 1 ? name.sublist(1).join(' ') : '';

    _phone.text = data['phone'] ?? '';
    _city.text = data['location'] ?? '';
    gender = data['gender'] ?? '';
    selectedLanguages = List<String>.from(data['languages'] ?? []);

    setState(() {});
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
      'phone': _phone.text.trim(),
      'location': _city.text.trim(),
      'gender': gender,
      'languages': selectedLanguages,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => loading = false);

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser!.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Personal details'),
      ),

      /// ✅ SAFE BOTTOM BUTTON
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: loading ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update'),
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _rowFields(
                _input(context, _firstName, 'First name', required: true),
                _input(context, _lastName, 'Last name (Optional)'),
              ),

              const SizedBox(height: 18),

              _label(context, 'Email'),
              const SizedBox(height: 6),
              TextFormField(
                enabled: false,
                initialValue: email,
                decoration: _decoration(context),
              ),

              const SizedBox(height: 18),

              _label(context, 'Contact number'),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextFormField(
                      enabled: false,
                      initialValue: '+91',
                      decoration: _decoration(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _input(
                      context,
                      _phone,
                      'Phone number',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _input(context, _city, 'Current city'),

              const SizedBox(height: 22),

              _label(context, 'Gender'),
              const SizedBox(height: 10),
              Row(
                children: ['Female', 'Male', 'Others']
                    .map((g) => _genderChip(context, g))
                    .toList(),
              ),

              const SizedBox(height: 22),

              _label(context, 'Languages you know'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: allLanguages
                    .map((l) => _languageChip(context, l))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── UI HELPERS ─────────────

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(.6),
      ),
    );
  }

  Widget _rowFields(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _input(
    BuildContext context,
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Required' : null
          : null,
      decoration: _decoration(context, label),
    );
  }

  InputDecoration _decoration(BuildContext context, [String? hint]) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _genderChip(BuildContext context, String value) {
    final theme = Theme.of(context);
    final selected = gender == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageChip(BuildContext context, String lang) {
    final theme = Theme.of(context);
    final selected = selectedLanguages.contains(lang);

    return GestureDetector(
      onTap: () {
        setState(() {
          selected
              ? selectedLanguages.remove(lang)
              : selectedLanguages.add(lang);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        child: Text(
          selected ? '$lang ×' : '$lang +',
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
