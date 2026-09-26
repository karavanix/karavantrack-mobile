import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/gps_service.dart';
import 'tracker_core.dart';

/// Token source for the in-process (iOS) tracker: shares the UI's
/// ApiService, so there's one token pair and one refresh path.
class ApiTokenSource implements TrackerTokenSource {
  ApiTokenSource(this._api);

  final ApiService _api;

  @override
  Future<String?> fresh() async {
    final token = _api.accessToken;
    if (token == null || token.isEmpty) return null;
    if (!jwtExpiresSoon(token)) return token;
    return await refresh() ?? token;
  }

  @override
  Future<String?> refresh() async {
    final ok = await _api.refreshTokens().timeout(
      kTrackerHttpTimeout,
      onTimeout: () => false,
    );
    return ok ? _api.accessToken : null;
  }
}

/// Starts and stops the shared [TrackerCore] wherever this platform lets it
/// run. The tracking logic is the same everywhere; only the host differs:
///
/// - Android: the flutter_background_service isolate (background_service.dart),
///   a foreground service that survives the app being swiped away.
/// - iOS: this (main) isolate. iOS has no long-running background service;
///   the process stays alive in the background only while the position
///   stream in GpsService is running, and the tracker rides along with it.
///   Swiping the app away stops tracking on iOS — a known limitation,
///   handled separately.
class TrackerRunner {
  TrackerRunner._();

  static TrackerCore? _inProcess;

  static Future<void> start() async {
    if (Platform.isAndroid) {
      await startBackgroundService();
      return;
    }
    if (!Platform.isIOS) return;
    final tracker = _inProcess ??= TrackerCore(
      tokens: ApiTokenSource(ApiService.instance),
      liveStreamSettings: trackingStreamSettings(),
    );
    tracker.start();
  }

  static Future<void> stop() async {
    if (Platform.isAndroid) {
      await stopBackgroundService();
      return;
    }
    final tracker = _inProcess;
    _inProcess = null;
    await tracker?.stop();
  }

  /// Sends the queue now instead of on the next tick.
  static Future<void> flushNow() async {
    if (Platform.isAndroid) {
      await flushBackgroundService();
      return;
    }
    await _inProcess?.flushNow();
  }

  /// Queued (not yet delivered) points per load, for the UI's buffer counter.
  static Future<Map<String, int>> pendingCounts() async {
    final prefs = await SharedPreferences.getInstance();
    // On Android the queue is written by the service's isolate, so this
    // isolate's cached copy is stale until reloaded. On iOS the tracker
    // shares this very cache — reloading there could momentarily swap in
    // an older on-disk copy under the tracker's feet, so it's skipped.
    if (Platform.isAndroid) await prefs.reload();
    return pendingPointCounts(prefs);
  }
}
