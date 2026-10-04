import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import '../../utils/logger.dart';
import '../../utils/pkce.dart';
import '../../utils/result.dart';
import '../services/api/api_exception.dart';
import '../services/api/auth_api.dart';
import '../services/api/auth_interceptor.dart';
import '../services/api/models/token_pair.dart';
import '../services/apple_sign_in_service.dart';
import '../services/local_store.dart';
import '../services/telegram_auth_service.dart';

typedef SignUpForm = ({String email, String firstName, String lastName});

/// The session: how the user signs in, and the tokens once they have. The
/// only owner of the tokens. Signed in means a refresh token is stored;
/// listeners (the router, SessionLifecycle) hear about every change.
class AuthRepository extends ChangeNotifier implements TokenSource {
  AuthRepository({
    required this._api,
    required this._store,
    required this._apple,
    required this._telegram,
  }) : _accessToken = _store.getString(StoreKeys.accessToken),
       _refreshToken = _store.getString(StoreKeys.refreshToken),
       _pendingEmail = _store.getString(StoreKeys.pendingVerificationEmail) {
    _telegramSub = _telegram.callbacks.listen(_completeTelegram);
  }

  final AuthApi _api;
  final LocalStore _store;
  final AppleSignInService _apple;
  final TelegramAuthService _telegram;
  late final StreamSubscription<TelegramCallback> _telegramSub;

  String? _accessToken;
  String? _refreshToken;
  String? _pendingEmail;
  SignUpForm? _lastSignUp;
  bool _telegramWaiting = false;
  bool _telegramInProgress = false;
  final _telegramErrors = StreamController<Exception>.broadcast();
  Future<Result<String>>? _refreshing;

  bool get isSignedIn => _refreshToken != null;

  @override
  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  /// Signed up, waiting for the code from the e-mail. Kept on the device:
  /// the app may be killed while the driver is in the mail app.
  String? get pendingVerificationEmail => _pendingEmail;

  /// The last sign-up form sent from this launch, to refill it when the
  /// driver goes back from the code screen.
  SignUpForm? get lastSignUp => _lastSignUp;

  bool get appleAvailable => _apple.isAvailable;

  /// The Telegram app was opened for the driver to confirm the login and
  /// nothing has come back yet.
  bool get telegramWaiting => _telegramWaiting;

  /// Between the return from Telegram and the server's answer.
  bool get telegramInProgress => _telegramInProgress;

  /// Failures of the Telegram exchange, which finishes outside any button
  /// press (the code arrives from the redirect).
  Stream<Exception> get telegramErrors => _telegramErrors.stream;

