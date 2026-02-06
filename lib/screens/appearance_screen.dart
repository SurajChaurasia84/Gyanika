import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../main.dart'; // themeNotifier

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  Future<void> _changeTheme(
    BuildContext context,
    ThemeMode mode,
  ) async {
    themeNotifier.value = mode;

    final box = Hive.box('settings');
    final followSystem = mode == ThemeMode.system;
    await box.put('theme_follow_system', followSystem);
    await box.put(
      'theme_mode',
      mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Theme',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          _themeTile(
            context,
            title: 'System Default',
            subtitle: 'Follow device theme',
            icon: Icons.phone_android,
            mode: ThemeMode.system,
          ),

          _themeTile(
            context,
            title: 'Light Mode',
            subtitle: 'Always light',
            icon: Icons.light_mode,
            mode: ThemeMode.light,
          ),

          _themeTile(
            context,
            title: 'Dark Mode',
            subtitle: 'Always dark',
            icon: Icons.dark_mode,
            mode: ThemeMode.dark,
          ),

          const SizedBox(height: 30),

          /// ℹ INFO
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
            ),
            child: const Text(
              'Theme changes are applied instantly and saved automatically.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
  }) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, current, __) {
        final selected = current == mode;

        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Colors.indigo)
              : null,
          onTap: () => _changeTheme(context, mode),
        );
      },
    );
  }
}
