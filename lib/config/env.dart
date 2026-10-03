/// Build-time configuration. Defaults point at production, so CI and release
/// builds need no flags; a local build against another backend passes
/// `--dart-define-from-file=env/dev.json` (see env/dev.example.json).
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.yool.live',
  );

  /// The web cabinet. Hosts the privacy/terms pages and the driver invite
  /// links (`<webBaseUrl>/invite/{token}`).
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://app.yool.live',
  );

  static const String apiPrefix = '$apiBaseUrl/api/v1';

  static const String privacyPolicyUrl = '$webBaseUrl/privacy-policy';
  static const String termsOfServiceUrl = '$webBaseUrl/terms-of-service';

  /// Telegram OAuth sends the code here; the server bounces it back into the
  /// app through the custom scheme handled in MainActivity/SceneDelegate.
  static const String telegramRedirectUrl = '$apiPrefix/auth/telegram/callback';

  /// Host of the HTTPS invite links (App Links / Universal Links).
  static final String inviteHost = Uri.parse(webBaseUrl).host;
}
