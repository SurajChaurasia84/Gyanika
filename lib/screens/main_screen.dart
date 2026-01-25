import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'home_section.dart';
import 'explore_section.dart';
import 'quizes_section.dart';
import 'library_section.dart';
import 'chat_section.dart';

class GyanikaApp extends StatefulWidget {
  const GyanikaApp({super.key});

  @override
  State<GyanikaApp> createState() => _GyanikaAppState();
}

class _GyanikaAppState extends State<GyanikaApp> {
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,

        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.white,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gyanika',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.light(
            primary: Colors.indigo,
            // background: Colors.white,
            surface: Colors.white,
          ),
        ),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: _screens[_currentIndex],

          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.white,
            elevation: 1,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            selectedItemColor: Colors.indigo,
            unselectedItemColor: Colors.grey,
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
                    ? const Icon(Iconsax.message5, size: 30)
                    : const Icon(Iconsax.message, size: 25),
                label: 'Chats',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
