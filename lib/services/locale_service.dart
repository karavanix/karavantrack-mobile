import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen locale code (en / ru / uz).
class LocaleService {
  static const _key = 'app_locale';

  static Future<String> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'en';
  }

  static Future<void> saveLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
