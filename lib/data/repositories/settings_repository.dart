import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../services/local_store.dart';

/// On-device preferences: language, theme and the first-run flags.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({required LocalStore store, Locale? deviceLocale})
    : _store = store,
      _locale = initialLocale(
        store,
        deviceLocale ?? PlatformDispatcher.instance.locale,
      ),
      _darkTheme = store.getBool(StoreKeys.darkTheme) ?? true,
      _seenLanguage = store.getBool(StoreKeys.seenLanguage) ?? false,
      _seenOnboarding = store.getBool(StoreKeys.seenOnboarding) ?? false;

  static const supportedLocales = [Locale('en'), Locale('ru'), Locale('uz')];

  /// What the app speaks when the driver never picked: the phone's language
  /// when the app has it, Russian otherwise.
  static const fallbackLocale = Locale('ru');

  /// Names for the language picker, each in its own language.
  static const languageNames = {
    'en': 'English',
    'ru': 'Русский',
    'uz': "O'zbek",
  };

  /// The language the app starts in: the driver's choice if there is one,
  /// else the phone's language, else [fallbackLocale]. Also used where
  /// there's no repository yet (the tracking library's texts in main).
  static Locale initialLocale(LocalStore store, Locale deviceLocale) {
    final saved = store.getString(StoreKeys.locale);
    if (saved != null) return Locale(saved);
    return supportedLocales.any(
          (l) => l.languageCode == deviceLocale.languageCode,
        )
        ? Locale(deviceLocale.languageCode)
        : fallbackLocale;
  }

  final LocalStore _store;

  Locale _locale;
  bool _darkTheme;
  bool _seenLanguage;
  bool _seenOnboarding;

  /// The language the driver picked, or the one the app started in.
  Locale get locale => _locale;

  /// The language as the server knows it: `ru`, `uz` or `en`.
  String get languageCode => _locale.languageCode;

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
