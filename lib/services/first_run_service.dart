import 'package:shared_preferences/shared_preferences.dart';

/// Persists first-launch flags. Kept as two independent flags so future
/// releases can re-prompt one (e.g. new onboarding slides) without
/// re-asking the other.
class FirstRunService {
  static const _seenLanguageKey = 'seen_language';
  static const _seenOnboardingKey = 'seen_onboarding';

  static Future<bool> hasSeenLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenLanguageKey) ?? false;
  }

  static Future<void> markLanguageSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenLanguageKey, true);
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenOnboardingKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
  }
}
