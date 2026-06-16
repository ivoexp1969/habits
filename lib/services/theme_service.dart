import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('theme_mode') ?? 'dark';
  themeNotifier.value = switch (stored) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

Future<void> saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme_mode', switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    _ => 'dark',
  });
  themeNotifier.value = mode;
}
