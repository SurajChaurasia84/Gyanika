import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'helpers/in_app_notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🧠 Hive initialize
  await Hive.initFlutter();
  await Hive.openBox('messages');
  final settingsBox = await Hive.openBox('settings');

  // 🎨 Load saved theme (persisted locally)
  final followSystem =
      settingsBox.get('theme_follow_system', defaultValue: true) as bool;
  final savedTheme = settingsBox.get('theme_mode', defaultValue: 'system');
  if (followSystem) {
    themeNotifier.value = ThemeMode.system;
  } else {
    themeNotifier.value = switch (savedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  // 🔒 Edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const GyanikaApp());
}

class GyanikaApp extends StatelessWidget {
  const GyanikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, themeMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Gyanika',
          themeMode: themeMode,
          navigatorKey: appNavigatorKey,

          // ☀️ LIGHT
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              surface: Colors.white,
            ),
          ),

          // 🌙 DARK
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F0F14),
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigo,
              surface: Color(0xFF151520),
            ),
          ),

          home: const AuthGate(),
        );
      },
    );
  }
}

/// 🔐 AUTH GATE
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          InAppNotificationService.dispose();
          // ❌ Not logged in → Login Screen
          return const LoginScreen();
        } else if (!user.emailVerified) {
          InAppNotificationService.dispose();
          // ⚠️ Logged in but email not verified → Email Verification Screen
          return EmailVerificationScreen(user: user);
        } else {
          // ✅ Logged in & email verified → MainScreen
          Future.microtask(() {
            InAppNotificationService.init(
              navigatorKey: appNavigatorKey,
              uid: user.uid,
            );
          });
          return const MainScreen();
        }
      },
    );
  }
}
