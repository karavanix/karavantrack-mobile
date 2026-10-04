import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/domain/models/location_state.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_backend.dart';
import '../../testing/test_graph.dart';

/// What the app shell does once the driver is in: the location prompts.
Future<void> passLocationPrompts(TestGraph g) =>
    g.location.requestAccess(() async => true);

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
    await settle();
    // Not yet: the location disclosure and prompts come first.
    expect(g.push.permissionRequests, 0);

    await passLocationPrompts(g);
    await pumpUntil(() => g.backend.devices.isNotEmpty);

    expect(g.push.permissionRequests, 1);
    expect(g.backend.devices.values.single, 'push-token');
  });

  test('the device is registered once per sign-in', () async {
    final g = TestGraph.signedIn()..session;
    int registrations() => g.backend.requestsTo('/users/me/devices').length;
    // Long enough for a second request to reach the server.
    Future<void> settleRequests() async {
      for (var i = 0; i < 20; i++) {
        await settle();
      }
    }

    await passLocationPrompts(g);
    await pumpUntil(() => registrations() > 0);
    await settleRequests();
    expect(registrations(), 1);

    // A token that really changes is sent again.
    g.push.refreshes.add('push-token-2');
    await pumpUntil(() => registrations() > 1);
    await settleRequests();
    expect(registrations(), 2);

    // Back in after signing out: the new token, once.
    await g.session.signOut();
    await g.auth.signInWithPassword(
      email: 'driver@yool.live',
      password: 'password1',
    );
    await passLocationPrompts(g);
    await pumpUntil(() => registrations() > 2);
    await settleRequests();
    expect(registrations(), 3);
  });

  test('no push prompt while the profile is incomplete', () async {
    final g = TestGraph.signedIn(cachedProfile: false);
    g.backend.firstName = '';

    g.session;
    await pumpUntil(() => g.profile.user != null);
    await passLocationPrompts(g);
    await settle();

    expect(g.push.permissionRequests, 0);
  });

  test('sign-out tells the server, then clears everything', () async {
    final g = TestGraph.signedIn()..session;
    await passLocationPrompts(g);
    await pumpUntil(() => g.backend.devices.isNotEmpty);

    await g.session.signOut();
    await settle();

    expect(g.backend.logouts, 1);
    expect(g.auth.isSignedIn, isFalse);
    expect(g.profile.user, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedProfile), isFalse);
    expect(g.push.deletedTokens, 1);
    expect(g.loads.active, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedActiveLoad), isFalse);
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
    await passLocationPrompts(g);
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

  test('the next driver on this phone gets the disclosure again', () async {
    final g = TestGraph.signedIn()..session;
    g.locationService.access = LocationAccess.denied;
    var disclosures = 0;
    Future<bool> askConsent() async {
      disclosures++;
      return false;
    }

    await g.location.requestAccess(askConsent);
    await g.location.requestAccess(askConsent);
    expect(disclosures, 1);

    await g.session.signOut();
    await settle();
    await g.location.requestAccess(askConsent);
    expect(disclosures, 2);
  });

  test('a restored session shows the saved active load, then fresh', () async {
    final backend = FakeBackend()..activeLoadId = 'L1';
    backend.loads['L1']!.status = 'in_transit';
    final g = TestGraph.signedIn(backend: backend);
    g.store.values[StoreKeys.cachedActiveLoad] =
        '{"id":"L1","title":"Saved","status":"accepted",'
        '"created_at":"2026-10-01T08:00:00Z"}';

    g.session;
    expect(g.loads.active?.title, 'Saved');

    await pumpUntil(() => g.loads.active?.title == 'Load L1');
    expect(g.store.values[StoreKeys.cachedActiveLoad], contains('in_transit'));
  });

  test('loads are fetched again when the app comes back', () async {
    final g = TestGraph.signedIn()..session;
    await pumpUntil(() => g.loads.pendingLoaded);
    expect(g.loads.pending, isEmpty);

    g.backend.addPending(1);
    g.lifecycle.resumes.add(null);

    await pumpUntil(() => g.loads.pending.length == 1);
  });

  test('a push about a load in the open app fetches it', () async {
    final g = TestGraph.signedIn()..session;
    g.backend.activeLoadId = 'L1';
    await pumpUntil(() => g.loads.active?.id == 'L1');

    g.backend.loads['L1']!.status = 'cancelled';
    g.push.messages.add((title: 'Груз отменен', body: null, loadId: 'L1'));

    await pumpUntil(() => g.loads.active == null);
    expect(g.loads.byId('L1')?.status.wire, 'cancelled');
  });

  test('loads are fetched again when the network is back', () async {
    final g = TestGraph.signedIn()..session;
    await pumpUntil(() => g.loads.pendingLoaded);
    g.connectivityService.changes.add(false);
    await settle();

    g.backend.addPending(2);
    g.connectivityService.changes.add(true);

    await pumpUntil(() => g.loads.pending.length == 2);
  });

  test('an accepted invite makes its load the active one', () async {
    final g = TestGraph.signedIn()..session;
    g.backend.invites['tok'] = (
      status: 'pending',
      loadId: 'L1',
      acceptedByMe: false,
    );
    g.invites.handleLink(Uri.parse('yoollive://invite/tok'));

    await g.invites.accept();

    await pumpUntil(() => g.loads.active?.id == 'L1');
  });
}
