import 'dart:async';
import 'package:geolocator/geolocator.dart';

typedef PositionCallback = void Function(Position position);

/// Wrapper around the Geolocator plugin for requesting permissions
/// and streaming GPS positions.
class GpsService {
  StreamSubscription<Position>? _positionStream;

  bool _isAccessGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (_isAccessGranted(permission)) return true;
    permission = await Geolocator.requestPermission();
    return _isAccessGranted(permission);
  }

  Future<void> startPositionStream(PositionCallback callback) async {
    final granted = await requestPermission();
    if (!granted) throw Exception('Location permission not granted');

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen(callback);
  }

  Future<void> stopPositionStream() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
