import 'package:driver_tracking_app/routing/redirect.dart';
import 'package:driver_tracking_app/routing/routes.dart';
import 'package:flutter_test/flutter_test.dart';

RouteState state({
  bool ready = true,
  bool signedIn = true,
  bool profileCompleted = true,
  bool seenLanguage = true,
  bool seenOnboarding = true,
  bool pendingVerification = false,
  String? inviteToken,
}) => RouteState(
  ready: ready,
  signedIn: signedIn,
  profileCompleted: profileCompleted,
  seenLanguage: seenLanguage,
  seenOnboarding: seenOnboarding,
  pendingVerification: pendingVerification,
  inviteToken: inviteToken,
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
        state(profileCompleted: false),
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
      'invite when signed in': (state(inviteToken: 'tok'), Routes.invite('tok')),
      'invite waits for the profile': (
        state(profileCompleted: false, inviteToken: 'tok'),
        Routes.profileSetup,
      ),
      'e-mail code comes before an invite': (
        state(signedIn: false, pendingVerification: true, inviteToken: 'tok'),
        Routes.verifyEmail,
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
      expect(
        redirect(state(inviteToken: 'tok'), Routes.invite('tok')),
        isNull,
      );
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
}
