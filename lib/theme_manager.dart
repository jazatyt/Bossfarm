import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static Future<void> initialize() async {
    final box = await Hive.openBox('settings_box');
    final String? savedMode = box.get('themeMode');
    if (savedMode == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (savedMode == 'light') {
      themeMode.value = ThemeMode.light;
    }
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void toggleTheme() {
    themeMode.value = themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final box = Hive.box('settings_box');
    box.put('themeMode', themeMode.value == ThemeMode.dark ? 'dark' : 'light');
  }
}
