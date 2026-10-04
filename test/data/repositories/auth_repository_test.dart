import 'package:driver_tracking_app/data/repositories/auth_repository.dart';
import 'package:driver_tracking_app/data/services/api/api_client.dart';
import 'package:driver_tracking_app/data/services/api/api_exception.dart';
import 'package:driver_tracking_app/data/services/api/auth_api.dart';
import 'package:driver_tracking_app/data/services/apple_sign_in_service.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_services.dart';
import '../../testing/test_graph.dart';

void main() {
  test('password sign-in stores the tokens', () async {
    final g = TestGraph();

    final result = await g.auth.signInWithPassword(
      email: 'driver@yool.live',
      password: 'password1',
    );

    expect(result, isA<Ok<void>>());
    expect(g.auth.isSignedIn, isTrue);
    expect(g.store.values[StoreKeys.refreshToken], isNotNull);
  });

  test('a wrong password is a 403 and leaves the user signed out', () async {
    final g = TestGraph();

    final result = await g.auth.signInWithPassword(
      email: 'driver@yool.live',
      password: 'nope',
    );

    expect(
      (result as Error<void>).error,
      isA<HttpException>().having((e) => e.statusCode, 'status', 403),
    );
    expect(g.auth.isSignedIn, isFalse);
  });

  group('sign-up', () {
    Future<TestGraph> signedUp() async {
      final g = TestGraph();
      await g.auth.signUp(
        email: 'new@yool.live',
        password: 'password1',
        firstName: 'Bek',
        lastName: '',
      );
      return g;
    }

    test('waits for the code, and the wait survives a restart', () async {
      final g = await signedUp();
      expect(g.auth.pendingVerificationEmail, 'new@yool.live');

      // The app is killed while the driver reads the e-mail.
      final restarted = TestGraph(backend: g.backend, store: g.store);
      expect(restarted.auth.pendingVerificationEmail, 'new@yool.live');

      final result = await restarted.auth.verifyEmail('123456');
      expect(result, isA<Ok<void>>());
      expect(restarted.auth.isSignedIn, isTrue);
      expect(restarted.auth.pendingVerificationEmail, isNull);
      expect(
        g.store.values.containsKey(StoreKeys.pendingVerificationEmail),
        isFalse,
      );
    });

    test('a wrong code keeps waiting', () async {
      final g = await signedUp();

      final result = await g.auth.verifyEmail('000000');

      expect(
        (result as Error<void>).error,
        isA<HttpException>().having((e) => e.code, 'code', 'OTP_MISMATCH'),
      );
      expect(g.auth.pendingVerificationEmail, 'new@yool.live');
      expect(g.auth.isSignedIn, isFalse);
    });

    test('going back keeps the form to refill', () async {
      final g = await signedUp();

      await g.auth.cancelVerification();

      expect(g.auth.pendingVerificationEmail, isNull);
      expect(g.auth.lastSignUp?.email, 'new@yool.live');
      expect(g.auth.lastSignUp?.firstName, 'Bek');
    });

    test('a verified e-mail is a conflict and nothing waits', () async {
      final g = TestGraph();

      final result = await g.auth.signUp(
        email: 'driver@yool.live',
        password: 'password1',
        firstName: '',
        lastName: '',
      );

      expect(
        (result as Error<void>).error,
        isA<HttpException>().having((e) => e.statusCode, 'status', 409),
      );
      expect(g.auth.pendingVerificationEmail, isNull);
    });
  });

  group('Telegram', () {
    test('logs in in the Telegram app, which sends the code back', () async {
      final g = TestGraph();

      expect(await g.auth.startTelegramSignIn(), isA<Ok<void>>());
      expect(g.telegram.opened.single.scheme, 'tg');
      expect(g.auth.telegramWaiting, isTrue);
      expect(g.store.values[StoreKeys.telegramVerifier], isNotNull);

      g.telegram.appRedirect();
      await pumpUntil(() => g.auth.isSignedIn);
      expect(g.auth.telegramWaiting, isFalse);
      expect(g.auth.telegramInProgress, isFalse);
      expect(g.store.values[StoreKeys.telegramVerifier], isNull);
      expect(g.backend.requestsTo('/auth/telegram'), hasLength(1));
    });

    test('the verifier outlives the app: iOS may kill it meanwhile', () async {
      final g = TestGraph();
      await g.auth.startTelegramSignIn();

      // The app starts again because Telegram opened its link.
      final telegram = FakeTelegramAuthService()
        ..challenge = g.telegram.challenge
        ..appRedirect();
      final auth = AuthRepository(
        api: AuthApi(ApiClient.public(adapter: g.backend.server)),
        store: g.store,
        apple: g.apple,
        telegram: telegram,
      );

      await pumpUntil(() => auth.isSignedIn);
    });

    test('a code with no login of ours behind it is rejected', () async {
      final g = TestGraph();
      final errors = <Exception>[];
      g.auth.telegramErrors.listen(errors.add);

      g.telegram.appRedirect();
      await pumpUntil(() => errors.isNotEmpty);

      expect(g.auth.isSignedIn, isFalse);
      expect(g.telegram.exchanges, isEmpty);
      expect(g.backend.requestsTo('/auth/telegram'), isEmpty);
    });

    test('cancel hides the wait; a code that still comes signs in', () async {
      final g = TestGraph();
      await g.auth.startTelegramSignIn();

      g.auth.cancelTelegramSignIn();
      expect(g.auth.telegramWaiting, isFalse);

      g.telegram.appRedirect();
      await pumpUntil(() => g.auth.isSignedIn);
    });

    test('opened again, only the latest verifier is kept', () async {
      final g = TestGraph();
      await g.auth.startTelegramSignIn();
      final first = g.store.values[StoreKeys.telegramVerifier];

      await g.auth.startTelegramSignIn();

      expect(g.telegram.opened, hasLength(2));
      expect(g.store.values[StoreKeys.telegramVerifier], isNot(first));
      g.telegram.appRedirect();
      await pumpUntil(() => g.auth.isSignedIn);
    });

    test('without the Telegram app it logs in through the browser', () async {
      final g = TestGraph();
      g.telegram.appLoginAvailable = false;

      expect(await g.auth.startTelegramSignIn(), isA<Ok<void>>());
      expect(g.telegram.opened.single.host, 'oauth.telegram.org');
      expect(g.telegram.opened.single.queryParameters['state'], 'st');
      expect(g.auth.telegramWaiting, isFalse);

      g.telegram.redirect(code: 'tg-code', state: 'st');
      await settle();
      expect(g.auth.telegramInProgress, isTrue);
      await pumpUntil(() => g.auth.isSignedIn);
      expect(g.auth.telegramInProgress, isFalse);
    });

    test('a browser code from a cold start waits for the repository', () async {
      final telegram = FakeTelegramAuthService();
      // Delivered before anything subscribed.
      telegram.redirect(code: 'tg-code', state: 'st');
      final g = TestGraph();
      final auth = AuthRepository(
        api: AuthApi(ApiClient.public(adapter: g.backend.server)),
        store: g.store,
        apple: g.apple,
        telegram: telegram,
      );

      await pumpUntil(() => auth.isSignedIn);
    });

    test('a rejected browser code is reported on telegramErrors', () async {
      final g = TestGraph();
      final errors = <Exception>[];
      g.auth.telegramErrors.listen(errors.add);

      g.telegram.redirect(code: 'bad', state: 'st');
      await pumpUntil(() => errors.isNotEmpty);

      expect(errors.single, isA<HttpException>());
      expect(g.auth.isSignedIn, isFalse);
      expect(g.auth.telegramInProgress, isFalse);
    });
  });

  test(
    'Apple: the code goes along, for revoking on account deletion',
    () async {
      final g = TestGraph();
      g.apple.next = const Result.ok((
        identityToken: 'apple-id-token',
        authorizationCode: 'apple-code',
        firstName: 'Ali',
        lastName: 'Valiev',
      ));

      final result = await g.auth.signInWithApple();

      expect(result, isA<Ok<void>>());
      expect(g.auth.isSignedIn, isTrue);
      final body = g.backend.requestsTo('/auth/apple').single.data as Map;
      expect(body['authorization_code'], 'apple-code');
      expect(body['first_name'], 'Ali');
    },
  );

  test('closing the Apple sheet is not an error worth showing', () async {
    final g = TestGraph();

    final result = await g.auth.signInWithApple();

    expect((result as Error<void>).error, isA<AppleSignInCancelled>());
    expect(g.backend.requestsTo('/auth/apple'), isEmpty);
  });
}
