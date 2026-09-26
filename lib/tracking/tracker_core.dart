import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api_service.dart' show kAuthTokenKey, kRefreshTokenKey;

// ─── The one tracking policy, shared by every platform ─────────────────────
//
// Everything that decides WHAT gets recorded and HOW it reaches the server
// lives here: the adaptive 2/10-minute sampling, jitter filtering, the
// persistent offline queue, token refresh, the WebSocket used for
// start/stop_live_location, live-mode streaming and its ack.
//
// What differs per platform is only WHERE this code runs (see
// tracker_runner.dart): on Android inside the flutter_background_service
// isolate, which survives the app being swiped away; on iOS in the main
// isolate, kept alive in the background by the position stream in
// GpsService, because iOS has no long-running background service at all.
// Change tracking behavior here and it changes on both platforms.

// ─── SharedPreferences keys ────────────────────────────────────────────────
const String kBgActiveLoadId = 'bg_active_load_id';
const String kBgCarrierId = 'bg_carrier_id';
const String kBgAuthToken = 'bg_auth_token';
// JSON-encoded list of points that couldn't be sent (offline, server error)
// and are waiting to be flushed via the /location/batch endpoint.
const String kBgPendingPoints = 'bg_pending_points';

const String _kBaseUrl = 'https://api.yool.live';
const String _kBasePath = '/api/v1';

// Mirrors MaxLoadLocationBatchSize server-side (register_load_location_batch.go).
const int _kMaxQueuedPoints = 500;

// ─── Adaptive interval (normal mode) ───────────────────────────────────────
// Speed threshold (m/s) above which the truck is considered moving (~5 km/h).
const double _kMovingThresholdMps = 1.5;
const Duration _kMovingInterval = Duration(minutes: 2);
const Duration _kStationaryInterval = Duration(minutes: 10);
const Duration _kTickInterval = Duration(minutes: 1);

// Upper bounds so one hung request or GPS fix can't wedge the tracker: a tick
// and a flush each run one at a time, so without these a half-open
// connection on bad cell signal would block every tick after it forever.
const Duration kTrackerHttpTimeout = Duration(seconds: 30);
const Duration _kFixTimeout = Duration(seconds: 30);

// ─── Client-side jitter filtering ──────────────────────────────────────────
// Conservative on purpose — these only reject fixes bad enough to be noise,
// not real maneuvers. Tune against real driving data before tightening.

// Urban GPS error alone runs 20-50m; a fix worse than that is more likely
// noise than a real position, so it's dropped rather than recorded.
const double _kMaxAcceptableAccuracyM = 50.0;

// While parked, a new point is only kept if it moved further than GPS noise
// could plausibly account for — floor of 15m, or 2x the fix's own reported
// accuracy, whichever is larger. This is what turns a standing truck into a
// single point on the map instead of a tangle of jitter.
const double _kParkedHysteresisFloorM = 15.0;
const double _kParkedHysteresisAccuracyMultiplier = 2.0;

double _distanceMeters(Position a, Position b) {
  const earthRadiusM = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(b.latitude - a.latitude);
  final dLng = toRad(b.longitude - a.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(a.latitude)) *
          math.cos(toRad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

// ─── Tokens ────────────────────────────────────────────────────────────────

/// Where the tracker gets its bearer token. Each runner plugs in the source
/// that fits its isolate: the Android background isolate has no access to
/// the UI isolate's ApiService, the iOS in-process tracker does.
abstract class TrackerTokenSource {
  /// A token good for at least 30 more seconds, refreshing first if needed.
  Future<String?> fresh();

  /// Forces a refresh — called after the server answered 401.
  Future<String?> refresh();
}

/// Decodes a JWT's `exp` claim without verifying the signature. Safe here:
/// the token was already issued by our own server: this is only used to
/// decide *when* to proactively refresh, not to trust the token's claims.
DateTime? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'] as int?;
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

bool jwtExpiresSoon(String token) {
  final expiry = jwtExpiry(token);
  return expiry == null ||
      expiry.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)));
}