  Future<Result<void>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await _api.login(email: email, password: password);
    return _signedIn(result);
  }

  /// Sends the code to [email]; the code screen takes it from there.
  Future<Result<void>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _lastSignUp = (email: email, firstName: firstName, lastName: lastName);
    final result = await _api.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    if (result case Error(:final error)) return Result.error(error);
    _pendingEmail = email;
    await _store.setString(StoreKeys.pendingVerificationEmail, email);
    notifyListeners();
    return const Result.ok(null);
  }

  Future<Result<void>> verifyEmail(String code) async {
    final email = _pendingEmail;
    if (email == null) {
      return Result.error(Exception('no e-mail waiting for a code'));
    }
    final result = await _api.verifyEmail(email: email, code: code);
    if (result is Ok<TokenPair>) await _clearPending();
    return _signedIn(result);
  }

  /// Leaves the code screen for the sign-up form.
  Future<void> cancelVerification() async {
    await _clearPending();
    notifyListeners();
  }

  Future<Result<void>> signInWithApple() async {
    final credential = await _apple.requestCredential();
    switch (credential) {
      case Error(:final error):
        return Result.error(error);
      case Ok(:final value):
        final result = await _api.apple(
          idToken: value.identityToken,
          authorizationCode: value.authorizationCode,
          firstName: value.firstName,
          lastName: value.lastName,
        );
        return _signedIn(result);
    }
  }

  /// Opens the login in the Telegram app, or Telegram's login page in the
  /// browser when there's no Telegram app. The sign-in completes when the
  /// code comes back (see [telegramWaiting], [telegramInProgress],
  /// [telegramErrors]).
  Future<Result<void>> startTelegramSignIn() async {
    final pkce = createPkce();
    final url = await _telegram.appLoginUrl(codeChallenge: pkce.challenge);
    if (url != null) {
      await _store.setString(StoreKeys.telegramVerifier, pkce.verifier);
      if (await _telegram.openApp(url)) {
        _telegramWaiting = true;
        notifyListeners();
        return const Result.ok(null);
      }
      log.info('[auth] No Telegram app, logging in through the browser');
    }
    return _startTelegramInBrowser();
  }

  /// The driver gave up on the Telegram app (declined there, or changed
  /// their mind). A code that still comes back signs them in all the same.
  void cancelTelegramSignIn() {
    _telegramWaiting = false;
    notifyListeners();
  }

  Future<Result<void>> _startTelegramInBrowser() async {
    switch (await _api.pkce()) {
      case Error(:final error):
        return Result.error(error);
      case Ok(:final value):
        final url = _telegram.authorizeUrl(
          state: value.state,
          codeChallenge: value.codeChallenge,
          redirectUri: Env.telegramRedirectUrl,
        );
        final opened = await _telegram.open(url);
        return opened
            ? const Result.ok(null)
            : Result.error(Exception('could not open $url'));
    }
  }

  Future<void> _completeTelegram(TelegramCallback callback) async {
    _telegramWaiting = false;
    _telegramInProgress = true;
    notifyListeners();
    final result = switch (callback) {
      TelegramAppCallback(:final code) => await _exchangeTelegramCode(code),
      TelegramWebCallback(:final code, :final state) => await _api.telegram(
        code: code,
        state: state,
        redirectUri: Env.telegramRedirectUrl,
      ),
    };
    _telegramInProgress = false;
    switch (await _signedIn(result)) {
      case Ok():
        break;
      case Error(:final error):
        log.warning('[auth] Telegram sign-in failed: $error');
        notifyListeners();
        _telegramErrors.add(error);
    }
  }

  /// Code → Telegram's id_token (with the verifier from
  /// [startTelegramSignIn]) → our tokens.
  Future<Result<TokenPair>> _exchangeTelegramCode(String code) async {
    final verifier = _store.getString(StoreKeys.telegramVerifier);
    if (verifier == null) {
      return const Result.error(
        TelegramLoginException('no Telegram login in progress'),
      );
    }
    switch (await _telegram.exchange(code: code, codeVerifier: verifier)) {
      case Error(:final error):
        return Result.error(error);
      case Ok(value: final idToken):
        // The code is spent; a new login starts with a new verifier.
        await _store.remove(StoreKeys.telegramVerifier);
        return _api.telegramIdToken(idToken);
    }
  }

  Future<Result<void>> _signedIn(Result<TokenPair> result) async {
    switch (result) {
      case Ok(:final value):
        await _save(value);
        notifyListeners();
        return const Result.ok(null);
      case Error(:final error):
        return Result.error(error);
    }
  }

  /// Forgets the session on this device. Telling the server is
  /// SessionLifecycle's job; this is also what a rejected refresh does.
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.remove(StoreKeys.accessToken);
    await _store.remove(StoreKeys.refreshToken);
    notifyListeners();
  }

  /// Concurrent callers share one request: the HTTP interceptor and, later,
  /// the tracking library can both ask at the same moment.
  @override
  Future<Result<String>> refreshAccessToken() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Result<String>> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      return const Result.error(UnauthorizedException());
    }
    switch (await _api.refresh(refreshToken)) {
      case Ok(:final value):
        // Signed out while the request was in flight: don't resurrect.
        if (_refreshToken != refreshToken) {
          return const Result.error(UnauthorizedException());
        }
        await _save(value);
        return Result.ok(value.accessToken);
      case Error(error: HttpException(isClientError: true) && final error):
        log.warning(
          'Refresh token rejected (${error.statusCode}), signing out',
        );
        await signOut();
        return const Result.error(UnauthorizedException());
      case Error(:final error):
        return Result.error(error);
    }
  }

  Future<void> _save(TokenPair tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _store.setString(StoreKeys.accessToken, tokens.accessToken);
    await _store.setString(StoreKeys.refreshToken, tokens.refreshToken);
  }

  Future<void> _clearPending() async {
    _pendingEmail = null;
    await _store.remove(StoreKeys.pendingVerificationEmail);
  }

  @override
  void dispose() {
    _telegramSub.cancel();
    _telegramErrors.close();
    super.dispose();
  }
}
