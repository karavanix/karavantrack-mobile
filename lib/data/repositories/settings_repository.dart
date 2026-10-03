import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../services/local_store.dart';

/// On-device preferences: language, theme and the first-run flags.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({required this._store})
    : _locale = Locale(_store.getString(StoreKeys.locale) ?? 'en'),
      _darkTheme = _store.getBool(StoreKeys.darkTheme) ?? true,
      _seenLanguage = _store.getBool(StoreKeys.seenLanguage) ?? false,
      _seenOnboarding = _store.getBool(StoreKeys.seenOnboarding) ?? false;

  static const supportedLocales = [Locale('en'), Locale('ru'), Locale('uz')];

  /// Names for the language picker, each in its own language.
  static const languageNames = {
    'en': 'English',
    'ru': 'Русский',
    'uz': "O'zbek",
  };

  final LocalStore _store;

  Locale _locale;
  bool _darkTheme;
  bool _seenLanguage;
  bool _seenOnboarding;

  /// The language the user picked; the app ignores the system language.
  Locale get locale => _locale;

  bool get darkTheme => _darkTheme;

  bool get seenLanguage => _seenLanguage;

  bool get seenOnboarding => _seenOnboarding;

  Future<void> setLocale(Locale locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    await _store.setString(StoreKeys.locale, locale.languageCode);
  }

  Future<void> setDarkTheme(bool dark) async {
    if (dark == _darkTheme) return;
    _darkTheme = dark;
    notifyListeners();
    await _store.setBool(StoreKeys.darkTheme, dark);
  }

  Future<void> markLanguageSeen() async {
    if (_seenLanguage) return;
    _seenLanguage = true;
    notifyListeners();
    await _store.setBool(StoreKeys.seenLanguage, true);
  }

  Future<void> markOnboardingSeen() async {
    if (_seenOnboarding) return;
    _seenOnboarding = true;
    notifyListeners();
    await _store.setBool(StoreKeys.seenOnboarding, true);
  }
}
