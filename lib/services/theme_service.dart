import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen theme mode (dark / light).
class ThemeService {
  static const _key = 'app_theme_dark';

  /// Returns true if dark mode is preferred (default: true).
  static Future<bool> loadIsDark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> saveIsDark(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
