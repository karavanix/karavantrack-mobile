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

  testWidgets('Telegram: the code coming back signs in', (tester) async {
    final h = Harness(
      device: {StoreKeys.seenLanguage: true, StoreKeys.seenOnboarding: true},
    );
    await h.start(tester);

    await tapText(tester, 'Continue with Telegram');
    expect(h.telegram.opened, hasLength(1));

    h.telegram.redirect(code: 'tg-code', state: 'st');
    await tester.pumpAndSettle();

    expect(find.text('Loads'), findsWidgets);
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
