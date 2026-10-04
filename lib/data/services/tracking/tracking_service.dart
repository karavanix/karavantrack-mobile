import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../../../domain/models/fix.dart';
import '../../../utils/logger.dart';
import 'headless.dart';
import 'tracking_config.dart';

/// The library's state as far as the app cares.
class TrackingSnapshot {
  const TrackingSnapshot({required this.enabled, required this.isMoving});

  static const off = TrackingSnapshot(enabled: false, isMoving: false);

  /// Tracking is on: the library records and sends points.
  final bool enabled;

  /// The library thinks the phone is moving (GPS on); false while parked.
  final bool isMoving;
}

/// The server's answer to a batch of points, `POST /tracking/locations`.
class BatchResult {
  const BatchResult({
    required this.status,
    required this.stopTracking,
    this.loadStatus,
  });

  /// [body] is the response as the library hands it over. Anything that
  /// isn't the expected JSON is a result without instructions.
  factory BatchResult.parse(int status, String body) {
    var stop = false;
    String? loadStatus;
    if (status >= 200 && status < 300) {
      try {
        if (jsonDecode(body) case final Map<String, Object?> map) {
          stop = map['stop_tracking'] == true;
          if (map['load_status'] case final String s) loadStatus = s;
        }
      } on FormatException {
        // Not ours to judge: the points were taken.
      }
    }
    return BatchResult(
      status: status,
      stopTracking: stop,
      loadStatus: loadStatus,
    );
  }

  final int status;

  /// The load of the batch's latest point needs no more points: confirmed,
  /// cancelled, waiting for confirmation too long, or not this driver's.
  final bool stopTracking;

  final String? loadStatus;

  bool get ok => status >= 200 && status < 300;
}

/// [TrackingService.sync] while the library is sending a batch of its own:
/// it takes one request at a time.
class TrackingBusy implements Exception {
  const TrackingBusy();

  @override
  String toString() => 'TrackingBusy';
}

/// The tracking library (flutter_background_geolocation): it records the
/// points, keeps them in its own database and sends them to the server
/// with its own HTTP client, also while the app is in the background or
/// killed. No state here; TrackingRepository keeps it.
abstract interface class TrackingService {
  /// Once per launch, before anything else touches the library, also when
  /// the OS starts the app in the background to resume tracking.
  Future<TrackingSnapshot> ready(TrackingSetup setup);

  /// Replaces the configuration (tokens, the load stamped on points).
  Future<void> configure(TrackingSetup setup);

  Future<TrackingSnapshot> start();

  Future<TrackingSnapshot> stop();

  /// Tells the library the phone is (not) moving right now, rather than
  /// waiting for the motion sensors: a driver's action means they're
  /// about to drive off.
  Future<void> changePace(bool moving);

  /// Where the phone is now: the latest fix if it's fresh, else a new one
  /// (the GPS is switched on for it while parked). Not queued for sending.
  /// Fails without a fix in time.
  Future<Fix> currentFix();

  /// Points recorded but not yet accepted by the server.
  Future<int> pendingCount();

  /// When the oldest of them was recorded; null with nothing queued.
  Future<DateTime?> oldestPendingAt();

  /// Sends everything queued now. Fails without a connection, and with
  /// [TrackingBusy] while a batch is already on its way.
  Future<void> sync();

  /// Forgets every queued point.
  Future<void> destroyLocations();

  /// Every answer of the server to a batch.
  Stream<BatchResult> get responses;

  /// A point recorded.
  Stream<void> get recorded;

  Stream<bool> get motionChanges;

  Stream<bool> get enabledChanges;
}

/// [TrackingService] on flutter_background_geolocation.
class BgTrackingService implements TrackingService {
  final _responses = StreamController<BatchResult>.broadcast();
  final _recorded = StreamController<void>.broadcast();
  final _motion = StreamController<bool>.broadcast();
  final _enabled = StreamController<bool>.broadcast();

