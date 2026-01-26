import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({super.key});

  Future<void> _clearCache(BuildContext context) async {
    await Hive.box('messages').clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully')),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Data & Storage'),

          _actionTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Cache',
            subtitle: 'Remove locally stored data',
            color: Colors.orange,
            onTap: () => _clearCache(context),
          ),

          const SizedBox(height: 24),

          _sectionTitle('Account'),

          _actionTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Logout from this device',
            color: Colors.redAccent,
            onTap: () => _signOut(context),
          ),

          const SizedBox(height: 30),

          /// ⚠ INFO
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
            ),
            child: const Text(
              'Advanced options affect your app data and account.\n'
              'Use with caution.',
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

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
