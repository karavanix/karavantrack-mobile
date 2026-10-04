import 'dart:async';

import 'package:dio/dio.dart';
import 'package:driver_tracking_app/data/services/api/api_exception.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/domain/models/load.dart';
import 'package:driver_tracking_app/utils/logger.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../testing/fake_backend.dart';
import '../../testing/test_graph.dart';

void main() {
  test('refresh brings the active load and the first pending page', () async {
    final g = TestGraph.signedIn();
    g.backend
      ..activeLoadId = 'A'
      ..addPending(3);

    expect(await g.loads.refresh(), isA<Ok<void>>());

    expect(g.loads.active?.id, 'A');
    expect(g.loads.pending.map((l) => l.id), ['P1', 'P2', 'P3']);
    expect(g.loads.hasMorePending, isFalse);
    expect(g.store.values[StoreKeys.cachedActiveLoad], contains('"id":"A"'));
  });

  test('no active load clears the saved one', () async {
    final g = TestGraph.signedIn();
    g.store.values[StoreKeys.cachedActiveLoad] =
        '{"id":"A","title":"","status":"accepted",'
        '"created_at":"2026-10-01T08:00:00Z"}';
    g.loads.restore();
    expect(g.loads.active?.id, 'A');

    await g.loads.refresh();

    expect(g.loads.active, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedActiveLoad), isFalse);
  });

  test('offline, the saved active load stays and the error is kept', () async {
    final g = TestGraph.signedIn();
    g.store.values[StoreKeys.cachedActiveLoad] =
        '{"id":"A","title":"Saved","status":"in_transit",'
        '"created_at":"2026-10-01T08:00:00Z"}';
    g.loads.restore();
    g.backend.online = false;

    expect(await g.loads.refresh(), isA<Error<void>>());

    expect(g.loads.active?.title, 'Saved');
    expect(g.loads.refreshError, isA<NetworkException>());
    expect(g.loads.pendingLoaded, isFalse);
  });

  test('pages follow one another until the last', () async {
    final g = TestGraph.signedIn();
    g.backend.addPending(20);

    await g.loads.refresh();
    expect(g.loads.pending, hasLength(15));
    expect(g.loads.hasMorePending, isTrue);

    await g.loads.loadMorePending();
    expect(g.loads.pending, hasLength(20));
    expect(g.loads.hasMorePending, isFalse);
    expect(g.backend.requestsTo('/loads/pending').last.queryParameters, {
      'limit': 15,
      'offset': 15,
    });
  });

  test('a load shifting between pages is not shown twice', () async {
    final g = TestGraph.signedIn();
    g.backend.addPending(20);
    await g.loads.refresh();

    // A new load at the top pushes P15 onto the second page.
    final rest = {...g.backend.loads};
    g.backend.loads
      ..clear()
      ..['N'] = FakeLoad('N')
      ..addAll(rest);
    await g.loads.loadMorePending();

    final ids = g.loads.pending.map((l) => l.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, hasLength(20));
  });

  test('a page still loading when the list is refreshed is dropped', () async {
    final g = TestGraph.signedIn();
    g.backend.addPending(20);
    await g.loads.refresh();

    // Hold the next-page request until the refresh is done.
    final release = Completer<void>();
    final handle = g.backend.server.handler;
    g.backend.server.handler = (RequestOptions r) async {
      final response = await handle(r);
      // Answered from the old list, arriving late.
      if (r.path == '/loads/pending' && r.queryParameters['offset'] == 15) {
        await release.future;
      }
      return response;
    };
    final more = g.loads.loadMorePending();
    await pumpUntil(() => g.backend.requestsTo('/loads/pending').length == 2);
    expect(g.loads.loadingMorePending, isTrue);

    g.backend.loads.removeWhere((id, _) => id != 'P1');
    await g.loads.refresh();
    release.complete();
    await more;

    expect(g.loads.pending.map((l) => l.id), ['P1']);
    expect(g.loads.loadingMorePending, isFalse);
  });

  test('accepting moves the load from pending to active', () async {
    final g = TestGraph.signedIn();
    g.backend.addPending(2);
    await g.loads.refresh();

    final result = await g.loads.perform('P1', LoadAction.accept);

    expect(result, isA<Ok<void>>());
    expect(g.loads.active?.id, 'P1');
    expect(g.loads.active?.history.single.to, LoadStatus.accepted);
    expect(g.loads.pending.map((l) => l.id), ['P2']);
    expect(g.store.values[StoreKeys.cachedActiveLoad], contains('"id":"P1"'));
  });

  test('a step the server refuses shows the load as it is now', () async {
    final g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    // The shipper cancelled it meanwhile.
    g.backend.loads['A']!.status = 'cancelled';

    final result = await g.loads.perform('A', LoadAction.beginPickup);

    expect(
      result,
      isA<Error<void>>().having((e) => e.error, 'error', isA<HttpException>()),
    );
    expect(g.loads.byId('A')?.status, LoadStatus.cancelled);
    expect(g.loads.active, isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedActiveLoad), isFalse);
  });

  test('a load that is no longer ours is forgotten', () async {
    final g = TestGraph.signedIn();
    g.backend.addPending(1);
    await g.loads.refresh();
    g.backend.loads.remove('P1');

    await g.loads.fetch('P1');

    expect(g.loads.byId('P1'), isNull);
    expect(g.loads.pending, isEmpty);
  });

  test('a list copy keeps the history while the status is the same', () async {
    final g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    g.backend.loads['A']!.history.add((from: 'assigned', to: 'accepted'));
    g.backend.loads['A']!.status = 'dropped_off';
    await g.loads.fetch('A');
    expect(g.loads.byId('A')?.history, hasLength(1));

    // History lists dropped-off loads without their history.
    await g.loads.refreshHistory();

    expect(g.loads.history.single.id, 'A');
    expect(g.loads.byId('A')?.history, hasLength(1));
  });

  test('history pages like pending', () async {
    final g = TestGraph.signedIn();
    for (var i = 1; i <= 17; i++) {
      g.backend.loads['H$i'] = FakeLoad('H$i', status: 'confirmed');
    }

    await g.loads.refreshHistory();
    expect(g.loads.history, hasLength(15));
    await g.loads.loadMoreHistory();

    expect(g.loads.history, hasLength(17));
    expect(g.loads.hasMoreHistory, isFalse);
  });

  test('refreshes asked for while one runs share it', () async {
    final g = TestGraph.signedIn();

    await Future.wait([g.loads.refresh(), g.loads.refresh()]);

    expect(g.backend.requestsTo('/loads/active'), hasLength(1));
  });

  test(
    'no active load is one debug line; other errors log as before',
    () async {
      final g = TestGraph.signedIn();
      // Tests run with the log off; history only, no console.
      log.configure(settings: TalkerSettings(useConsoleLogs: false));
      addTearDown(log.disable);
      List<TalkerData> activeLines() => log.history
          .where((l) => l.generateTextMessage().contains('/loads/active'))
          .toList();

      log.cleanHistory();
      await g.loads.refresh();
      expect(activeLines().where((l) => l.logLevel == LogLevel.error), isEmpty);
      expect(
        activeLines().where((l) => l.message!.startsWith('[loads]')).single,
        isA<TalkerData>()
            .having((l) => l.logLevel, 'level', LogLevel.debug)
            .having((l) => l.message, 'message', contains('404')),
      );

      final backend = g.backend.server.handler;
      g.backend.server.handler = (r) async => r.path == '/loads/active'
          ? (status: 500, body: {'code': 'INTERNAL_ERROR', 'message': 'db'})
          : backend(r);
      log.cleanHistory();
      await g.loads.refresh();
      expect(
        activeLines().where((l) => l.logLevel == LogLevel.error),
        hasLength(1),
      );
    },
  );

  test('clear forgets everything, and late answers too', () async {
    final g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    final refreshing = g.loads.refresh();

    await g.loads.clear();
    await refreshing;

    expect(g.loads.active, isNull);
    expect(g.loads.byId('A'), isNull);
    expect(g.store.values.containsKey(StoreKeys.cachedActiveLoad), isFalse);
  });

  test('requests go out as the API expects', () async {
    final g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    g.backend.server.requests.clear();

    await g.loads.perform('A', LoadAction.beginPickup, attachmentIds: ['x']);

    final step = g.backend.server.requests.first;
    expect(step.method, 'POST');
    expect(step.path, '/loads/A/pickup/begin');
    expect(step.data, {
      'attachment_ids': ['x'],
    });
    expect(g.backend.loads['A']!.attachments['picking_up'], ['x']);
  });
}
