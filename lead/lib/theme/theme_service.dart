import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'app_theme_mode';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeService();

  /// Load saved theme before runApp to avoid flash. Call once from main().
  static Future<ThemeService> create() async {
    final service = ThemeService();
    await service._load();
    return service;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeModeKey);
    if (index != null && index >= 0 && index <= 2) {
      _themeMode = ThemeMode.values[index];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> toggle() async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }
}
