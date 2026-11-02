import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../testing/app_harness.dart';

void main() {
  testWidgets('fresh install: language, onboarding, then sign-in', (
    tester,
  ) async {
    await Harness().start(tester);

    expect(find.text('Choose your language'), findsOneWidget);
    await tapText(tester, 'Русский');
    await tapText(tester, 'Continue');

    await tapText(tester, 'Пропустить');

    expect(find.text('Войти'), findsWidgets);
    expect(find.text('Нет аккаунта? Зарегистрироваться'), findsOneWidget);
  });

  testWidgets('signed in with a saved profile: straight in, even offline', (
    tester,
  ) async {
    final h = Harness(
      device: {
        ...signedInDevice,
        StoreKeys.cachedProfile: '{"id":"u1","first_name":"Ali"}',
      },
    );
    h.backend.online = false;

    await h.start(tester);

    expect(find.text('Loads'), findsWidgets);
    expect(find.text('Complete Profile'), findsNothing);
  });

  testWidgets(
    'no saved profile and no network: retry, not "complete profile"',
    (tester) async {
      final h = Harness(device: signedInDevice)..backend.online = false;
      await h.start(tester);

      expect(
        find.text('No internet connection. Check it and try again.'),
        findsOneWidget,
      );
      expect(find.text('Complete Profile'), findsNothing);

      h.backend.online = true;
      await tapText(tester, 'Try again');

      expect(find.text('Loads'), findsWidgets);
    },
  );

  testWidgets('sign-up: wrong code explained, right code lets in', (
    tester,
  ) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await tapText(tester, "Don't have an account? Sign up");
    await enter(tester, 'First name', 'Bek');
    await enter(tester, 'Email', 'new@yool.live');
    await enter(tester, 'Password', 'short');
    await tapText(tester, 'Create account');
    expect(
      find.text('The password must be at least 8 characters.'),
      findsOneWidget,
    );

    await clearSnackBars(tester);
    await enter(tester, 'Password', 'password1');
    await tapText(tester, 'Create account');
    expect(find.text('Verify Email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tapText(tester, 'Verify');
    expect(
      find.text('Wrong code. Check the email and try again.'),
      findsOneWidget,
    );

    await clearSnackBars(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tapText(tester, 'Verify');
    expect(find.text('Loads'), findsWidgets);
  });

  testWidgets('back from the code screen refills the sign-up form', (
    tester,
  ) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);
    await tapText(tester, "Don't have an account? Sign up");
    await enter(tester, 'Email', 'new@yool.live');
    await enter(tester, 'Password', 'password1');
    await tapText(tester, 'Create account');

    await tapText(tester, 'Back to sign up');

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('new@yool.live'), findsOneWidget);
  });

  testWidgets('wrong password is explained in words', (tester) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await enter(tester, 'Email', 'driver@yool.live');
    await enter(tester, 'Password', 'wrong-one');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('forgotten password: e-mail, code, new password, sign in', (
    tester,
  ) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);
    await enter(tester, 'Email', 'driver@yool.live');

    await tapText(tester, 'Forgot password?');
    expect(find.text('Reset password'), findsOneWidget);
    // The e-mail from the sign-in form is already there.
    await tapText(tester, 'Send code');
    expect(h.backend.resetCodesSentTo, ['driver@yool.live']);
    expect(find.textContaining('driver@yool.live'), findsOneWidget);

    // The code step: nothing typed stays put.
    await tapText(tester, 'Next');
    expect(find.text('Please enter the verification code'), findsOneWidget);
    await clearSnackBars(tester);
    await enter(tester, 'Verification Code', '111111');
    await tapText(tester, 'Next');
    expect(find.text('Confirm password'), findsOneWidget);

    // The password step checks the pair before the server sees it.
    await enter(tester, 'New password', 'short');
    await enter(tester, 'Confirm password', 'short');
    await tapText(tester, 'Change password');
    expect(
      find.text('The password must be at least 8 characters.'),
      findsOneWidget,
    );
    await clearSnackBars(tester);
    await enter(tester, 'New password', 'password2');
    await enter(tester, 'Confirm password', 'password3');
    await tapText(tester, 'Change password');
    expect(find.text("The passwords don't match."), findsOneWidget);
    await clearSnackBars(tester);
    expect(h.backend.requestsTo('/auth/password/reset'), isEmpty);

    // A wrong code is only known to the server: back to the code step.
    await enter(tester, 'Confirm password', 'password2');
    await tapText(tester, 'Change password');
    expect(
      find.text('Wrong code. Check the email and try again.'),
      findsOneWidget,
    );
    await clearSnackBars(tester);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.text('111111'),
      findsNothing,
      reason: 'the code field is clean',
    );

    await enter(tester, 'Verification Code', '123456');
    await tapText(tester, 'Next');
    // The passwords typed before are still there.
    await tapText(tester, 'Change password');

    // Back on the sign-in screen, told what to do.
    expect(find.text('Sign in'), findsWidgets);
    expect(
      find.text('Password changed. Sign in with the new password.'),
      findsOneWidget,
    );
    await clearSnackBars(tester);
    await enter(tester, 'Email', 'driver@yool.live');
    await enter(tester, 'Password', 'password2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Loads'), findsWidgets);
  });

  testWidgets('forgotten password: back goes one step back', (tester) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await tapText(tester, 'Forgot password?');
    await tapText(tester, 'Send code');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await clearSnackBars(tester);

    await enter(tester, 'Email', 'typo@yool.live');
    await tapText(tester, 'Send code');
    await enter(tester, 'Verification Code', '123456');
    await tapText(tester, 'Next');
    expect(find.text('Change password'), findsOneWidget);

    // From the password to the code.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Send the code again'), findsOneWidget);

    // From the code to the e-mail, to correct it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('typo@yool.live'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('invite link on a fresh install: log in & accept in one go', (
    tester,
  ) async {
    final h = Harness();
    h.backend.invites['tok'] = (
      status: 'pending',
      loadId: 'L1',
      acceptedByMe: false,
    );
    await h.start(tester);

    h.links.controller.add(Uri.parse('https://app.yool.live/invite/tok'));
    await tester.pumpAndSettle();
    expect(find.text('You have been offered a load'), findsOneWidget);

    await tapText(tester, 'Log in & accept');
    // Language and onboarding are skipped for an invite.
    await enter(tester, 'Email', 'driver@yool.live');
    await enter(tester, 'Password', 'password1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(h.backend.activeLoadId, 'L1');
    // Straight to the load's details.
    expect(find.text('Tashkent → Samarkand'), findsWidgets);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('invite while busy with another load says so', (tester) async {
    final h = Harness(
      device: {
        ...signedInDevice,
        StoreKeys.cachedProfile: '{"id":"u1","first_name":"Ali"}',
      },
    );
    h.backend
      ..activeLoadId = 'L0'
      ..invites['tok'] = (status: 'pending', loadId: 'L1', acceptedByMe: false);
    await h.start(tester);

    h.links.controller.add(Uri.parse('yoollive://invite/tok'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Accept Load');

    expect(
      find.text(
        'You already have an active load. Finish it before accepting a new one.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Go to my loads');
    expect(find.text('Loads'), findsWidgets);
  });

  testWidgets('Telegram: waits for the confirmation, then signs in', (
    tester,
  ) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await tapText(tester, 'Continue with Telegram');
    expect(h.telegram.opened.single.scheme, 'tg');
    expect(find.text('Confirm in Telegram'), findsOneWidget);

    // Back without confirming: open it again.
    await tester.ensureVisible(find.text('Open Telegram'));
    await tapText(tester, 'Open Telegram');
    expect(h.telegram.opened, hasLength(2));

    h.telegram.appRedirect();
    await tester.pumpAndSettle();

    expect(find.text('Loads'), findsWidgets);
  });

  testWidgets('Telegram: cancel brings the button back', (tester) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await tapText(tester, 'Continue with Telegram');
    await tester.ensureVisible(find.text('Cancel'));
    await tapText(tester, 'Cancel');

    expect(find.text('Confirm in Telegram'), findsNothing);
    expect(find.text('Continue with Telegram'), findsOneWidget);
  });

  testWidgets('sign out from settings', (tester) async {
    final h = Harness(
      device: {
        ...signedInDevice,
        StoreKeys.cachedProfile: '{"id":"u1","first_name":"Ali"}',
      },
    );
    await h.start(tester);

    await tapText(tester, 'Settings');
    await tester.scrollUntilVisible(find.text('v9.9.9+99'), 200);
    await tapText(tester, 'Sign out');

    expect(h.backend.logouts, 1);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);
  });
}
