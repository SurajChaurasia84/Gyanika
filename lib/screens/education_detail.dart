import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EducationDetailScreen extends StatefulWidget {
  const EducationDetailScreen({super.key});

  @override
  State<EducationDetailScreen> createState() => _EducationDetailScreenState();
}

class _EducationDetailScreenState extends State<EducationDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  final _education = TextEditingController();
  final _stream = TextEditingController();
  final _institute = TextEditingController();
  final _startYear = TextEditingController();
  final _endYear = TextEditingController();

  bool loading = false;
  late final String uid;

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

    _education.text = data['education'] ?? '';
    _stream.text = data['stream'] ?? '';
    _institute.text = data['institute'] ?? '';

    if (data['duration'] != null) {
      final parts = (data['duration'] as String).split('-');
      if (parts.length == 2) {
        _startYear.text = parts[0].trim();
        _endYear.text = parts[1].trim();
      }
    }

    setState(() {});
  }

  Future<void> _saveEducation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final duration =
        '${_startYear.text.trim()}-${_endYear.text.trim()}';

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'education': _education.text.trim(),
      'stream': _stream.text.trim(),
      'institute': _institute.text.trim(),
      'duration': duration,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => loading = false);

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _education.dispose();
    _stream.dispose();
    _institute.dispose();
    _startYear.dispose();
    _endYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Education details'),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: loading ? null : _saveEducation,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _labeledInput(
                label: 'Education',
                controller: _education,
                required: true,
              ),
              const SizedBox(height: 16),

              _labeledInput(
                label: 'Stream / Branch',
                controller: _stream,
              ),
              const SizedBox(height: 16),

              _labeledInput(
                label: 'School / College',
                controller: _institute,
                required: true,
              ),
              const SizedBox(height: 16),

              /// YEARS
              Row(
                children: [
                  Expanded(
                    child: _labeledInput(
                      label: 'Start year',
                      controller: _startYear,
                      keyboardType: TextInputType.number,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeledInput(
                      label: 'End year',
                      controller: _endYear,
                      keyboardType: TextInputType.number,
                      required: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── LABEL + INPUT ─────────

  Widget _labeledInput({
  required String label,
  required TextEditingController controller,
  bool required = false,
  TextInputType keyboardType = TextInputType.text,
}) {
  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withOpacity(.6),
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.words,
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ],
  );
}

}
