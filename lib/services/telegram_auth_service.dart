import 'dart:io';
import 'package:telegram_login/telegram_login.dart';

// Platform-specific OAuth client IDs from BotFather native app registration.
// Each ID is embedded in the corresponding redirect URL: app{id}-login.tg.dev
const String _clientId           = '8966637225';
const String _iosRedirectUri     = 'https://app3555230600-login.tg.dev';
// /tglogin path must match the intent-filter path in AndroidManifest.xml
const String _androidRedirectUri = 'https://app1451611780-login.tg.dev/tglogin';

class TelegramAuthService {
  static final _telegramLogin = TelegramLogin();

  /// Initiates the native Telegram OAuth 2.0 flow and returns the OIDC
  /// id_token JWT on success, or null if the user cancelled.
  /// Throws on unexpected errors.
  static Future<String?> authenticate() async {
    final redirectUri = Platform.isIOS ? _iosRedirectUri : _androidRedirectUri;

    await _telegramLogin.configure(
      TelegramLoginConfiguration(
        clientId: _clientId,
        redirectUri: redirectUri,
        scopes: ['profile', 'phone'],
      ),
    );

    try {
      final result = await _telegramLogin.login();
      return result.idToken;
    } on TelegramLoginError catch (e) {
      if (e.code == TelegramLoginErrorCode.cancelled) return null;
      throw Exception('Telegram auth error [${e.code}]: ${e.message}');
    }
  }
}
