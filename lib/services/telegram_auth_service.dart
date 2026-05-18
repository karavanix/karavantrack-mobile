import 'dart:io';
import 'package:telegram_login/telegram_login.dart';

// Platform-specific OAuth client IDs from BotFather native app registration.
// Each ID is embedded in the corresponding redirect URL: app{id}-login.tg.dev
const String _iosClientId       = '3555230600';
const String _androidClientId   = '626999857';
const String _iosRedirectUri    = 'https://app3555230600-login.tg.dev';
const String _androidRedirectUri = 'https://app626999857-login.tg.dev';

class TelegramAuthService {
  static final _telegramLogin = TelegramLogin();

  /// Initiates the native Telegram OAuth 2.0 flow and returns the OIDC
  /// id_token JWT on success, or null if the user cancelled.
  /// Throws on unexpected errors.
  static Future<String?> authenticate() async {
    final clientId    = Platform.isIOS ? _iosClientId    : _androidClientId;
    final redirectUri = Platform.isIOS ? _iosRedirectUri : _androidRedirectUri;

    await _telegramLogin.configure(
      TelegramLoginConfiguration(
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: ['profile'],
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
