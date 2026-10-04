import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/fix.dart';
import '../../utils/logger.dart';
import '../services/local_store.dart';
import '../services/tracking/tracking_config.dart';
import '../services/tracking/tracking_service.dart';

/// Background tracking of the active load: whether it runs and for which
/// load, how the points are getting to the server. The library records and
/// sends on its own, also with the app in the background or killed; this
/// is the app's side of it.
///
/// Which load to follow and when to stop is TrackingLifecycle's call; here
/// is how. Operations run one after another, in the order they were asked
/// for: a stop must not overtake the start before it.
class TrackingRepository extends ChangeNotifier {
  TrackingRepository({
    required this._service,
    required this._store,
    required this._texts,
    TrackingSnapshot launch = TrackingSnapshot.off,
    this.queueStuckAfter = const Duration(minutes: 5),
    this.flushTimeout = const Duration(seconds: 10),
    this.fixTimeout = const Duration(seconds: 12),
    this._now = DateTime.now,
  }) : _enabled = launch.enabled,
       _isMoving = launch.isMoving,
       _loadId = _store.getString(StoreKeys.trackingLoadId) {
    _subs
      ..add(_service.responses.listen(_onResponse))
      ..add(_service.recorded.listen((_) => _refreshQueue()))
      ..add(
        _service.motionChanges.listen((moving) {
          _isMoving = moving;
          if (!moving) _movingSinceStart = false;
          notifyListeners();
        }),
      )
      ..add(
        _service.enabledChanges.listen((on) {
          _enabled = on;
          notifyListeners();
        }),
      );
    unawaited(_refreshQueue());
  }

  /// Before runApp, also when the OS starts the app in the background to
  /// resume tracking (no widget is built then): the library must be ready
  /// on every launch, with the configuration it had.
  static Future<TrackingSnapshot> ready(
    TrackingService service,
    LocalStore store,
    TrackingTexts texts,
  ) async {
    try {
      return await service.ready(_setupFrom(store, texts));
    } catch (e, st) {
      log.error('Tracking library failed to start', e, st);
      return TrackingSnapshot.off;
    }
  }

