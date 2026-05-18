import 'package:telegram_login/telegram_login.dart';

// TODO: Replace with your Telegram OAuth client ID from BotFather
// (the numeric app ID assigned when you configure OAuth for your bot).
const String _telegramClientId = 'YOUR_TELEGRAM_CLIENT_ID';

class TelegramAuthService {
  /// Initiates the native Telegram OAuth 2.0 flow and returns the OIDC
  /// id_token JWT on success, or null if the user cancelled.
  /// Throws on unexpected errors.
  static Future<String?> authenticate() async {
    final result = await TelegramLogin.authenticate(
      clientId: _telegramClientId,
    );
    if (result.isCancelled) return null;
    if (result.error != null) {
      throw Exception('Telegram auth error: ${result.error}');
    }
    return result.idToken;
  }
}
