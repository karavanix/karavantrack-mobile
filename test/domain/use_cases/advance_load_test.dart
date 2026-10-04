import 'dart:async';
import 'dart:io';

import 'package:driver_tracking_app/domain/models/load.dart';
import 'package:driver_tracking_app/domain/use_cases/advance_load.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/test_graph.dart';

void main() {
  late Directory dir;
  late String photo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pod');
    photo = '${dir.path}/pod.jpg';
    File(photo).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<TestGraph> withActiveLoad() async {
    final g = TestGraph.signedIn();
    g.backend.activeLoadId = 'A';
    await g.loads.refresh();
    return g;
  }

  test('each status leads to its own step', () async {
    final g = await withActiveLoad();

    for (final expected in [
      'picking_up',
      'picked_up',
      'in_transit',
      'dropping_off',
      'dropped_off',
    ]) {
      expect(await g.advance(g.loads.active!), isA<Ok<void>>());
      expect(g.backend.loads['A']!.status, expected);
    }
    // Dropped off: nothing left for the driver.
    expect(g.loads.active!.status.nextAction, isNull);
    expect(await g.advance(g.loads.active!), isA<Error<void>>());
  });

  test('the photo goes up first and travels with the step', () async {
    final g = await withActiveLoad();

    final result = await g.advance(g.loads.active!, photoPath: photo);

    expect(result, isA<Ok<void>>());
    final upload = g.backend.requestsTo('/attachments/image').single;
    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(g.backend.loads['A']!.attachments['picking_up'], ['att-1']);
  });

  test('a failed upload stops the step', () async {
    final g = await withActiveLoad();
    g.backend.failUploads = true;

    final result = await g.advance(g.loads.active!, photoPath: photo);

    expect(
      result,
      isA<Error<void>>().having(
        (e) => e.error,
        'error',
        isA<PhotoUploadException>(),
      ),
    );
    expect(g.backend.loads['A']!.status, 'accepted');
    expect(g.loads.active!.status, LoadStatus.accepted);
  });

  group('where the step happened', () {
    Future<TestGraph> tracked() async {
      final g = await withActiveLoad();
      await g.tracking.follow('A');
      return g;
    }

    test('the step takes the phone\'s fix', () async {
      final g = await tracked();

      expect(await g.advance(g.loads.active!), isA<Ok<void>>());

      expect(g.backend.loads['A']!.locations['picking_up'], {
        'lat': 41.3111,
        'lng': 69.2797,
        'recorded_at': '2026-10-05T12:00:00.000Z',
        'accuracy_m': 8.0,
      });
    });

    test('no fix in time: the step goes without one', () async {
      final g = await tracked();
      g.trackingService.fix = null;

      expect(await g.advance(g.loads.active!), isA<Ok<void>>());

      expect(g.backend.loads['A']!.status, 'picking_up');
      expect(g.backend.loads['A']!.locations, isEmpty);
    });

    test('tracking off: the location isn\'t asked for', () async {
      final g = await withActiveLoad();

      expect(await g.advance(g.loads.active!), isA<Ok<void>>());

      expect(g.trackingService.calls, isNot(contains('fix')));
      expect(g.backend.loads['A']!.locations, isEmpty);
    });

    test('accepting takes no location', () async {
      final g = TestGraph.signedIn();
      g.backend.addPending(1);
      await g.loads.refresh();
      await g.tracking.follow('A');
      final offer = g.loads.pending.single;

      expect(await g.advance(offer), isA<Ok<void>>());

      expect(g.backend.loads['P1']!.status, 'accepted');
      expect(g.trackingService.calls, isNot(contains('fix')));
      expect(g.backend.loads['P1']!.locations, isEmpty);
    });

    test('the photo goes up while the GPS looks for a fix', () async {
      final g = await tracked();
      final held = g.trackingService.fixHeld = Completer<void>();

      final step = g.advance(g.loads.active!, photoPath: photo);
      await pumpEventQueue();
      expect(g.backend.requestsTo('/attachments/image'), hasLength(1));
      expect(g.backend.loads['A']!.status, 'accepted');

      held.complete();
      expect(await step, isA<Ok<void>>());
      expect(g.backend.loads['A']!.locations['picking_up'], isNotNull);
      expect(g.backend.loads['A']!.attachments['picking_up'], ['att-1']);
    });
  });
}
