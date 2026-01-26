import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppThemeController {
  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier(ThemeMode.system);

  static const _boxName = 'app_settings';
  static const _themeKey = 'theme_mode';

  /// Load saved theme (or system default)
  static Future<void> loadTheme() async {
    final box = await Hive.openBox(_boxName);
    final savedTheme = box.get(_themeKey, defaultValue: 'system');

    switch (savedTheme) {
      case 'light':
        notifier.value = ThemeMode.light;
        break;
      case 'dark':
        notifier.value = ThemeMode.dark;
        break;
      default:
        notifier.value = ThemeMode.system;
    }
  }

  /// Save & apply theme
  static Future<void> setTheme(ThemeMode mode) async {
    notifier.value = mode;
    final box = Hive.box(_boxName);

    if (mode == ThemeMode.light) {
      await box.put(_themeKey, 'light');
    } else if (mode == ThemeMode.dark) {
      await box.put(_themeKey, 'dark');
    } else {
      await box.put(_themeKey, 'system');
    }
  }
}
