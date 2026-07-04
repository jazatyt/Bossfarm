import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'dashboard_page.dart';
import 'alarms_page.dart';
import 'history_view_page.dart';
import 'farm_layout_builder_page.dart';
import 'user_management_page.dart';
import 'all_farms_page.dart';
import 'theme_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn =
        Hive.box('auth_box').get('isLoggedIn', defaultValue: false) as bool;
    final loc = state.matchedLocation;
    final unauthed = loc == '/login' || loc == '/register';
    if (!loggedIn) return unauthed ? null : '/login';
    if (unauthed) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
    GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
    GoRoute(
        path: '/alarms',
        builder: (c, s) => AlarmsPage(initialIndex: (s.extra as int?) ?? 0)),
    GoRoute(path: '/history', builder: (c, s) => const HistoryViewPage()),
    GoRoute(path: '/layout', builder: (c, s) => const FarmLayoutBuilderPage()),
    GoRoute(path: '/settings', builder: (c, s) => const UserManagementPage()),
    GoRoute(
        path: '/farms',
        builder: (c, s) => AllFarmsPage(filterType: (s.extra as String?) ?? '')),
  ],
);

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
        return MaterialApp.router(
          routerConfig: _router,
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
        );
      },
    );
  }
}