  @override
  Future<TrackingSnapshot> ready(TrackingSetup setup) async {
    // The listeners go first: events of a background launch may come as
    // soon as ready() returns.
    bg.BackgroundGeolocation.onHttp((e) {
      final result = BatchResult.parse(e.status, e.responseText);
      log.info(
        '[tracking] batch: ${e.status}'
        '${result.stopTracking ? ', stop_tracking' : ''}',
      );
      _responses.add(result);
    });
    bg.BackgroundGeolocation.onLocation(
      (_) => _recorded.add(null),
      (e) => log.warning('[tracking] location error: $e'),
    );
    bg.BackgroundGeolocation.onMotionChange((l) {
      log.info('[tracking] moving: ${l.isMoving}');
      _motion.add(l.isMoving);
      _recorded.add(null);
    });
    bg.BackgroundGeolocation.onEnabledChange((on) {
      log.info('[tracking] enabled: $on');
      _enabled.add(on);
    });
    bg.BackgroundGeolocation.onAuthorization((e) {
      if (!e.success) log.warning('[tracking] token refresh failed: $e');
    });
    final state = await bg.BackgroundGeolocation.ready(trackingConfig(setup));
    log.info(
      '[tracking] ready: enabled ${state.enabled}'
      '${state.didLaunchInBackground ? ', launched in background' : ''}',
    );
    if (Platform.isAndroid) {
      await bg.BackgroundGeolocation.registerHeadlessTask(trackingHeadlessTask);
    }
    return _snapshot(state);
  }

  @override
  Future<void> configure(TrackingSetup setup) =>
      bg.BackgroundGeolocation.setConfig(trackingConfig(setup));

  @override
  Future<TrackingSnapshot> start() async =>
      _snapshot(await bg.BackgroundGeolocation.start());

  @override
  Future<TrackingSnapshot> stop() async =>
      _snapshot(await bg.BackgroundGeolocation.stop());

  @override
  Future<void> changePace(bool moving) =>
      bg.BackgroundGeolocation.changePace(moving);

  @override
  Future<Fix> currentFix() async {
    final l = await bg.BackgroundGeolocation.getCurrentPosition(
      // Driving, a point is recorded every ~10 s: that one will do.
      maximumAge: 60000,
      timeout: 10,
      desiredAccuracy: 50,
      samples: 3,
      // The step's point goes with the step; queued as well, it would be
      // a second copy of the same fix.
      persist: false,
    );
    final c = l.coords;
    // The library has -1 for what the fix doesn't know (no GPS: no speed).
    double? known(double v) => v < 0 ? null : v;
    return Fix(
      lat: c.latitude,
      lng: c.longitude,
      recordedAt: DateTime.tryParse('${l.timestamp}') ?? DateTime.now(),
      accuracyM: known(c.accuracy),
      speedMps: known(c.speed),
      headingDeg: known(c.heading),
    );
  }

  @override
  Future<int> pendingCount() => bg.BackgroundGeolocation.count;

  @override
  Future<DateTime?> oldestPendingAt() async {
    final rows = await bg.BackgroundGeolocation.getLocations(
      bg.LocationQuery(limit: 1, order: bg.LocationQuery.ORDER_ASC),
    );
    if (rows.isEmpty) return null;
    // Android hands over the raw location; iOS the record as rendered by
    // locationTemplate, where the time is `recorded_at`.
    if (rows.first case {'timestamp': final String at} ||
        {'recorded_at': final String at}) {
      return DateTime.tryParse(at);
    }
    return null;
  }

  @override
  Future<void> sync() async {
    try {
      await bg.BackgroundGeolocation.sync();
    } on PlatformException catch (e) {
      // Android: PlatformException(HTTPService is busy, ...).
      final text = '${e.code} ${e.message}'.toLowerCase();
      if (text.contains('busy')) throw const TrackingBusy();
      rethrow;
    }
  }

  @override
  Future<void> destroyLocations() =>
      bg.BackgroundGeolocation.destroyLocations();

  @override
  Stream<BatchResult> get responses => _responses.stream;

  @override
  Stream<void> get recorded => _recorded.stream;

  @override
  Stream<bool> get motionChanges => _motion.stream;

  @override
  Stream<bool> get enabledChanges => _enabled.stream;

  static TrackingSnapshot _snapshot(bg.State state) => TrackingSnapshot(
    enabled: state.enabled,
    isMoving: state.isMoving ?? false,
  );
}
