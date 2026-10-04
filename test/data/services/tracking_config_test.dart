import 'dart:convert';

import 'package:driver_tracking_app/data/repositories/tracking_repository.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/data/services/tracking/tracking_config.dart';
import 'package:driver_tracking_app/data/services/tracking/tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_backend.dart';
import '../../testing/fake_local_store.dart';
import '../../testing/fake_tracking_service.dart';

/// Template variables as the library fills them on Android (its TSLocation,
/// read from the bytecode of tslocationmanager 4.6.1): every value is a
/// string, put into the template as is.
const _androidValues = {
  'uuid': '0b5e1c3a-9f2d-4c1e-8a7b-6d5f4e3c2b1a',
  'timestamp': '2026-10-04T08:15:30.123Z',
  'latitude': '41.311081',
  'longitude': '69.240562',
  'accuracy': '4.8',
  'altitude': '455.2',
  'speed': '-1.0',
  'heading': '-1.0',
  'event': '',
  'is_moving': 'false',
  'activity.type': 'still',
  'activity.confidence': '100',
  'odometer': '1234.5',
  'battery.level': '0.87',
  'battery.is_charging': 'true',
  'mock': 'false',
};

/// The tags the library documents for locationTemplate. Any other one
/// fails the record ("Unknown template variable").
const _documentedTags = {
  'latitude',
  'longitude',
  'speed',
  'heading',
  'accuracy',
  'altitude',
  'altitude_accuracy',
  'timestamp',
  'uuid',
  'event',
  'odometer',
  'odometer_error',
  'activity.type',
  'activity.confidence',
  'battery.level',
  'battery.is_charging',
  'mock',
  'is_moving',
  'timestampMeta',
};

final _tag = RegExp(r'<%=\s*([\w.]+)\s*%>');

/// What the library does with a record: fills the template, then merges
/// the extras into the object.
Map<String, Object?> _render(
  Map<String, String> values, {
  Map<String, Object?> extras = const {},
}) {
  final json = locationTemplate.replaceAllMapped(_tag, (m) => values[m[1]]!);
  return {...jsonDecode(json) as Map<String, Object?>, ...extras};
}

