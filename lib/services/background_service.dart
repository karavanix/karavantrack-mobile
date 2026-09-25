import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart' show kAuthTokenKey, kRefreshTokenKey;

// ─── SharedPreferences keys (shared between UI and background isolate) ─────
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

// ─── Service configuration ──────────────────────────────────────────────────

/// Initialize and configure the Android foreground service.
/// Call once in `main()` before `runApp()`.
Future<void> initBackgroundService() async {
  if (!Platform.isAndroid) return;
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'karavantrack_location',
      initialNotificationTitle: 'KaravanTrack',
      initialNotificationContent: 'Location tracking active',
      foregroundServiceNotificationId: 9001,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
  );
}

// ─── iOS background handler (required by API) ───────────────────────────────
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ─── Adaptive interval state (normal REST mode) ──────────────────────────────
// Speed threshold (m/s) above which the truck is considered moving (~5 km/h).
const double _kMovingThresholdMps = 1.5;
const Duration _kMovingInterval = Duration(minutes: 2);
const Duration _kStationaryInterval = Duration(minutes: 10);

DateTime? _lastSentAt;

// ─── Client-side jitter filtering ───────────────────────────────────────────
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

/// The last point actually kept (queued), used as the hysteresis anchor
/// while parked. Deliberately NOT updated on a point that gets filtered out,
/// so slow drift across many rejected fixes still gets caught once it
/// exceeds the threshold relative to the last real position.
Position? _lastKeptPosition;

double _distanceMeters(Position a, Position b) {
  const earthRadiusM = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(b.latitude - a.latitude);
  final dLng = toRad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(a.latitude)) *
          math.cos(toRad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

// ─── Live mode state (WebSocket fast mode) ──────────────────────────────────
WebSocketChannel? _wsChannel;
Timer? _liveTrackingWatchdog;
StreamSubscription<Position>? _liveGpsSubscription;

// Reconnect delay grows with each failed attempt, capped at 30 s.
int _wsReconnectDelaySec = 5;

// ─── Background isolate entry point ─────────────────────────────────────────
/// Runs in a separate Dart isolate — NO shared memory with the UI isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ⚠️  CRITICAL: call setAsForegroundService() immediately so Android does
  //  not kill the process before our timer even fires.
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  // Listen for stop signal from UI isolate
  service.on('stopService').listen((_) {
    _stopLiveMode();
    _wsChannel?.sink.close();
    service.stopSelf();
  });

  // Connect WebSocket to receive start/stop_live_location signals from backend.
  await _connectWs();

  // Check every minute; actual send rate adapts to movement (2 min moving, 10 min stationary).
  Timer.periodic(const Duration(minutes: 1), (_) => _tick(service));

  // Also send immediately on first start
  await _tick(service);
}

// ─── Token refresh (background isolate has no shared memory with the UI
// isolate's ApiService, so it keeps its own minimal refresh logic) ──────────
//
// Refresh tokens are NOT single-use server-side — RefreshTokenUsecase only
// checks a revocation cursor, not that the token hasn't been redeemed before
// — so this isolate and the UI isolate can both refresh independently
// without racing each other over the same refresh token.

/// Decodes a JWT's `exp` claim without verifying the signature. Safe here:
/// the token was already issued by our own server: this is only used to
/// decide *when* to proactively refresh, not to trust the token's claims.
DateTime? _jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'] as int?;
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// Redeems the refresh token and writes the new pair back to the keys both
/// isolates read, so the UI isolate picks up the refreshed tokens too.
Future<String?> _refreshAccessToken(SharedPreferences prefs) async {
  final refreshToken = prefs.getString(kRefreshTokenKey);
  if (refreshToken == null || refreshToken.isEmpty) return null;
  try {
    final response = await http.post(
      Uri.parse('$_kBaseUrl$_kBasePath/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
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

/// Returns a token good for at least 30 more seconds, refreshing first if
/// the stored one is missing, expired, or close to expiring.
Future<String?> _ensureFreshToken(SharedPreferences prefs) async {
  final token = prefs.getString(kBgAuthToken);
  if (token == null || token.isEmpty) return null;
  final expiry = _jwtExpiry(token);
  final staleSoon = expiry == null ||
      expiry.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)));
  if (!staleSoon) return token;
  return await _refreshAccessToken(prefs) ?? token;
}

// ─── WebSocket client ────────────────────────────────────────────────────────

Future<void> _connectWs() async {
  final prefs = await SharedPreferences.getInstance();
  final token = await _ensureFreshToken(prefs) ?? '';
  if (token.isEmpty) return;

  final wsUri = Uri.parse(
    '${_kBaseUrl.replaceAll('https://', 'wss://').replaceAll('http://', 'ws://')}$_kBasePath/ws?token=$token',
  );

  try {
    _wsChannel = WebSocketChannel.connect(wsUri);
    _wsReconnectDelaySec = 5; // reset backoff on success
    _wsChannel!.stream.listen(
      _onWsMessage,
      onDone: _scheduleWsReconnect,
      onError: (_) => _scheduleWsReconnect(),
      cancelOnError: true,
    );
  } catch (_) {
    _scheduleWsReconnect();
  }
}

void _scheduleWsReconnect() {
  Future.delayed(Duration(seconds: _wsReconnectDelaySec), _connectWs);
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

// ─── Live mode (WebSocket GPS stream) ───────────────────────────────────────

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
  // reverts to normal REST mode automatically.
  _liveTrackingWatchdog?.cancel();
  _liveTrackingWatchdog = Timer(const Duration(minutes: 5), _stopLiveMode);

  // Subscribe to the position stream and forward each fix over the WebSocket.
  _liveGpsSubscription?.cancel();
  _liveGpsSubscription = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    ),
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
  _liveGpsSubscription?.cancel();
  _liveGpsSubscription = null;
}

