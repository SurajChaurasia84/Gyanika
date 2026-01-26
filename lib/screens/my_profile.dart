import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _education = TextEditingController();
  final _address = TextEditingController();
  final _stream = TextEditingController();
  final _institute = TextEditingController();

  bool loading = false;
  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadUserData();
  }

  /// 🔄 LOAD DATA
  Future<void> _loadUserData() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = doc.data();
    if (data == null) return;

    _name.text = data['name'] ?? '';
    _email.text = data['email'] ?? '';
    _phone.text = data['phone'] ?? '';
    _location.text = data['location'] ?? '';
    _education.text = data['education'] ?? '';
    _address.text = data['address'] ?? '';
    _stream.text = data['stream'] ?? '';
    _institute.text = data['institute'] ?? '';
  }

  /// 💾 SAVE DATA
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'location': _location.text.trim(),
      'education': _education.text.trim(),
      'address': _address.text.trim(),
      'stream': _stream.text.trim(),
      'institute': _institute.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _education.dispose();
    _address.dispose();
    _stream.dispose();
    _institute.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _title('Personal Information'),

              _field(_name, 'Full Name', Icons.person, required: true),
              _field(
                _email,
                'Email',
                Icons.email,
                enabled: false, // 🔒 email change later flow
              ),
              _field(_phone, 'Phone Number', Icons.phone),
              _field(_location, 'Location / City', Icons.location_on),

              const SizedBox(height: 20),
              _title('Education'),

              _field(_education, 'Education', Icons.school),
              _field(_stream, 'Stream', Icons.book),
              _field(_institute, 'School / College', Icons.account_balance),

              const SizedBox(height: 20),
              _title('Address'),

              _field(_address, 'Address', Icons.home, maxLines: 3),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧩 WIDGETS
  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
