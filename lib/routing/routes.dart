abstract final class Routes {
  static const splash = '/splash';
  static const verifyEmail = '/verify-email';
  static const invitePrefix = '/invite';
  static const language = '/language';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const profileSetup = '/profile-setup';
  static const noConnection = '/no-connection';

  static const loads = '/loads';
  static const history = '/loads/history';
  static const settings = '/settings';

  static String invite(String token) => '$invitePrefix/$token';

  static String loadDetails(String loadId) => '$loads/$loadId';
}
