import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'home_section.dart';
import 'explore_section.dart';
import 'quizes_section.dart';
import 'library_section.dart';
import 'saved_section.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeSection(),
    ExploreSection(),
    QuizesSection(),
    LibrarySection(),
    ChatSection(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,

        systemNavigationBarColor: colorScheme.surface,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: colorScheme.surface,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: _screens[_currentIndex],

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: colorScheme.surface,
          elevation: 1,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),

          items: [
            BottomNavigationBarItem(
              icon: _currentIndex == 0
                  ? const Icon(Iconsax.home_15, size: 30)
                  : const Icon(Iconsax.home, size: 25),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 1
                  ? const Icon(Iconsax.clipboard5, size: 30)
                  : const Icon(Iconsax.clipboard, size: 25),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 2
                  ? const Icon(Iconsax.cup5, size: 30)
                  : const Icon(Iconsax.cup, size: 25),
              label: 'Quizes',
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 3
                  ? const Icon(Iconsax.layer5, size: 30)
                  : const Icon(Iconsax.layer, size: 25),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: _currentIndex == 4
                  ? const Icon(Iconsax.like5, size: 30)
                  : const Icon(Iconsax.like, size: 25),
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }
}
