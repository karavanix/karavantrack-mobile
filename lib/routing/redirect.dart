import 'routes.dart';

/// Everything the redirect looks at, as one snapshot.
class RouteState {
  const RouteState({
    required this.ready,
    required this.signedIn,
    required this.profileCompleted,
    required this.seenLanguage,
    required this.seenOnboarding,
    this.pendingVerification = false,
    this.inviteToken,
  });

  /// Startup is done (splash can go).
  final bool ready;
  final bool signedIn;
  final bool profileCompleted;
  final bool seenLanguage;
  final bool seenOnboarding;

  /// Registered, waiting for the e-mail code.
  final bool pendingVerification;

  /// From an invite link that hasn't been dealt with yet.
  final String? inviteToken;
}

/// Where the user must be right now, or null once they've made it into the
/// app proper. The order is the old app's, and it matters for Google Play:
/// nothing that leads to the location prompt is reachable before sign-in
/// and a completed profile.
String? requiredRoute(RouteState s) {
  if (!s.ready) return Routes.splash;
  if (s.pendingVerification) return Routes.verifyEmail;
  // An invite link skips language/onboarding/login: the offer screen itself
  // asks to sign in. A signed-in driver finishes the profile first.
  if (s.inviteToken case final token?
      when !s.signedIn || s.profileCompleted) {
    return Routes.invite(token);
  }
  if (!s.signedIn) {
    if (!s.seenLanguage) return Routes.language;
    if (!s.seenOnboarding) return Routes.onboarding;
    return Routes.login;
  }
  if (!s.profileCompleted) return Routes.profileSetup;
  return null;
}

/// The go_router redirect: [location] is where navigation is heading.
/// Returns the path to go to instead, or null to let it through.
String? redirect(RouteState s, String location) {
  final required = requiredRoute(s);
  if (required != null) return location == required ? null : required;
  // In the app proper the entry screens are behind us.
  return _isEntryRoute(location) ? Routes.loads : null;
}

bool _isEntryRoute(String location) =>
    location == Routes.splash ||
    location == Routes.verifyEmail ||
    location.startsWith('${Routes.invitePrefix}/') ||
    location == Routes.language ||
    location == Routes.onboarding ||
    location == Routes.login ||
    location == Routes.profileSetup;
