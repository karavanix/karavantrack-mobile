import 'dart:async';

import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/domain/models/location_state.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_backend.dart';
import '../../testing/fake_local_store.dart';
import '../../testing/test_graph.dart';

/// A signed-in driver past the location prompts, the session and the
/// tracking rules running.
Future<TestGraph> driver({FakeBackend? backend, FakeLocalStore? store}) async {
  final g = store == null
      ? TestGraph.signedIn(backend: backend)
      : TestGraph(backend: backend, store: store);
  g
    ..session
    ..trackingLifecycle;
  await g.location.requestAccess(() async => true);
  return g;
}

/// Tracking runs for [loadId].
Future<void> tracks(TestGraph g, String loadId) => pumpUntil(
  () => g.tracking.enabled && g.trackingService.setup?.loadId == loadId,
);

void main() {
  group('starts', () {
    test('accepting a load starts tracking for it, moving', () async {
      final g = await driver();
      g.backend.addPending(1);
      await g.loads.refresh();

      await g.advance(g.loads.pending.single);

      await tracks(g, 'P1');
      // The hint comes after the start, or the library would ignore it.
      final calls = g.trackingService.calls;
      expect(calls.indexOf('pace:true'), greaterThan(calls.indexOf('start')));
      expect(g.store.values[StoreKeys.trackingLoadId], 'P1');
    });

    test('an active load found on the server is followed', () async {
      final g = await driver();
      g.backend.activeLoadId = 'A';

      await g.loads.refresh();

      await tracks(g, 'A');
      // Nothing the driver did: no hint about moving.
      expect(g.trackingService.calls, isNot(contains('pace:true')));
    });

    test('"On the way" says moving; other steps do not', () async {
      final g = await driver();
      g.backend.activeLoadId = 'A';
      await g.loads.refresh();
      await tracks(g, 'A');

      await g.advance(g.loads.active!); // picking up
      await g.advance(g.loads.active!); // picked up
      expect(g.trackingService.calls, isNot(contains('pace:true')));

      await g.advance(g.loads.active!); // on the way
      expect(g.trackingService.calls.last, 'pace:true');
    });

    test('not before the location prompts are over', () async {
      final g = TestGraph.signedIn()
        ..session
        ..trackingLifecycle;
      g.backend.activeLoadId = 'A';
      await g.loads.refresh();
      await settle();
      expect(g.trackingService.calls, isNot(contains('start')));

      await g.location.requestAccess(() async => true);

      await tracks(g, 'A');
    });

    test(
      'not without any location access: the library would ask itself',
      () async {
        final g = TestGraph.signedIn()
          ..session
          ..trackingLifecycle;
        g.locationService.access = LocationAccess.denied;
        await g.location.requestAccess(() async => false);
        g.backend.activeLoadId = 'A';
        await g.loads.refresh();
        await settle();

        expect(g.trackingService.calls, isNot(contains('start')));

        // Allowed later in the settings.
        g.locationService.access = LocationAccess.always;
        await g.location.check();
        await tracks(g, 'A');
      },
    );
  });

  group('keeps going', () {
    test('after "Dropped off": until the shipper confirms', () async {
      final g = await driver();
      g.backend.activeLoadId = 'A';
      await g.loads.refresh();
      await tracks(g, 'A');

      for (var i = 0; i < 5; i++) {
        await g.advance(g.loads.active!);
      }
      await settle();

      expect(g.backend.loads['A']!.status, 'dropped_off');
      expect(g.tracking.enabled, isTrue);
      expect(g.trackingService.calls, isNot(contains('stop')));
    });

    test(
      'with no signal: a saved load is no reason to stop or start over',
      () async {
        // The library resumed by itself after a reboot, for the saved load.
        final backend = FakeBackend()..activeLoadId = 'A';
        final first = await driver(backend: backend);
        await first.loads.refresh();
        await tracks(first, 'A');

        final g = TestGraph(backend: backend, store: first.store);
        g.trackingService.enabled = true;
        backend.online = false;
        g.loads.restore();
        g
          ..session
          ..trackingLifecycle;
        await g.location.requestAccess(() async => true);
        await settle();

        expect(g.loads.active?.id, 'A');
        expect(g.trackingService.calls, isNot(contains('stop')));
        expect(g.trackingService.calls, isNot(contains('start')));
      },
    );

    test(
      'with no signal and nothing saved: the library is left alone',
      () async {
        final g = TestGraph.signedIn();
        g.trackingService.enabled = true;
        g.backend.online = false;
        g
          ..session
          ..trackingLifecycle;
        await g.location.requestAccess(() async => true);
        await settle();

        expect(g.loads.active, isNull);
        expect(g.trackingService.calls, isNot(contains('stop')));
      },
    );
  });

  group('stops', () {
    test('when the server has no active load any more', () async {
      final g = await driver();
      g.backend.activeLoadId = 'A';
      await g.loads.refresh();
      await tracks(g, 'A');

      g.backend.loads['A']!.status = 'cancelled';
      await g.loads.refresh();

      await pumpUntil(() => !g.tracking.enabled);
    });

    test(
      'when an answer to a batch says so, and the loads are fetched',
      () async {
        final g = await driver();
        g.backend.activeLoadId = 'A';
        await g.loads.refresh();
        await tracks(g, 'A');
        final fetches = g.backend.requestsTo('/loads/active').length;

        g.backend.loads['A']!.status = 'confirmed';
        g.trackingService.record();
        await g.trackingService.autoSync();

        await pumpUntil(() => !g.tracking.enabled);
        await pumpUntil(
          () => g.backend.requestsTo('/loads/active').length > fetches,
        );
        await pumpUntil(() => g.loads.active == null);
        expect(g.backend.takenPoints, ['A']);
      },
    );

    test(
      'a stop about an old load: the active one is followed again',
      () async {
        final g = await driver();
        g.backend
          ..activeLoadId = 'B'
          ..loads['A'] = FakeLoad('A', status: 'confirmed');
        await g.loads.refresh();
        await tracks(g, 'B');
        g.trackingService.calls.clear();

        // A late batch of the previous load only.
        g.trackingService.queue.add((loadId: 'A', at: DateTime.now()));
        await g.trackingService.autoSync();

        await pumpUntil(() => g.trackingService.calls.contains('stop'));
        await tracks(g, 'B');
      },
    );
  });

  test('a new load: the previous one\'s points go first, its "stop" is '
      'ignored', () async {
    final g = await driver();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    await tracks(g, 'A');
    // Recorded with no signal, still queued when A is confirmed.
    g.backend.online = false;
    g.trackingService
      ..record()
      ..record();
    g.backend.loads['A']!.status = 'confirmed';
    g.backend.online = true;
    g.backend.loads['B'] = FakeLoad('B');
    // The app learns A is confirmed: tracking stops, the points stay.
    await g.loads.refresh();
    await pumpUntil(() => !g.tracking.enabled);
    g.trackingService.calls.clear();

    await g.advance(g.loads.pending.single);

    await tracks(g, 'B');
    expect(g.backend.takenPoints, ['A', 'A']);
    final calls = g.trackingService.calls;
    expect(calls.indexOf('sync'), lessThan(calls.indexOf('configure:B')));
    expect(calls, isNot(contains('stop')));
  });

  test('points waiting longer than 5 minutes show as stuck', () async {
    final g = await driver();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    await tracks(g, 'A');

    g.trackingService.record(at: g.now.subtract(const Duration(minutes: 2)));
    await pumpUntil(() => g.tracking.pending == 1);
    expect(g.tracking.queueStuck, isFalse);

    g.now = g.now.add(const Duration(minutes: 4));
    g.trackingService.record(at: g.now);
    await pumpUntil(() => g.tracking.pending == 2);
    expect(g.tracking.queueStuck, isTrue);

    await g.trackingService.autoSync();
    await pumpUntil(() => g.tracking.pending == 0);
    expect(g.tracking.queueStuck, isFalse);
  });

  group('sign-out', () {
    Future<TestGraph> tracking() async {
      final g = await driver();
      g.backend.activeLoadId = 'A';
      await g.loads.refresh();
      await tracks(g, 'A');
      g.backend.online = false;
      g.trackingService
        ..record()
        ..record();
      g.backend.online = true;
      return g;
    }

    void expectStoppedAndForgotten(TestGraph g) {
      final calls = g.trackingService.calls;
      expect(g.tracking.enabled, isFalse);
      expect(calls.indexOf('destroy'), greaterThan(calls.indexOf('stop')));
      expect(g.trackingService.queue, isEmpty);
      expect(g.store.values.containsKey(StoreKeys.trackingLoadId), isFalse);
      // The library is left without the driver's tokens and load.
      expect(g.trackingService.setup?.loadId, isNull);
      expect(g.trackingService.setup?.refreshToken, isNull);
    }

    test(
      'sends what is queued before logging out, then stops and forgets',
      () async {
        final g = await tracking();

        await g.session.signOut();
        await settle();

        expect(g.backend.takenPoints, ['A', 'A']);
        // Sent while the tokens were still good.
        expect(g.trackingService.logoutsAtSync, 0);
        expect(g.backend.logouts, 1);
        expectStoppedAndForgotten(g);
      },
    );

    test('offline: the points are lost, the sign-out still happens', () async {
      final g = await tracking();
      g.backend.online = false;

      await g.session.signOut();
      await settle();

      expect(g.trackingService.calls, contains('sync'));
      expect(g.backend.takenPoints, isEmpty);
      expect(g.auth.isSignedIn, isFalse);
      expectStoppedAndForgotten(g);
    });

    test('a server that doesn\'t answer doesn\'t hold the driver', () async {
      final g = await tracking();
      g.trackingService.syncHeld = Completer<void>();

      await g.session.signOut().timeout(const Duration(seconds: 2));
      await settle();

      expect(g.auth.isSignedIn, isFalse);
      expectStoppedAndForgotten(g);
    });

    test(
      'a rejected refresh token: nothing to send with, just forgotten',
      () async {
        final g = await tracking();

        // refresh-0 was never issued by this backend, so it gets refused.
        await g.auth.refreshAccessToken();
        await settle();
        await settle();

        expect(g.trackingService.calls, isNot(contains('sync')));
        expectStoppedAndForgotten(g);
      },
    );

    test('nothing queued, nothing sent', () async {
      final g = await driver();

      await g.session.signOut();
      await settle();

      expect(g.trackingService.calls, isNot(contains('sync')));
    });

    test('deleting the account sends what is queued first', () async {
      final g = await tracking();

      expect(await g.session.deleteAccount(), isA<Ok<void>>());
      await settle();

      expect(g.backend.takenPoints, ['A', 'A']);
      expect(g.backend.profileDeleted, isTrue);
      expectStoppedAndForgotten(g);
    });
  });

  test('a sign-in hands the library the new tokens', () async {
    final g = TestGraph()
      ..session
      ..trackingLifecycle;

    await g.auth.signInWithPassword(
      email: 'driver@yool.live',
      password: 'password1',
    );
    await settle();

    expect(g.trackingService.setup?.accessToken, g.auth.accessToken);
    expect(g.trackingService.setup?.refreshToken, g.auth.refreshToken);
  });
}
