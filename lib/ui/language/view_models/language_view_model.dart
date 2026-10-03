import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

/// First-launch language picker: the choice applies on Continue.
class LanguageViewModel extends ChangeNotifier {
  LanguageViewModel({required this._settings}) : _selected = _settings.locale {
    confirm = Command0(_confirm);
  }

  final SettingsRepository _settings;
  late final Command0<void> confirm;

  Locale _selected;

  Locale get selected => _selected;

  List<Locale> get locales => SettingsRepository.supportedLocales;

  String nameOf(Locale locale) =>
      SettingsRepository.languageNames[locale.languageCode]!;

  void select(Locale locale) {
    _selected = locale;
    notifyListeners();
  }

  Future<Result<void>> _confirm() async {
    await _settings.setLocale(_selected);
    await _settings.markLanguageSeen();
    return const Result.ok(null);
  }

  @override
  void dispose() {
    confirm.dispose();
    super.dispose();
  }
}