Future<void> _sendLiveAckViaWs(String status, {String? reason}) async {
  if (_wsChannel == null) return;

  final prefs = await SharedPreferences.getInstance();
  final loadId = prefs.getString(kBgActiveLoadId) ?? '';
  if (loadId.isEmpty) return;

  try {
    _wsChannel!.sink.add(jsonEncode({
      'event': 'live_location_ack',
      'data': {
        'load_id': loadId,
        'status': status,
        'reason': ?reason,
      },
    }));
  } catch (_) {}
}

Future<void> _sendPositionViaWs(Position pos) async {
  if (_wsChannel == null) return;

  final prefs = await SharedPreferences.getInstance();
  final loadId = prefs.getString(kBgActiveLoadId) ?? '';
  if (loadId.isEmpty) return;

  try {
    _wsChannel!.sink.add(jsonEncode({
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
    }));
  } catch (_) {}
}

// ─── Normal REST tick — queue-and-flush ─────────────────────────────────────
// Every fix is written to a local queue before it's ever sent, and each tick
// tries to flush that queue via the batch endpoint. A point that fails to
// send (no signal, server hiccup) simply stays queued and goes out with the
// next successful flush, with its original recorded_at — instead of being
// dropped, which is what happened before.

Future<void> _tick(ServiceInstance service) async {
  // Update notification timestamp
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'KaravanTrack',
      content:
          'Tracking — ${DateTime.now().toLocal().toString().substring(11, 16)}',
    );
  }

  // Read context written by UI isolate via SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final loadId = prefs.getString(kBgActiveLoadId);

  if (loadId == null || loadId.isEmpty) return;

  final token = await _ensureFreshToken(prefs);
  if (token == null || token.isEmpty) return;

  // Always attempt to drain whatever is already queued, regardless of the
  // movement interval below — this is what lets a backlog built up while
  // offline empty out as soon as connectivity returns. Queued points carry
  // their own load_id (see _enqueuePoint), so this also flushes anything
  // stranded from a load that has since completed and is no longer active.
  await _flushQueue(prefs: prefs, token: token);

  // Verify GPS is available
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
      ),
    );

    // A fix this imprecise is more likely noise than a real position —
    // skip it rather than record it and retry next tick.
    if (pos.accuracy > _kMaxAcceptableAccuracyM) return;

    final isMoving = (pos.speed) > _kMovingThresholdMps;
    final requiredInterval = isMoving ? _kMovingInterval : _kStationaryInterval;
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

List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
  final raw = prefs.getString(kBgPendingPoints);
  if (raw == null || raw.isEmpty) return [];
  try {
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
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

/// Posts everything currently queued via the batch endpoint, one request per
/// load_id (a queue can span more than one load if it wasn't fully drained
/// before the driver moved on to the next). Points are matched by their
/// local `_qid` when removing sent ones from the persisted queue afterwards,
/// so a point enqueued while a request is in flight is never lost even if
/// it races with this flush.
Future<bool> _flushQueue({
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
        .map((p) => {
              'lat': p['lat'],
              'lng': p['lng'],
              'speed_mps': p['speed_mps'],
              'accuracy_m': p['accuracy_m'],
              'heading_deg': p['heading_deg'],
              'recorded_at': p['recorded_at'],
            })
        .toList();
    final body = jsonEncode({'points': wirePoints});
    final uri = Uri.parse(
      '$_kBaseUrl$_kBasePath/loads/${entry.key}/location/batch',
    );

    bool ok;
    try {
      var response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
        body: body,
      );
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken(prefs);
        if (refreshed != null) {
          currentToken = refreshed;
          response = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
            body: body,
          );
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
    final remaining =
        current.where((p) => !sentQids.contains(p['_qid'])).toList();
    if (remaining.isEmpty) {
      await prefs.remove(kBgPendingPoints);
    } else {
      await prefs.setString(kBgPendingPoints, jsonEncode(remaining));
    }
  }

  return allOk;
}

// ─── Public API (called from UI isolate / AppStore) ─────────────────────────

/// Start the foreground location service.
Future<void> startBackgroundService() async {
  if (!Platform.isAndroid) return;
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) await service.startService();
}

/// Stop the foreground location service.
Future<void> stopBackgroundService() async {
  if (!Platform.isAndroid) return;
  final service = FlutterBackgroundService();
  service.invoke('stopService');
}

/// Write active-load context so the background isolate can pick it up.
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
/// flushed once the driver's next load starts the service again. Call
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
