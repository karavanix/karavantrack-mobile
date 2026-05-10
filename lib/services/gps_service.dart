import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

typedef PositionCallback = void Function(Position position);

class GpsService {
  StreamSubscription<Position>? _positionStream;

  Future<void> startPositionStream(PositionCallback callback) async {
    // Permission must already be granted by LocationPermissionService before calling this.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      throw Exception('Always location permission not granted');
    }

    final LocationSettings settings;

    if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = AndroidSettings(
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

    _positionStream = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(callback);
  }

  Future<void> stopPositionStream() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
