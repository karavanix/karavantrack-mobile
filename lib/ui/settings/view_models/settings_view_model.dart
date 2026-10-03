import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/app_info_service.dart';
import '../../../domain/models/user.dart';
import '../../../domain/use_cases/session_lifecycle.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';
import '../../profile_setup/view_models/profile_setup_view_model.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required this._profile,
    required this._settings,
    required this._session,
    required AppInfoService appInfo,
  }) {
    saveName = Command1((name) => saveProfileName(_profile, name));
    deleteAccount = Command0(_session.deleteAccount);
    signOut = Command0(_signOut);
    _profile.addListener(notifyListeners);
    _settings.addListener(notifyListeners);
    appInfo.version().then((v) {
      if (_disposed) return;
      _version = v;
      notifyListeners();
    });
  }

  static const supportEmail = 'support@yool.live';

  final ProfileRepository _profile;
  final SettingsRepository _settings;
  final SessionLifecycle _session;

  late final Command1<void, FullName> saveName;
  late final Command0<void> deleteAccount;
  late final Command0<void> signOut;

  String? _version;
  bool _disposed = false;

  User? get user => _profile.user;

  Locale get locale => _settings.locale;

  List<Locale> get locales => SettingsRepository.supportedLocales;

  String nameOf(Locale locale) =>
      SettingsRepository.languageNames[locale.languageCode]!;

  bool get darkTheme => _settings.darkTheme;

  /// The installed build, e.g. `1.5.3+46`; null until read.
  String? get version => _version;

  void setLocale(Locale locale) => _settings.setLocale(locale);

  void setDarkTheme(bool dark) => _settings.setDarkTheme(dark);

  Future<void> copySupportEmail() =>
      Clipboard.setData(const ClipboardData(text: supportEmail));

  Future<Result<void>> _signOut() async {
    await _session.signOut();
    return const Result.ok(null);
  }

  @override
  void dispose() {
    _disposed = true;
    _profile.removeListener(notifyListeners);
    _settings.removeListener(notifyListeners);
    saveName.dispose();
    deleteAccount.dispose();
    signOut.dispose();
    super.dispose();
  }
}
