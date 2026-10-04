import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'api/api_client.dart';
import 'api/api_exception.dart';

/// The code Telegram hands back once the driver confirms the login.
sealed class TelegramCallback {
  const TelegramCallback(this.code);

  final String code;
}

/// The Telegram app opened our login link itself
/// (`https://app…-login.tg.dev/tglogin?code=…`). The code is exchanged on
/// the device with the verifier kept since [TelegramAuthService.appLoginUrl].
final class TelegramAppCallback extends TelegramCallback {
  const TelegramAppCallback(super.code);
}

/// The browser login came back through the server's redirect to
/// `yoollive://tglogin`. The server holds that verifier and exchanges.
final class TelegramWebCallback extends TelegramCallback {
  const TelegramWebCallback(super.code, {required this.state});

  final String state;
}

/// Telegram turned the exchange down, or answered with nothing usable.
final class TelegramLoginException implements Exception {
  const TelegramLoginException(this.reason);

  final String reason;

  @override
  String toString() => 'TelegramLoginException: $reason';
}

/// The device side of Telegram login.
///
/// Normally the login happens in the Telegram app: [appLoginUrl] asks
/// Telegram for a `tg://` link, the driver confirms there, and Telegram
/// opens [appRedirectUri], which Android (App Link) and iOS (Universal
/// Link) hand to this app. Without the Telegram app it falls back to the
/// browser page ([authorizeUrl]), which comes back via the server's redirect
/// to `yoollive://tglogin`, caught natively (MainActivity / SceneDelegate)
/// and sent over a MethodChannel after the first Flutter frame.
///
/// Either way the code may arrive on a cold start, so [listen] must run
/// before `runApp`.
class TelegramAuthService {
  TelegramAuthService({
    this._channel = const MethodChannel('yool.live.app/telegram_auth'),
    Dio? http,
  }) : _http = http ?? _createDio();

  static Dio _createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // Telegram shows the OS from it under "This login attempt came
      // from" ("Android" / "iOS"; the app name doesn't come through).
      headers: {'User-Agent': _userAgent},
    ),
  )..interceptors.add(quietHttpLog());

  static const clientId = '8966637225';
  static const _scope = 'openid profile phone';
  static const _oauth = 'https://oauth.telegram.org';

  static String get _userAgent =>
      Platform.isIOS ? 'YoolLive (iPhone; iOS)' : 'YoolLive (Android)';

  /// Where Telegram sends the driver after "Log In". Telegram hosts one such
  /// domain per native app registered with @BotFather (Login Widget →
  /// Native Login) and verifies it against the app: package and signing key
  /// on Android, team and bundle id on iOS. Release builds are re-signed by
  /// Google Play, debug and profile builds carry the debug key, so each has
  /// its own domain. Must match `telegramLoginHost` in build.gradle.kts and
  /// the associated domain in Runner.entitlements.
  static Uri get appRedirectUri => Uri.https(
    Platform.isIOS
        ? 'app3555230600-login.tg.dev'
        : kReleaseMode
        ? 'app1340816991-login.tg.dev'
        : 'app3297224938-login.tg.dev',
    '/tglogin',
  );

  final MethodChannel _channel;
  final Dio _http;
  // Single-subscription: a code that arrives before AuthRepository
  // subscribes waits in the buffer instead of being dropped.
  final _callbacks = StreamController<TelegramCallback>();
  // The launch link can come both as the initial link and on the stream.
  String? _lastAppCode;

  /// Codes Telegram sends back. One listener: AuthRepository.
  Stream<TelegramCallback> get callbacks => _callbacks.stream;

  /// Starts catching codes: the browser login's from the MethodChannel, the
  /// Telegram app's from [links] (every link that opens the app).
  void listen(Stream<Uri> links) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onTelegramCallback') return;
      final args = Map<String, Object?>.from(call.arguments as Map);
      final code = args['code'] as String?;
      final state = args['state'] as String?;
      if (code == null || state == null) return;
      await closeInAppWebView();
      _callbacks.add(TelegramWebCallback(code, state: state));
    });
    links.listen((uri) {
      if (uri.host != appRedirectUri.host) return;
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty || code == _lastAppCode) return;
      _lastAppCode = code;
      _callbacks.add(TelegramAppCallback(code));
    });
  }

  /// A `tg://` link that opens the login in the Telegram app, or null when
  /// Telegram gives none (offline, or Telegram's side).
  Future<Uri?> appLoginUrl({required String codeChallenge}) async {
    try {
      final response = await _http.get<Map<String, Object?>>(
        '$_oauth/crossapp',
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'scope': _scope,
          'redirect_uri': appRedirectUri.toString(),
          Platform.isIOS ? 'ios_sdk' : 'android_sdk': '1',
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );
      if (response.data?['url'] case final String url) return Uri.parse(url);
      log.warning('[auth] Telegram gave no login link: ${response.data}');
    } on DioException catch (e) {
      log.warning('[auth] Telegram login link failed: $e');
    }
    return null;
  }

  /// Opens the Telegram app on [url]; false when no Telegram app takes it.
  Future<bool> openApp(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      log.warning('[auth] Opening Telegram failed: $e');
      return false;
    }
  }

  /// Trades a [TelegramAppCallback] code for Telegram's id_token. The token
  /// lives 30 seconds: hand it to the server straight away.
  Future<Result<String>> exchange({
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final response = await _http.post<Map<String, Object?>>(
        '$_oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': appRedirectUri.toString(),
          'code_verifier': codeVerifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return switch (response.data) {
        {'id_token': final String token} => Result.ok(token),
        {'error': final String error} => Result.error(
          TelegramLoginException(error),
        ),
        final other => Result.error(TelegramLoginException('$other')),
      };
    } on DioException catch (e) {
      return Result.error(apiExceptionFrom(e));
    }
  }

  /// The browser login page, for when the Telegram app can't be used.
  Uri authorizeUrl({
    required String state,
    required String codeChallenge,
    required String redirectUri,
  }) => Uri.https('oauth.telegram.org', '/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': _scope,
    'state': state,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  });

  /// On iOS the in-app browser lives in our process: swiped away while the
  /// driver is in Telegram, it takes the login page and its redirect with
  /// it. Safari outlives the app.
  Future<bool> open(Uri url) => launchUrl(
    url,
    mode: Platform.isIOS
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );
}
