import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

typedef TelegramCallback = ({String code, String state});

/// The device side of Telegram login: opens Telegram's OAuth page and
/// receives the code when Telegram redirects to `yoollive://tglogin`.
///
/// The redirect is caught natively (MainActivity / SceneDelegate) and sent
/// over a MethodChannel after the first Flutter frame, so [listen] must run
/// before `runApp` — including on a cold start caused by the redirect.
class TelegramAuthService {
  TelegramAuthService({
    this._channel = const MethodChannel('yool.live.app/telegram_auth'),
  });

  static const clientId = '8966637225';

  final MethodChannel _channel;
  // Single-subscription: a code that arrives before AuthRepository
  // subscribes waits in the buffer instead of being dropped.
  final _callbacks = StreamController<TelegramCallback>();

  /// Codes delivered by the redirect. One listener: AuthRepository.
  Stream<TelegramCallback> get callbacks => _callbacks.stream;

  void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onTelegramCallback') return;
      final args = Map<String, Object?>.from(call.arguments as Map);
      final code = args['code'] as String?;
      final state = args['state'] as String?;
      if (code == null || state == null) return;
      await closeInAppWebView();
      _callbacks.add((code: code, state: state));
    });
  }

  Uri authorizeUrl({
    required String state,
    required String codeChallenge,
    required String redirectUri,
  }) => Uri.https('oauth.telegram.org', '/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'openid profile phone',
    'state': state,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  });

  Future<bool> open(Uri url) =>
      launchUrl(url, mode: LaunchMode.inAppBrowserView);
}