/// Token source for an isolate with no shared memory with the UI isolate:
/// reads and refreshes tokens straight from SharedPreferences.
///
/// Refresh tokens are NOT single-use server-side — RefreshTokenUsecase only
/// checks a revocation cursor, not that the token hasn't been redeemed before
/// — so this isolate and the UI isolate can both refresh independently
/// without racing each other over the same refresh token.
class PrefsTokenSource implements TrackerTokenSource {
  @override
  Future<String?> fresh() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kBgAuthToken);
    if (token == null || token.isEmpty) return null;
    if (!jwtExpiresSoon(token)) return token;
    return await refresh() ?? token;
  }

  /// Redeems the refresh token and writes the new pair back to the keys both
  /// isolates read, so the UI isolate picks up the refreshed tokens too.
  @override
  Future<String?> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(kRefreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$_kBaseUrl$_kBasePath/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(kTrackerHttpTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || refresh == null) return null;
      await prefs.setString(kAuthTokenKey, access);
      await prefs.setString(kRefreshTokenKey, refresh);
      await prefs.setString(kBgAuthToken, access);
      return access;
    } catch (_) {
      return null;
    }
  }
}

// ─── Queue helpers (also read by the UI for the buffer counter) ───────────

List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
  final raw = prefs.getString(kBgPendingPoints);
  if (raw == null || raw.isEmpty) return [];
  try {
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

/// Number of queued (not yet delivered) points per load_id.
Map<String, int> pendingPointCounts(SharedPreferences prefs) {
  final counts = <String, int>{};
  for (final p in _readQueue(prefs)) {
    final loadId = p['load_id'] as String?;
    if (loadId == null || loadId.isEmpty) continue;
    counts[loadId] = (counts[loadId] ?? 0) + 1;
  }
  return counts;
}

// ─── The tracker ───────────────────────────────────────────────────────────

class TrackerCore {
  TrackerCore({
    required this.tokens,
    required this.liveStreamSettings,
    this.onTick,
  });

  final TrackerTokenSource tokens;

  /// Settings for the live-mode position stream. On iOS this must be the
  /// same settings GpsService uses for its keep-alive stream: geolocator
  /// hands every subscriber in an isolate the one stream created first,
  /// so whichever subscribes first decides e.g. background delivery.
  final LocationSettings liveStreamSettings;

  /// Called at the start of every tick — the Android runner uses it to
  /// refresh the foreground notification's timestamp.
  final void Function()? onTick;

  bool _running = false;
  Timer? _tickTimer;
  bool _ticking = false;
  Future<bool>? _inflightFlush;

  DateTime? _lastSentAt;

  /// The last point actually kept (queued), used as the hysteresis anchor
  /// while parked. Deliberately NOT updated on a point that gets filtered out,
  /// so slow drift across many rejected fixes still gets caught once it
  /// exceeds the threshold relative to the last real position.
  Position? _lastKeptPosition;

  // Live mode state (WebSocket fast mode)
  WebSocketChannel? _wsChannel;
  bool _wsConnected = false;
  Timer? _wsReconnectTimer;
  // Reconnect delay grows with each failed attempt, capped at 30 s.
  int _wsReconnectDelaySec = 5;
  Timer? _liveTrackingWatchdog;
  StreamSubscription<Position>? _liveGpsSubscription;

  bool get isRunning => _running;

  /// Starts ticking and connects the WebSocket. Returns right away — the
  /// first fix and the socket handshake happen in the background, so a
  /// caller like "accept load" isn't held up by a slow GPS fix.
  void start() {
    if (_running) return;
    _running = true;
    unawaited(_connectWs());
    _tickTimer = Timer.periodic(_kTickInterval, (_) => tick());
    unawaited(tick());
  }

  /// Stops everything and does not reconnect. On Android the isolate dies
  /// right after anyway; on iOS the tracker lives in the main isolate, so
  /// leaving a reconnect loop or GPS stream behind would outlive the load.
  Future<void> stop() async {
    _running = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _stopLiveMode();
    final channel = _wsChannel;
    _wsChannel = null;
    _wsConnected = false;
    await channel?.sink.close();
  }

  /// Sends whatever is queued right now instead of waiting for the next
  /// tick — used when connectivity comes back and before a load completes.
  Future<void> flushNow() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await tokens.fresh();
    if (token == null || token.isEmpty) return;
    await _flushQueue(prefs: prefs, token: token);
  }

  // ─── WebSocket client ────────────────────────────────────────────────────

  Future<void> _connectWs() async {
    if (!_running) return;
    final token = await tokens.fresh() ?? '';
    if (!_running) return;
    if (token.isEmpty) {
      _scheduleWsReconnect();
      return;
    }

    final wsUri = Uri.parse(
      '${_kBaseUrl.replaceAll('https://', 'wss://').replaceAll('http://', 'ws://')}$_kBasePath/ws?token=$token',
    );

    WebSocketChannel? channel;
    try {
      final connecting = WebSocketChannel.connect(wsUri);
      channel = connecting;
      _wsChannel = connecting;
      connecting.stream.listen(
        _onWsMessage,
        onDone: () => _onWsClosed(connecting),
        onError: (_) => _onWsClosed(connecting),
        cancelOnError: true,
      );
      await connecting.ready.timeout(kTrackerHttpTimeout);
      if (!_running || _wsChannel != connecting) {
        // Stopped (or replaced) while the handshake was in flight.
        unawaited(connecting.sink.close().catchError((_) {}));
        return;
      }
      _wsConnected = true;
      _wsReconnectDelaySec = 5; // reset backoff only once actually connected
    } catch (_) {
      // Handshake failure. The stream usually reports it too; _onWsClosed
      // ignores whichever of the two arrives second.
      if (channel != null) {
        _onWsClosed(channel);
        unawaited(channel.sink.close().catchError((_) {}));
      } else {
        _scheduleWsReconnect();
      }
    }
  }

  void _onWsClosed(WebSocketChannel channel) {
    // Ignore a late close from a socket already replaced or shut down.
    if (_wsChannel != channel) return;
    _wsChannel = null;
    _wsConnected = false;
    // Live points only travel over this socket, so without it live mode has
    // nowhere to send them. The regular tick keeps recording into the queue;
    // the server's keepalive re-sends start_live_location after reconnect.
    _stopLiveMode();
    _scheduleWsReconnect();
  }

  void _scheduleWsReconnect() {
    if (!_running) return;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(
      Duration(seconds: _wsReconnectDelaySec),
      _connectWs,
    );
    // Exponential backoff capped at 30 s
    if (_wsReconnectDelaySec < 30) {
      _wsReconnectDelaySec = (_wsReconnectDelaySec * 2).clamp(5, 30);
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['event']) {
        case 'start_live_location':
          _startLiveMode();
          break;
        case 'stop_live_location':
          _stopLiveMode();
          break;
      }
    } catch (_) {}
  }

  // ─── Live mode (WebSocket GPS stream) ────────────────────────────────────

  // The server's start_live_location is a one-way NATS publish — it has no
  // idea whether the phone actually managed to start streaming. This acks
  // back so the shipper's "Live" badge reflects reality instead of just the
  // shipper's own browser socket.
  Future<void> _startLiveMode() async {
    final gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) {
      await _sendLiveAckViaWs('failed', reason: 'gps_disabled');
      return;
    }

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      await _sendLiveAckViaWs('failed', reason: 'no_permission');
      return;
    }

    // Reset the 5-minute watchdog — if no keepalive renewal arrives the driver
    // reverts to normal mode automatically.
    _liveTrackingWatchdog?.cancel();
    _liveTrackingWatchdog = Timer(const Duration(minutes: 5), _stopLiveMode);

    // Subscribe to the position stream and forward each fix over the WebSocket.
    await _liveGpsSubscription?.cancel();
    _liveGpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: liveStreamSettings,
        ).listen(
          _sendPositionViaWs,
          onError: (_) {
            // GPS got disabled (or another stream failure) mid-flight — tell the
            // shipper the live stream actually died instead of leaving them
            // looking at a badge that's frozen on the last known good state.
            _sendLiveAckViaWs('failed', reason: 'gps_disabled');
            _stopLiveMode();
          },
        );

    await _sendLiveAckViaWs('started');
  }

  void _stopLiveMode() {
    _liveTrackingWatchdog?.cancel();
    _liveTrackingWatchdog = null;
    // Only cancels OUR subscription. On iOS the stream is shared with
    // GpsService's keep-alive listener and stays open as long as that one does.
    _liveGpsSubscription?.cancel();
    _liveGpsSubscription = null;
  }

  Future<void> _sendLiveAckViaWs(String status, {String? reason}) async {
    if (!_wsConnected || _wsChannel == null) return;

    final prefs = await SharedPreferences.getInstance();
    final loadId = prefs.getString(kBgActiveLoadId) ?? '';
    if (loadId.isEmpty) return;

    try {
      _wsChannel!.sink.add(
        jsonEncode({
          'event': 'live_location_ack',
          'data': {'load_id': loadId, 'status': status, 'reason': ?reason},
        }),
      );
    } catch (_) {}
  }

  Future<void> _sendPositionViaWs(Position pos) async {
    if (!_wsConnected || _wsChannel == null) return;

    final prefs = await SharedPreferences.getInstance();
    final loadId = prefs.getString(kBgActiveLoadId) ?? '';
    if (loadId.isEmpty) return;

    try {
      _wsChannel!.sink.add(
        jsonEncode({
          'event': 'location',
          'data': {
            'load_id': loadId,
            'lat': pos.latitude,
            'lng': pos.longitude,
            'speed_mps': pos.speed < 0 ? 0.0 : pos.speed,
            'accuracy_m': pos.accuracy,
            'heading_deg': pos.heading,
            // The fix's own timestamp (already UTC — see Position.fromMap),
            // not the moment this function runs. The stream can hand us a
            // backlog of fixes in one dispatch; stamping them all with "now"
            // collapses their true spacing to milliseconds, which is
            // indistinguishable from a GPS teleport once it reaches the
            // server's speed-plausibility check.
            'recorded_at': pos.timestamp.toIso8601String(),
          },
        }),
      );
    } catch (_) {}
  }

  // ─── Normal tick — queue-and-flush ───────────────────────────────────────
  // Every fix is written to a local queue before it's ever sent, and each tick
  // tries to flush that queue via the batch endpoint. A point that fails to
  // send (no signal, server hiccup) simply stays queued and goes out with the
  // next successful flush, with its original recorded_at — instead of being
  // dropped, which is what happened before.

  Future<void> tick() async {
    // A slow GPS fix or request must not let ticks pile up on top of each other.
    if (!_running || _ticking) return;
    _ticking = true;
    try {
      await _tick();
    } finally {
      _ticking = false;
    }
  }

  Future<void> _tick() async {
    onTick?.call();

    final prefs = await SharedPreferences.getInstance();
    final loadId = prefs.getString(kBgActiveLoadId);

    if (loadId == null || loadId.isEmpty) return;

    final token = await tokens.fresh();
    if (token == null || token.isEmpty) return;

    // Always attempt to drain whatever is already queued, regardless of the
    // movement interval below — this is what lets a backlog built up while
    // offline empty out as soon as connectivity returns. Queued points carry
    // their own load_id (see _enqueuePoint), so this also flushes anything
    // stranded from a load that has since completed and is no longer active.
    await _flushQueue(prefs: prefs, token: token);

    try {
      final gpsOn = await Geolocator.isLocationServiceEnabled();
      if (!gpsOn) return;

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: _kFixTimeout,
        ),
      );

      // A fix this imprecise is more likely noise than a real position —
      // skip it rather than record it and retry next tick.
      if (pos.accuracy > _kMaxAcceptableAccuracyM) return;

      final isMoving = (pos.speed) > _kMovingThresholdMps;
      final requiredInterval = isMoving
          ? _kMovingInterval
          : _kStationaryInterval;
      final now = DateTime.now();

      if (_lastSentAt != null &&
          now.difference(_lastSentAt!) < requiredInterval) {
        return;
      }

      if (!isMoving && _lastKeptPosition != null) {
        final hysteresisThreshold = math.max(
          _kParkedHysteresisFloorM,
          _kParkedHysteresisAccuracyMultiplier * pos.accuracy,
        );
        if (_distanceMeters(_lastKeptPosition!, pos) < hysteresisThreshold) {
          // Parked, and within GPS noise of the last kept point — nothing to
          // report. Still advance the gate so the next check waits out the
          // full stationary interval instead of re-sampling every minute.
          _lastSentAt = now;
          return;
        }
      }

      await _enqueuePoint(prefs, loadId, pos);
      _lastKeptPosition = pos;
      // Only advance the interval gate on a successful flush — while offline
      // this means the tick timer (every 1 min) keeps sampling and queueing
      // instead of waiting out the full 2-10 min interval, which is the
      // point: capture as much of the real path as the queue cap allows.
      final flushed = await _flushQueue(prefs: prefs, token: token);
      if (flushed) _lastSentAt = now;
    } catch (_) {
      // Silently skip — will retry on next tick
    }
  }

  Future<void> _enqueuePoint(
    SharedPreferences prefs,
    String loadId,
    Position pos,
  ) async {
    final queue = _readQueue(prefs);
    queue.add({
      // Local-only id to identify this exact point when removing it from the
      // queue after a successful send; stripped before it's sent to the API.
      '_qid': '${DateTime.now().microsecondsSinceEpoch}_${queue.length}',
      'load_id': loadId,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'speed_mps': pos.speed < 0 ? 0.0 : pos.speed,
      'accuracy_m': pos.accuracy,
      'heading_deg': pos.heading,
      // The fix's own timestamp (already UTC), not enqueue time — see the
      // matching note in _sendPositionViaWs. This matters even more here:
      // a point can sit in the queue for hours before a flush actually
      // sends it, so "now" would be wrong by however long it waited.
      'recorded_at': pos.timestamp.toIso8601String(),
    });
    // Bound growth: keep the most recent points rather than let a long
    // offline stretch (or a stuck load) grow this without limit.
    if (queue.length > _kMaxQueuedPoints) {
      queue.removeRange(0, queue.length - _kMaxQueuedPoints);
    }
    await prefs.setString(kBgPendingPoints, jsonEncode(queue));
  }

  /// Only one flush at a time: a tick and a [flushNow] racing each other
  /// would both post the same snapshot, and the server doesn't dedupe.
  Future<bool> _flushQueue({
    required SharedPreferences prefs,
    required String token,
  }) {
    final inflight = _inflightFlush;
    if (inflight != null) return inflight;
    final flush = _doFlushQueue(prefs: prefs, token: token);
    _inflightFlush = flush;
    return flush.whenComplete(() => _inflightFlush = null);
  }

  /// Posts everything currently queued via the batch endpoint, one request per
  /// load_id (a queue can span more than one load if it wasn't fully drained
  /// before the driver moved on to the next). Points are matched by their
  /// local `_qid` when removing sent ones from the persisted queue afterwards,
  /// so a point enqueued while a request is in flight is never lost even if
  /// it races with this flush.
  Future<bool> _doFlushQueue({
    required SharedPreferences prefs,
    required String token,
  }) async {
    final snapshot = _readQueue(prefs);
    if (snapshot.isEmpty) return true;

    final byLoad = <String, List<Map<String, dynamic>>>{};
    for (final p in snapshot) {
      final loadId = p['load_id'] as String?;
      if (loadId == null || loadId.isEmpty) continue;
      byLoad.putIfAbsent(loadId, () => []).add(p);
    }

    var currentToken = token;
    final sentQids = <String>{};
    var allOk = true;

    for (final entry in byLoad.entries) {
      final wirePoints = entry.value
          .map(
            (p) => {
              'lat': p['lat'],
              'lng': p['lng'],
              'speed_mps': p['speed_mps'],
              'accuracy_m': p['accuracy_m'],
              'heading_deg': p['heading_deg'],
              'recorded_at': p['recorded_at'],
            },
          )
          .toList();
      final body = jsonEncode({'points': wirePoints});
      final uri = Uri.parse(
        '$_kBaseUrl$_kBasePath/loads/${entry.key}/location/batch',
      );

      bool ok;
      try {
        var response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $currentToken',
              },
              body: body,
            )
            .timeout(kTrackerHttpTimeout);
        if (response.statusCode == 401) {
          final refreshed = await tokens.refresh();
          if (refreshed != null) {
            currentToken = refreshed;
            response = await http
                .post(
                  uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $currentToken',
                  },
                  body: body,
                )
                .timeout(kTrackerHttpTimeout);
          }
        }
        ok = response.statusCode >= 200 && response.statusCode < 300;
      } catch (_) {
        ok = false;
      }

      if (ok) {
        sentQids.addAll(entry.value.map((p) => p['_qid'] as String));
      } else {
        allOk = false;
      }
    }

    if (sentQids.isNotEmpty) {
      final current = _readQueue(prefs);
      final remaining = current
          .where((p) => !sentQids.contains(p['_qid']))
          .toList();
      if (remaining.isEmpty) {
        await prefs.remove(kBgPendingPoints);
      } else {
        await prefs.setString(kBgPendingPoints, jsonEncode(remaining));
      }
    }

    return allOk;
  }
}

// ─── Active-load context (written by the UI, read by the tracker) ─────────

/// Write active-load context so the tracker can pick it up.
Future<void> setBgActiveLoad({
  required String loadId,
  required String carrierId,
  required String token,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kBgActiveLoadId, loadId);
  await prefs.setString(kBgCarrierId, carrierId);
  await prefs.setString(kBgAuthToken, token);
}

/// Clear active-load context (call on complete or logout).
///
/// Deliberately does NOT touch the pending-points queue: queued points carry
/// their own load_id and must survive a load completing so they still get
/// flushed once the driver's next load starts the tracker again. Call
/// [clearBgPendingPoints] separately on logout, where a stale queue from a
/// previous account is no longer wanted.
Future<void> clearBgActiveLoad() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kBgActiveLoadId);
  await prefs.remove(kBgCarrierId);
  await prefs.remove(kBgAuthToken);
}

/// Discards any not-yet-sent queued points. Call on logout only — a load
/// completing should NOT call this (see [clearBgActiveLoad]).
Future<void> clearBgPendingPoints() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kBgPendingPoints);
}
