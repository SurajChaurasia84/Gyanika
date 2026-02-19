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
import 'helpers/widget_navigation_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
const PageTransitionsTheme _appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _AppFadePageTransitionsBuilder(),
    TargetPlatform.iOS: _AppFadePageTransitionsBuilder(),
    TargetPlatform.linux: _AppFadePageTransitionsBuilder(),
    TargetPlatform.macOS: _AppFadePageTransitionsBuilder(),
    TargetPlatform.windows: _AppFadePageTransitionsBuilder(),
    TargetPlatform.fuchsia: _AppFadePageTransitionsBuilder(),
  },
);

class _AppFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('messages');
  final settingsBox = await Hive.openBox('settings');

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

  await WidgetNavigationService.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const GyanikaApp());
}

class GyanikaApp extends StatelessWidget {
  const GyanikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Gyanika',
          themeMode: themeMode,
          navigatorKey: appNavigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              surface: Colors.white,
            ),
            pageTransitionsTheme: _appPageTransitionsTheme,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F0F14),
            colorScheme: const ColorScheme.dark(
              primary: Colors.indigo,
              surface: Color(0xFF151520),
            ),
            pageTransitionsTheme: _appPageTransitionsTheme,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          InAppNotificationService.dispose();
          return const LoginScreen();
        } else if (!user.emailVerified) {
          InAppNotificationService.dispose();
          return EmailVerificationScreen(user: user);
        } else {
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