void main() {
  group('locationTemplate', () {
    test('uses only tags the library knows', () {
      final tags = {for (final m in _tag.allMatches(locationTemplate)) m[1]};
      expect(_documentedTags, containsAll(tags));
    });

    test('renders JSON with the fields the server reads', () {
      final point = _render(_androidValues, extras: {'load_id': 'A'});

      // RegisterLocationsPoint (api-server, rewrite/v2), less `provider`,
      // which Android adds to providerchange records by itself.
      expect(point.keys.toSet(), {
        'uuid',
        'load_id',
        'recorded_at',
        'lat',
        'lng',
        'accuracy_m',
        'altitude_m',
        'speed_mps',
        'heading_deg',
        'event',
        'is_moving',
        'activity_type',
        'activity_confidence',
        'odometer_m',
        'battery_level',
        'is_charging',
        'is_mock',
      });
      expect(point['recorded_at'], '2026-10-04T08:15:30.123Z');
      expect(point['lat'], 41.311081);
      expect(point['speed_mps'], -1.0);
      expect(point['event'], '');
      expect(point['is_moving'], isFalse);
      expect(point['battery_level'], 0.87);
      expect(point['is_mock'], isFalse);
      expect(point['load_id'], 'A');
    });

    test('a motionchange record renders too', () {
      final point = _render({
        ..._androidValues,
        'event': 'motionchange',
        'is_moving': 'true',
        'activity.type': 'in_vehicle',
        'speed': '12.5',
        'heading': '87.0',
      });

      expect(point['event'], 'motionchange');
      expect(point['is_moving'], isTrue);
      expect(point['heading_deg'], 87.0);
    });
  });

  group('trackingConfig', () {
    const setup = TrackingSetup(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      loadId: 'A',
      texts: testTrackingTexts,
    );
    final config = trackingConfig(setup);

    test('sends batches to /tracking/locations', () {
      final http = config.http!;
      expect(http.url, endsWith('/api/v1/tracking/locations'));
      expect(http.method, 'POST');
      expect(http.batchSync, isTrue);
      expect(http.rootProperty, 'points');
      expect(http.autoSyncThreshold, 6);
      expect(http.maxBatchSize, 250);
      expect(config.persistence!.locationTemplate, locationTemplate);
    });

    test('stamps the load on every point; none without a load', () {
      expect(config.persistence!.extras, {'load_id': 'A'});
      final idle = trackingConfig(
        const TrackingSetup(
          accessToken: null,
          refreshToken: null,
          loadId: null,
          texts: testTrackingTexts,
        ),
      );
      expect(idle.persistence!.extras, isEmpty);
    });

    test('refreshes the token with a form the server accepts', () {
      final auth = config.authorization!;
      expect(auth.accessToken, 'access-1');
      expect(auth.refreshToken, 'refresh-1');
      expect(auth.refreshUrl, endsWith('/api/v1/auth/refresh'));
      expect(auth.refreshPayload, {'refresh_token': '{refreshToken}'});
      expect(auth.expires, -1);
    });

    test('the production preset', () {
      final geo = config.geolocation!;
      expect(geo.distanceFilter, 50);
      expect(geo.stopTimeout, 5);
      expect(geo.filter!.trackingAccuracyThreshold, 50);
      expect(geo.locationAuthorizationRequest, 'Any');
      expect(geo.disableLocationAuthorizationAlert, isTrue);
      final app = config.app!;
      expect(app.stopOnTerminate, isFalse);
      expect(app.startOnBoot, isTrue);
      expect(app.enableHeadless, isTrue);
      expect(config.persistence!.maxDaysToPersist, 14);
      expect(config.reset, isTrue);
    });
  });

  group('BatchResult', () {
    test('reads the server\'s instruction', () {
      final r = BatchResult.parse(
        200,
        '{"accepted":5,"dropped":0,"load_status":"confirmed",'
        '"stop_tracking":true}',
      );
      expect(r.stopTracking, isTrue);
      expect(r.loadStatus, 'confirmed');

      final going = BatchResult.parse(
        200,
        '{"accepted":5,"dropped":0,"load_status":"in_transit",'
        '"stop_tracking":false}',
      );
      expect(going.stopTracking, isFalse);
    });

    test('anything but a 2xx JSON answer says nothing', () {
      expect(
        BatchResult.parse(500, '{"stop_tracking":true}').stopTracking,
        isFalse,
      );
      expect(BatchResult.parse(200, '<html>').stopTracking, isFalse);
      expect(BatchResult.parse(200, '[]').stopTracking, isFalse);
      expect(BatchResult.parse(0, '').stopTracking, isFalse);
    });
  });

  group('ready at launch', () {
    test('gives the library the saved tokens and load back', () async {
      final service = FakeTrackingService(FakeBackend());
      final store = FakeLocalStore({
        StoreKeys.accessToken: 'access-0',
        StoreKeys.refreshToken: 'refresh-0',
        StoreKeys.trackingLoadId: 'A',
      });

      await TrackingRepository.ready(service, store, testTrackingTexts);

      expect(service.setup?.loadId, 'A');
      expect(service.setup?.refreshToken, 'refresh-0');
    });

    test('a library that fails to start leaves the app working', () async {
      final service = _BrokenTrackingService(FakeBackend());

      final snapshot = await TrackingRepository.ready(
        service,
        FakeLocalStore(),
        testTrackingTexts,
      );

      expect(snapshot.enabled, isFalse);
    });
  });
}

class _BrokenTrackingService extends FakeTrackingService {
  _BrokenTrackingService(super.backend);

  @override
  Future<TrackingSnapshot> ready(TrackingSetup setup) async =>
      throw Exception('plugin missing');
}
