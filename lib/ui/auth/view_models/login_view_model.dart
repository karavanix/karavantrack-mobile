import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/env.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/invite_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/api/api_exception.dart';
import '../../../data/services/apple_sign_in_service.dart';
import '../../../utils/command.dart';
import '../../../utils/formatters.dart';
import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';

/// A problem with the form, found before anything is sent.
enum FormProblem { missingFields, invalidEmail, passwordTooShort }

class FormException implements Exception {
  const FormException(this.problem);

  final FormProblem problem;
}

typedef Credentials = ({
  String email,
  String password,
  String firstName,
  String lastName,
});

/// Sign in or sign up: e-mail and password, Telegram, Apple.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required this._auth,
    required this._settings,
    required this._invites,
  }) : _isSignUp = _auth.lastSignUp != null {
    submit = Command1(_submit);
    signInWithApple = Command0(_auth.signInWithApple);
    signInWithTelegram = Command0(_auth.startTelegramSignIn);
    _auth.addListener(notifyListeners);
    _settings.addListener(notifyListeners);
    _telegramErrors = _auth.telegramErrors.listen((e) {
      _telegramError = e;
      notifyListeners();
    });
  }

  final AuthRepository _auth;
  final SettingsRepository _settings;
  final InviteRepository _invites;
  late final StreamSubscription<Exception> _telegramErrors;

  late final Command1<void, Credentials> submit;
  late final Command0<void> signInWithApple;
  late final Command0<void> signInWithTelegram;

  bool _isSignUp;
  Exception? _telegramError;

  bool get isSignUp => _isSignUp;

  /// What to put back in the form after "Back to sign up".
  SignUpForm? get previousSignUp => _auth.lastSignUp;

  bool get appleAvailable => _auth.appleAvailable;

  bool get busy =>
      submit.running ||
      signInWithApple.running ||
      signInWithTelegram.running ||
      _auth.telegramInProgress;

  /// Came here from "Log in & accept" on an invite.
  bool get forInvite => _invites.acceptAfterSignIn;

  Locale get locale => _settings.locale;

  List<Locale> get locales => SettingsRepository.supportedLocales;

  String nameOf(Locale locale) =>
      SettingsRepository.languageNames[locale.languageCode]!;

  /// A Telegram sign-in that failed after the return from Telegram; the
  /// screen shows it once and calls [clearTelegramError].
  Exception? get telegramError => _telegramError;

  void clearTelegramError() => _telegramError = null;

  void toggleMode() {
    _isSignUp = !_isSignUp;
    notifyListeners();
  }

  void setLocale(Locale locale) => _settings.setLocale(locale);

  void backToInvite() => _invites.cancelSignIn();

  Future<void> openTerms() => _open(Env.termsOfServiceUrl);

  Future<void> openPrivacyPolicy() => _open(Env.privacyPolicyUrl);

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<Result<void>> _submit(Credentials c) {
    final email = c.email.trim();
    if (email.isEmpty || c.password.isEmpty) {
      return _problem(FormProblem.missingFields);
    }
    if (!isValidEmail(email)) return _problem(FormProblem.invalidEmail);
    if (!_isSignUp) {
      return _auth.signInWithPassword(email: email, password: c.password);
    }
    if (c.password.length < 8) return _problem(FormProblem.passwordTooShort);
    return _auth.signUp(
      email: email,
      password: c.password,
      firstName: c.firstName.trim(),
      lastName: c.lastName.trim(),
    );
  }

  Future<Result<void>> _problem(FormProblem problem) async =>
      Result.error(FormException(problem));

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    _settings.removeListener(notifyListeners);
    _telegramErrors.cancel();
    submit.dispose();
    signInWithApple.dispose();
    signInWithTelegram.dispose();
    super.dispose();
  }
}

/// The message for a failed sign-in or sign-up, or null when there's
/// nothing to say (the Apple sheet was closed).
String? loginErrorText(
  AppLocalizations l10n,
  Exception error, {
  required bool signUp,
}) => switch (error) {
  FormException(problem: FormProblem.missingFields) =>
    l10n.enterEmailAndPassword,
  FormException(problem: FormProblem.invalidEmail) => l10n.errorInvalidEmail,
  FormException(problem: FormProblem.passwordTooShort) =>
    l10n.errorPasswordTooShort,
  AppleSignInCancelled() => null,
  // The server doesn't say which: no such user, unverified, wrong password.
  HttpException(statusCode: 403) when !signUp => l10n.errorWrongCredentials,
  HttpException(statusCode: 409) when signUp => l10n.errorEmailTaken,
  ApiException() => errorText(l10n, error),
  _ => l10n.errorSignInFailed,
};
