import 'package:driver_tracking_app/routing/redirect.dart';
import 'package:driver_tracking_app/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';

RouteState state({
  bool ready = true,
  bool signedIn = true,
  ProfileGate profile = ProfileGate.complete,
  bool seenLanguage = true,
  bool seenOnboarding = true,
  bool pendingVerification = false,
  String? inviteToken,
  bool inviteSignInRequested = false,
  String? acceptedLoadId,
}) => RouteState(
  ready: ready,
  signedIn: signedIn,
  profile: profile,
  seenLanguage: seenLanguage,
  seenOnboarding: seenOnboarding,
  pendingVerification: pendingVerification,
  inviteToken: inviteToken,
  inviteSignInRequested: inviteSignInRequested,
  acceptedLoadId: acceptedLoadId,
);

void main() {
  group('requiredRoute', () {
    final cases = <String, (RouteState, String?)>{
      'starting up': (state(ready: false), Routes.splash),
      'fresh install': (
        state(signedIn: false, seenLanguage: false, seenOnboarding: false),
        Routes.language,
      ),
      'language picked': (
        state(signedIn: false, seenOnboarding: false),
        Routes.onboarding,
      ),
      'signed out': (state(signedIn: false), Routes.login),
      'waiting for the e-mail code': (
        state(signedIn: false, pendingVerification: true),
        Routes.verifyEmail,
      ),
      'signed in, no profile': (
        state(profile: ProfileGate.incomplete),
        Routes.profileSetup,
      ),
      'signed in with profile': (state(), null),
      'invite on a fresh install skips first-run and login': (
        state(
          signedIn: false,
          seenLanguage: false,
          seenOnboarding: false,
          inviteToken: 'tok',
        ),
        Routes.invite('tok'),
      ),
      'invite when signed in': (
        state(inviteToken: 'tok'),
        Routes.invite('tok'),
      ),
      'invite waits for the profile': (
        state(profile: ProfileGate.incomplete, inviteToken: 'tok'),
        Routes.profileSetup,
      ),
      'e-mail code comes before an invite': (
        state(signedIn: false, pendingVerification: true, inviteToken: 'tok'),
        Routes.verifyEmail,
      ),
      'profile still loading keeps the splash': (
        state(profile: ProfileGate.loading),
        Routes.splash,
      ),
      'profile unavailable offline': (
        state(profile: ProfileGate.unavailable),
        Routes.noConnection,
      ),
      'invite waits for the profile to load': (
        state(profile: ProfileGate.loading, inviteToken: 'tok'),
        Routes.splash,
      ),
      '"Log in & accept" goes straight to login, skipping first-run': (
        state(
          signedIn: false,
          seenLanguage: false,
          seenOnboarding: false,
          inviteToken: 'tok',
          inviteSignInRequested: true,
        ),
        Routes.login,
      ),
      '"Log in & accept": the code screen still comes first': (
        state(
          signedIn: false,
          pendingVerification: true,
          inviteToken: 'tok',
          inviteSignInRequested: true,
        ),
        Routes.verifyEmail,
      ),
      '"Log in & accept": back on the invite once signed in': (
        state(inviteToken: 'tok', inviteSignInRequested: true),
        Routes.invite('tok'),
      ),
      'splash comes before everything': (
        state(ready: false, pendingVerification: true, inviteToken: 'tok'),
        Routes.splash,
      ),
    };
    cases.forEach((name, c) {
      test(name, () => expect(requiredRoute(c.$1), c.$2));
    });
  });

  group('redirect', () {
    test('sends to the required route from anywhere else', () {
      expect(redirect(state(signedIn: false), Routes.loads), Routes.login);
      expect(redirect(state(signedIn: false), '/loads/42'), Routes.login);
    });

    test('lets the required route itself through', () {
      expect(redirect(state(signedIn: false), Routes.login), isNull);
      expect(redirect(state(inviteToken: 'tok'), Routes.invite('tok')), isNull);
    });

    test('in the app, leaves entry screens for the loads tab', () {
      for (final entry in [
        Routes.splash,
        Routes.login,
        Routes.language,
        Routes.onboarding,
        Routes.verifyEmail,
        Routes.profileSetup,
        Routes.invite('old'),
        Routes.noConnection,
      ]) {
        expect(redirect(state(), entry), Routes.loads, reason: entry);
      }
    });

    test('in the app, lets app routes through', () {
      for (final route in [
        Routes.loads,
        Routes.loadDetails('42'),
        Routes.history,
        Routes.settings,
      ]) {
        expect(redirect(state(), route), isNull, reason: route);
      }
    });
  });

  test('leaving an accepted invite goes to its load', () {
    expect(
      redirect(state(acceptedLoadId: 'L7'), Routes.invite('tok')),
      Routes.loadDetails('L7'),
    );
    expect(redirect(state(acceptedLoadId: 'L7'), Routes.login), Routes.loads);
  });
}
