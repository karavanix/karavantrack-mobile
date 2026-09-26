import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../tracking/tracker_core.dart';

// Android runner for the shared tracker (see tracker_core.dart). This file
// only decides WHERE tracking runs on Android — a separate isolate inside a
// foreground service, which keeps going after the app is swiped away. What
// gets tracked and how it's sent lives entirely in TrackerCore.
//
// iOS has no equivalent long-running service (flutter_background_service
// only offers a ~30 s background fetch there), so on iOS the tracker runs in
// the main isolate instead — see tracker_runner.dart.

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

  final tracker = TrackerCore(
    // No access to the UI isolate's ApiService from here.
    tokens: PrefsTokenSource(),
    liveStreamSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    ),
    onTick: () {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'KaravanTrack',
          content:
              'Tracking — ${DateTime.now().toLocal().toString().substring(11, 16)}',
        );
      }
    },
  );

  // Listen for stop signal from UI isolate
  service.on('stopService').listen((_) async {
    await tracker.stop();
    service.stopSelf();
  });
  service.on('flushNow').listen((_) => tracker.flushNow());

  tracker.start();
}

// ─── Public API (called from TrackerRunner) ─────────────────────────────────

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

/// Ask the running service to flush its queue now instead of on its next tick.
Future<void> flushBackgroundService() async {
  if (!Platform.isAndroid) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) service.invoke('flushNow');
}
