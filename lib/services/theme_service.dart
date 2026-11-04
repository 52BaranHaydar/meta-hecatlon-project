import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._internal() {
    _loadSavedTheme();
  }

  static final ThemeService instance = ThemeService._internal();
  static const String _preferenceKey = 'selected_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _hasUserOverride = false;

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadSavedTheme() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!_hasUserOverride) {
        _themeMode = preferences.getBool(_preferenceKey) == true
            ? ThemeMode.dark
            : ThemeMode.light;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Theme preference load warning: $error');
    }
  }

  Future<void> toggleThemeMode() async {
    _hasUserOverride = true;
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_preferenceKey, _themeMode == ThemeMode.dark);
    } catch (error) {
      debugPrint('Theme preference save warning: $error');
    }
  }
}