  final TrackingService _service;
  final LocalStore _store;
  final TrackingTexts Function() _texts;
  final DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];

  /// Queued points older than this mean they aren't getting through.
  final Duration queueStuckAfter;

  /// How long [flush] waits for the queue to empty.
  final Duration flushTimeout;

  /// How long [currentFix] waits; a bit over the library's own timeout,
  /// should its answer never come.
  final Duration fixTimeout;

  bool _enabled;
  bool _isMoving;
  bool _movingSinceStart = false;
  String? _loadId;
  int _pending = 0;
  DateTime? _oldestPendingAt;
  bool _queueStuck = false;
  Timer? _stuckTimer;
  bool _flushing = false;
  Future<void> _queue = Future.value();
  final _serverStops = StreamController<void>.broadcast();

  bool get enabled => _enabled;

  bool get isMoving => _isMoving;

  /// The load stamped on new points; meaningful while [enabled].
  String? get loadId => _loadId;

  /// Points recorded but not yet taken by the server.
  int get pending => _pending;

  /// Points have been waiting longer than [queueStuckAfter]: no signal, or
  /// the server keeps refusing them. A handful always waits for the next
  /// batch, that's normal. Turns true on time also with nothing else
  /// happening: parked with no signal, no point is recorded or answered.
  bool get queueStuck => _queueStuck;

  /// The server said the load needs no more points and tracking stopped.
  Stream<void> get serverStops => _serverStops.stream;

  /// Tracks [loadId]: starts tracking or moves it on to this load.
  ///
  /// When the load changes, points of the previous one still queued are
  /// sent first. The server's answer is about the latest point of a batch,
  /// with no load id: a batch of only old points would say "stop" (that
  /// load is confirmed) and stop the new one. (Should it happen anyway, say
  /// with no signal to send them now, TrackingLifecycle fetches the loads
  /// after any stop and follows the active one again.)
  Future<void> follow(String loadId) => _serial(() async {
    if (_enabled && _loadId == loadId) return;
    final previous = _loadId;
    if (previous != null && previous != loadId) await _flush();
    log.info('[tracking] follow $loadId (was ${_enabled ? previous : 'off'})');
    _loadId = loadId;
    await _store.setString(StoreKeys.trackingLoadId, loadId);
    await _service.configure(_setup());
    _apply(await _service.start());
    _movingSinceStart = _isMoving;
  });

  /// Stops tracking. Queued points stay and go out with the next batch.
  Future<void> stop() => _serial(_stop);

  /// The driver did something (accepted the load, set off): assume
  /// they're about to move rather than waiting for the motion sensors,
  /// which would miss the first few hundred metres.
  ///
  /// Tracking starts moving already: told again right after, the library
  /// records the same fix once more. Only our own start counts, not the
  /// state read at launch.
  Future<void> moving() => _serial(() async {
    if (!_enabled || _movingSinceStart) return;
    await _service.changePace(true);
    _isMoving = true;
    notifyListeners();
  });

  /// Where the phone is, for a status change to mark on the map; null
  /// without one in [fixTimeout]. Only while tracking: off, the location
  /// may not be allowed, and the library would ask for it itself. Not
  /// queued behind other operations, a flush mustn't hold up the driver.
  Future<Fix?> currentFix() async {
    if (!_enabled) return null;
    try {
      return await _service.currentFix().timeout(fixTimeout);
    } catch (e) {
      log.warning('[tracking] no fix for the step: $e');
      return null;
    }
  }

  /// A new session's tokens, for the library's own requests. It refreshes
  /// the access token by itself on a 401; this is for sign-in.
  Future<void> setTokens() => _serial(() => _service.configure(_setup()));

  /// Sends what's queued, before signing out makes it impossible (logout
  /// revokes the library's copy of the tokens too). A batch the library
  /// is already sending is waited for. Gives up after [flushTimeout] or on
  /// failure: the driver isn't kept waiting.
  Future<void> flush() => _serial(_flush);

  /// Signed out: stops tracking and forgets every point still queued and
  /// the load, so nothing of this driver goes out under the next one.
  Future<void> reset() => _serial(() async {
    await _stop();
    try {
      await _service.destroyLocations();
    } catch (e, st) {
      log.error('Queued points not deleted', e, st);
    }
    _loadId = null;
    await _store.remove(StoreKeys.trackingLoadId);
    await _service.configure(_setup());
    await _refreshQueue();
  });

  Future<void> _stop() async {
    if (!_enabled) return;
    log.info('[tracking] stop ($_loadId)');
    _movingSinceStart = false;
    _apply(await _service.stop());
  }

  Future<void> _flush() async {
    if (await _service.pendingCount() == 0) return;
    _flushing = true;
    final clock = Stopwatch()..start();
    Duration left() => flushTimeout - clock.elapsed;
    try {
      while (await _service.pendingCount() > 0) {
        if (left() <= Duration.zero) {
          throw TimeoutException('queue not empty', flushTimeout);
        }
        final answered = _service.responses.first..ignore();
        try {
          await _service.sync().timeout(left());
        } on TrackingBusy {
          // The library is sending a batch of its own, maybe not all of
          // the queue: once it's answered, the rest.
          log.info('[tracking] flush: a batch is on its way, waiting');
          final wait = left() < _busyRetry ? left() : _busyRetry;
          await Future.any([answered, Future<void>.delayed(wait)]);
        }
      }
    } catch (e) {
      log.warning('[tracking] queued points not sent: $e');
    } finally {
      _flushing = false;
      await _refreshQueue();
    }
  }

  /// How often [flush] asks again while the library is busy, should its
  /// answer get lost.
  static const _busyRetry = Duration(milliseconds: 500);

  void _onResponse(BatchResult result) {
    unawaited(_refreshQueue());
    // While flushing, the answers are about the load being left behind.
    if (!result.stopTracking || _flushing || !_enabled) return;
    unawaited(
      _serial(() async {
        if (!_enabled) return;
        log.info('[tracking] server says stop (${result.loadStatus})');
        await _stop();
        _serverStops.add(null);
      }),
    );
  }

  Future<void> _refreshQueue() async {
    try {
      final (count, oldest) = await (
        _service.pendingCount(),
        _service.oldestPendingAt(),
      ).wait;
      if (count == _pending && oldest == _oldestPendingAt) return;
      _pending = count;
      _oldestPendingAt = count == 0 ? null : oldest;
      _watchQueueAge();
      notifyListeners();
    } catch (e) {
      log.warning('[tracking] queue not read: $e');
    }
  }

  /// Sets [queueStuck] for the oldest queued point, now or when it gets
  /// too old.
  void _watchQueueAge() {
    _stuckTimer?.cancel();
    _stuckTimer = null;
    final oldest = _oldestPendingAt;
    if (oldest == null) {
      _queueStuck = false;
      return;
    }
    final left = oldest.add(queueStuckAfter).difference(_now());
    _queueStuck = left < Duration.zero;
    if (_queueStuck) return;
    _stuckTimer = Timer(left, () {
      _queueStuck = true;
      notifyListeners();
    });
  }

  void _apply(TrackingSnapshot snapshot) {
    _enabled = snapshot.enabled;
    _isMoving = snapshot.isMoving;
    notifyListeners();
  }

  TrackingSetup _setup() => _setupFrom(_store, _texts(), loadId: _loadId);

  static TrackingSetup _setupFrom(
    LocalStore store,
    TrackingTexts texts, {
    String? loadId,
  }) => TrackingSetup(
    accessToken: store.getString(StoreKeys.accessToken),
    refreshToken: store.getString(StoreKeys.refreshToken),
    loadId: loadId ?? store.getString(StoreKeys.trackingLoadId),
    texts: texts,
  );

  /// Runs [op] after every operation asked for before it. A failure is
  /// logged and doesn't hold up the ones after.
  Future<void> _serial(Future<void> Function() op) {
    final next = _queue.then((_) => op()).catchError((Object e, StackTrace st) {
      log.error('[tracking] operation failed', e, st);
    });
    _queue = next;
    return next;
  }

  @override
  void dispose() {
    _stuckTimer?.cancel();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_serverStops.close());
    super.dispose();
  }
}
