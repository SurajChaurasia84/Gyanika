import 'package:flutter/material.dart';

/// Global theme controller
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier(ThemeMode.system);
