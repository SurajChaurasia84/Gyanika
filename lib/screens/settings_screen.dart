import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/login_screen.dart';
import 'auth/select_category_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openCategoryUpdate(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectCategoryScreen(isUpdateMode: true),
      ),
    );

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories updated')),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (result == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  ///  CHANGE PASSWORD CONFIRM
  Future<void> _confirmPasswordReset(BuildContext context, String email) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'We will send a password reset link to your email. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result == true) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    }
  }

  /// ✏ EDIT NAME DIALOG
  Future<void> _editName(
    BuildContext context,
    String uid,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': controller.text.trim(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🔐 ACCOUNT
          _sectionTitle('Account'),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final name = data?['name'] ?? 'User';

              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                subtitle: Text(name),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editName(context, user.uid, name),
                ),
              );
            },
          ),

          _settingTile(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: user.email ?? '',
          ),

          _settingTile(
            icon: Icons.verified_user_outlined,
            title: 'Email Verified',
            subtitle: user.emailVerified ? 'Yes' : 'No',
          ),

          const SizedBox(height: 24),

          _sectionTitle('Category'),

          _settingTile(
            icon: Icons.category_outlined,
            title: 'Update Category',
            subtitle: 'Update your selected categories',
            onTap: () => _openCategoryUpdate(context),
          ),

          const SizedBox(height: 24),

          /// 🛡 SECURITY
          _sectionTitle('Security'),

          _settingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: () => _confirmPasswordReset(context, user.email!),
          ),

          _settingTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from this device',
            iconColor: Colors.redAccent,
            onTap: () => _confirmLogout(context),
          ),

          const SizedBox(height: 30),

          /// ℹ APP INFO
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
            ),
            child: const Text(
              'Gyanika v1.0.0\nLearning made simple.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap,
    );
  }
}
