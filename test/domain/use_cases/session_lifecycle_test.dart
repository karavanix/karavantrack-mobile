import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/test_graph.dart';

void main() {
  test('a restored session has its profile at once, fresh one after', () async {
    final g = TestGraph.signedIn();
    g.backend.firstName = 'Fresh';

    g.session;
    expect(g.profile.user?.firstName, 'Ali');

    await pumpUntil(() => g.profile.user?.firstName == 'Fresh');
  });

  test('sign-in loads the profile; push is asked for only after', () async {
    final g = TestGraph()..session;

    await g.auth.signInWithPassword(
      email: 'driver@yool.live',
      password: 'password1',
    );
    expect(g.push.permissionRequests, 0);
    await pumpUntil(() => g.profile.user != null);
    await pumpUntil(() => g.backend.devices.isNotEmpty);

    expect(g.push.permissionRequests, 1);
    expect(g.backend.devices.values.single, 'push-token');
  });

  test('no push prompt while the profile is incomplete', () async {
    final g = TestGraph.signedIn(cachedProfile: false);
    g.backend.firstName = '';

    g.session;
    await pumpUntil(() => g.profile.user != null);
    await settle();

    expect(g.push.permissionRequests, 0);
  });

  test('sign-out tells the server, then clears everything', () async {
    final g = TestGraph.signedIn()..session;
    await pumpUntil(() => g.backend.devices.isNotEmpty);

    await g.session.signOut();
    await settle();

    expect(g.backend.logouts, 1);
    expect(g.auth.isSignedIn, isFalse);
    expect(g.profile.user, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedProfile), isFalse);
    expect(g.push.deletedTokens, 1);
  });

  test('sign-out works offline', () async {
    final g = TestGraph.signedIn()..session;
    g.backend.online = false;

    await g.session.signOut();

    expect(g.auth.isSignedIn, isFalse);
  });

  test('a rejected refresh token cleans up the same way', () async {
    // refresh-0 was never issued by this backend, so it gets refused.
    final g = TestGraph.signedIn()..session;
    await pumpUntil(() => g.backend.devices.isNotEmpty);

    await g.auth.refreshAccessToken();
    await settle();

    expect(g.auth.isSignedIn, isFalse);
    expect(g.profile.user, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedProfile), isFalse);
    expect(g.push.deletedTokens, 1);
    expect(g.backend.logouts, 0);
  });

  test('deleting the account signs out only when the server agreed', () async {
    final g = TestGraph.signedIn()..session;

    g.backend.online = false;
    expect(await g.session.deleteAccount(), isA<Error<void>>());
    expect(g.auth.isSignedIn, isTrue);

    g.backend.online = true;
    expect(await g.session.deleteAccount(), isA<Ok<void>>());
    expect(g.backend.profileDeleted, isTrue);
    expect(g.auth.isSignedIn, isFalse);
  });
}
