import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences keys (shared between UI and background isolate) ─────
const String kBgActiveLoadId = 'bg_active_load_id';
const String kBgCarrierId = 'bg_carrier_id';
const String kBgAuthToken = 'bg_auth_token';

const String _kBaseUrl = 'https://api.yool.live';
const String _kBasePath = '/api/v1';

// ─── Service configuration ──────────────────────────────────────────────────

/// Initialize and configure the Android foreground service.
/// Call once in `main()` before `runApp()`.
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
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
  service.on('stopService').listen((_) => service.stopSelf());

  // Send GPS every 10 minutes
  Timer.periodic(const Duration(minutes: 10), (_) => _tick(service));

  // Also send immediately on first start
  await _tick(service);
}

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
  final carrierId = prefs.getString(kBgCarrierId);
  final token = prefs.getString(kBgAuthToken);

  if (loadId == null || loadId.isEmpty) return;
  if (token == null || token.isEmpty) return;

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

    await _postLocation(
      token: token,
      loadId: loadId,
      carrierId: carrierId ?? '',
      pos: pos,
    );
  } catch (_) {
    // Silently skip — will retry on next tick
  }
}

Future<void> _postLocation({
  required String token,
  required String loadId,
  required String carrierId,
  required Position pos,
}) async {
  try {
    await http.post(
      Uri.parse('$_kBaseUrl$_kBasePath/loads/$loadId/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'load_id': loadId,
        'carrier_id': carrierId,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed_mps': pos.speed,
        'accuracy_m': pos.accuracy,
        'heading_deg': pos.heading,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  } catch (_) {}
}

// ─── Public API (called from UI isolate / AppStore) ─────────────────────────

/// Start the foreground location service.
Future<void> startBackgroundService() async {
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) await service.startService();
}

/// Stop the foreground location service.
Future<void> stopBackgroundService() async {
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
Future<void> clearBgActiveLoad() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kBgActiveLoadId);
  await prefs.remove(kBgCarrierId);
  await prefs.remove(kBgAuthToken);
}
