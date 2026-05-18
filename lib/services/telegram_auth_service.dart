import 'dart:io';
import 'package:telegram_login/telegram_login.dart';

// Platform-specific OAuth client IDs assigned by BotFather.
// iOS redirect:     https://app3555230600-login.tg.dev/tglogin
// Android redirect: https://app626999857-login.tg.dev/tglogin
const String _iosClientId     = '3555230600';
const String _androidClientId = '626999857';

class TelegramAuthService {
  /// Initiates the native Telegram OAuth 2.0 flow and returns the OIDC
  /// id_token JWT on success, or null if the user cancelled.
  /// Throws on unexpected errors.
  static Future<String?> authenticate() async {
    final clientId = Platform.isIOS ? _iosClientId : _androidClientId;
    final result = await TelegramLogin.authenticate(
      clientId: clientId,
    );
    if (result.isCancelled) return null;
    if (result.error != null) {
      throw Exception('Telegram auth error: ${result.error}');
    }
    return result.idToken;
  }
}
