import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'theme_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('auth_box'); // Box for login state
  await Hive.openBox('sensors_box'); // Box for discovered sensors
  await ThemeManager.initialize(); // Load theme preference
  runApp(const SmartFarmApp());
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _checkLoginStatus() {
    final box = Hive.box('auth_box');
    return box.get('isLoggedIn', defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    final lightThemeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F4F0),
      cardColor: Colors.white,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(),
    );

    final darkThemeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          key: const ValueKey('SmartFarmAppRoot'),
          navigatorKey: navigatorKey,
          title: 'BOSS FARM',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: lightThemeData,
          darkTheme: darkThemeData,
          builder: (context, child) {
            return AnimatedTheme(
              data: mode == ThemeMode.dark ? darkThemeData : lightThemeData,
              duration: const Duration(milliseconds: 400),
              child: child!,
            );
          },
          home: _checkLoginStatus() ? const DashboardPage() : const LoginPage(),
        );
      },
    );
  }
}
