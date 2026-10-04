import 'dart:async';

import 'package:driver_tracking_app/data/services/tracking/tracking_config.dart';
import 'package:driver_tracking_app/data/services/tracking/tracking_service.dart';

import 'fake_backend.dart';

typedef QueuedPoint = ({String? loadId, DateTime at});

const testTrackingTexts = TrackingTexts(
  notificationTitle: 'title',
  notificationText: 'text',
  rationaleTitle: 'rationale',
  rationaleMessage: 'choose {backgroundPermissionOptionLabel}',
  rationaleAllow: 'allow',
  rationaleCancel: 'cancel',
);

/// The tracking library on a fake phone: points are recorded on demand
/// ([record]), stamped with the load configured at that moment, queued,
/// and sent in batches to [backend], whose answers come back on
/// [responses] like the library's onHttp.
class FakeTrackingService implements TrackingService {
  FakeTrackingService(this.backend);

  final FakeBackend backend;

  bool enabled = false;
  bool isMoving = false;
  TrackingSetup? setup;
  final queue = <QueuedPoint>[];

  /// Every call, in order: `ready`, `configure:<load>`, `start`, `stop`,
  /// `pace:<moving>`, `sync`, `destroy`.
  final calls = <String>[];

  /// start() throws, as without a location permission.
  bool failStart = false;

  /// While set, sync() waits for it: the server is slow to answer.
  Completer<void>? syncHeld;

  /// While set, autoSync() waits for it before its batch reaches the
  /// server; sync() meanwhile fails with TrackingBusy, like the library.
  Completer<void>? autoSyncHeld;

  bool _sending = false;

  /// The backend's logout count when sync() was last called.
  int? logoutsAtSync;

  final _responses = StreamController<BatchResult>.broadcast();
  final _recorded = StreamController<void>.broadcast();
  final _motion = StreamController<bool>.broadcast();
  final _enabled = StreamController<bool>.broadcast();

  TrackingSnapshot get _snapshot =>
      TrackingSnapshot(enabled: enabled, isMoving: isMoving);

  @override
  Future<TrackingSnapshot> ready(TrackingSetup setup) async {
    calls.add('ready');
    this.setup = setup;
    return _snapshot;
  }

  @override
  Future<void> configure(TrackingSetup setup) async {
    calls.add('configure:${setup.loadId}');
    this.setup = setup;
  }

  @override
  Future<TrackingSnapshot> start() async {
    calls.add('start');
    if (failStart) throw Exception('no permission');
    enabled = true;
    _enabled.add(true);
    return _snapshot;
  }

  @override
  Future<TrackingSnapshot> stop() async {
    calls.add('stop');
    enabled = false;
    isMoving = false;
    _enabled.add(false);
    return _snapshot;
  }

  @override
  Future<void> changePace(bool moving) async {
    calls.add('pace:$moving');
    isMoving = moving;
  }

  /// The library takes a point (only while tracking).
  void record({DateTime? at}) {
    if (!enabled) return;
    queue.add((loadId: setup?.loadId, at: at ?? DateTime.now()));
    _recorded.add(null);
  }

  /// The library sends its queue on its own (enough points, a stop or a
  /// start, the network back), in batches of [batchSize].
  Future<void> autoSync({int batchSize = 250}) async {
    _sending = true;
    try {
      if (autoSyncHeld case final held?) await held.future;
      await _send(batchSize);
    } finally {
      _sending = false;
    }
  }

  @override
  Future<int> pendingCount() async => queue.length;

  @override
  Future<DateTime?> oldestPendingAt() async =>
      queue.isEmpty ? null : queue.first.at;

  @override
  Future<void> sync() async {
    calls.add('sync');
    logoutsAtSync = backend.logouts;
    if (_sending) throw const TrackingBusy();
    if (syncHeld case final held?) await held.future;
    await _send(250);
  }

  Future<void> _send(int batchSize) async {
    while (queue.isNotEmpty) {
      if (!backend.online) throw Exception('no network');
      final batch = queue.take(batchSize).toList();
      final result = backend.takePoints([for (final p in batch) p.loadId]);
      queue.removeRange(0, batch.length);
      _responses.add(result);
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> destroyLocations() async {
    calls.add('destroy');
    queue.clear();
  }

  @override
  Stream<BatchResult> get responses => _responses.stream;

  @override
  Stream<void> get recorded => _recorded.stream;

  @override
  Stream<bool> get motionChanges => _motion.stream;

  @override
  Stream<bool> get enabledChanges => _enabled.stream;
}
