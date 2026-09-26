import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

typedef PositionCallback = void Function(Position position);

/// Position-stream settings for the main isolate. Shared with the iOS
/// tracker's live mode on purpose: geolocator gives every subscriber in an
/// isolate the one stream created first, so both must ask for the same
/// thing — otherwise whichever subscribes first silently wins, and a plain
/// LocationSettings would lose background delivery on iOS.
LocationSettings trackingStreamSettings() {
  if (Platform.isIOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    );
  }
  return AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10,
    intervalDuration: const Duration(seconds: 10),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'Location tracking active',
      notificationTitle: 'KaravanTrack',
      enableWakeLock: true,
    ),
  );
}

/// Main-isolate position stream. It feeds the UI's "GPS" indicator on both
/// platforms, and on iOS it is also what keeps the process — and with it
/// the in-process tracker — alive while the app is in the background.
/// It records nothing itself; recording is TrackerCore's job.
class GpsService {
  StreamSubscription<Position>? _positionStream;

  Future<void> startPositionStream(PositionCallback callback) async {
    // Permission must already be granted by LocationPermissionService before calling this.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      throw Exception('Always location permission not granted');
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: trackingStreamSettings(),
    ).listen(callback);
  }

  Future<void> stopPositionStream() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
