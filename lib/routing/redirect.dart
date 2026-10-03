import 'routes.dart';

/// What the router knows about the signed-in user's profile.
enum ProfileGate {
  /// Being fetched for the first time, nothing on the device yet.
  loading,

  /// The fetch failed and there's nothing on the device.
  unavailable,
  incomplete,
  complete,
}

/// Everything the redirect looks at, as one snapshot.
class RouteState {
  const RouteState({
    required this.ready,
    required this.signedIn,
    required this.profile,
    required this.seenLanguage,
    required this.seenOnboarding,
    this.pendingVerification = false,
    this.inviteToken,
    this.inviteSignInRequested = false,
    this.acceptedLoadId,
  });

  /// Startup is done (splash can go).
  final bool ready;
  final bool signedIn;

  /// Only meaningful when [signedIn].
  final ProfileGate profile;
  final bool seenLanguage;
  final bool seenOnboarding;

  /// Registered, waiting for the e-mail code.
  final bool pendingVerification;

  /// From an invite link that hasn't been dealt with yet.
  final String? inviteToken;

  /// The driver tapped "Log in & accept" on the invite.
  final bool inviteSignInRequested;

  /// The load of the invite just accepted.
  final String? acceptedLoadId;
}

/// Where the user must be right now, or null once they've made it into the
/// app proper. The order is the old app's, and it matters for Google Play:
/// nothing that leads to the location prompt is reachable before sign-in
/// and a completed profile.
String? requiredRoute(RouteState s) {
  if (!s.ready) return Routes.splash;
  if (s.pendingVerification) return Routes.verifyEmail;
  if (s.inviteToken case final token?) {
    // An invite link skips language/onboarding: the offer screen itself
    // asks to sign in. A signed-in driver finishes the profile first.
    final showInvite = s.signedIn
        ? s.profile == ProfileGate.complete
        : !s.inviteSignInRequested;
    if (showInvite) return Routes.invite(token);
  }
  if (!s.signedIn) {
    if (s.inviteSignInRequested) return Routes.login;
    if (!s.seenLanguage) return Routes.language;
    if (!s.seenOnboarding) return Routes.onboarding;
    return Routes.login;
  }
  return switch (s.profile) {
    ProfileGate.loading => Routes.splash,
    ProfileGate.unavailable => Routes.noConnection,
    ProfileGate.incomplete => Routes.profileSetup,
    ProfileGate.complete => null,
  };
}

/// The go_router redirect: [location] is where navigation is heading.
/// Returns the path to go to instead, or null to let it through.
String? redirect(RouteState s, String location) {
  final required = requiredRoute(s);
  if (required != null) return location == required ? null : required;
  // In the app proper the entry screens are behind us. Leaving an accepted
  // invite goes to its load.
  if (!_isEntryRoute(location)) return null;
  if (location.startsWith('${Routes.invitePrefix}/')) {
    if (s.acceptedLoadId case final loadId?) return Routes.loadDetails(loadId);
  }
  return Routes.loads;
}

bool _isEntryRoute(String location) =>
    location == Routes.splash ||
    location == Routes.verifyEmail ||
    location.startsWith('${Routes.invitePrefix}/') ||
    location == Routes.language ||
    location == Routes.onboarding ||
    location == Routes.login ||
    location == Routes.profileSetup ||
    location == Routes.noConnection;
