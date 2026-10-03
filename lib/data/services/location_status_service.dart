import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/models/location_state.dart';
import '../../utils/logger.dart';

/// The phone's location settings: reading them, asking for access, and
/// sending the driver to the system settings.
abstract interface class LocationStatusService {
  Future<LocationState> read();

  /// The system "while using the app" prompt.
  Future<void> requestWhileInUse();

  /// The upgrade to "all the time". Needs "while using" first.
  Future<void> requestAlways();

  Future<void> openAppSettings();

  /// The system location toggle (Android); the app's settings on iOS,
  /// which has no way to open Location Services directly.
  Future<void> openLocationSettings();
}

/// [LocationStatusService] on permission_handler.
///
/// permission_handler can't tell precise from approximate location, so
/// [read] reports it as precise for now. The tracking library (step 6)
/// reports the accuracy itself and replaces this implementation.
class PermissionHandlerLocationStatusService implements LocationStatusService {
  static const _settings = MethodChannel('yool.live.app/settings');

  @override
  Future<LocationState> read() async {
    final (service, always, whileInUse) = await (
      ph.Permission.location.serviceStatus,
      ph.Permission.locationAlways.status,
      ph.Permission.locationWhenInUse.status,
    ).wait;
    return LocationState(
      serviceEnabled: service.isEnabled,
      access: always.isGranted
          ? LocationAccess.always
          : whileInUse.isGranted
          ? LocationAccess.whileInUse
          : LocationAccess.denied,
      precise: true,
    );
  }

  @override
  Future<void> requestWhileInUse() async {
    final status = await ph.Permission.locationWhenInUse.request();
    log.info('[location] while-in-use request: $status');
  }

  @override
  Future<void> requestAlways() async {
    // iOS may silently ignore a second prompt that comes right after the
    // first one.
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // On Android 10+ the background permission has to be asked for on its
    // own: bundled with FINE/COARSE, Android 11+ drops the whole request
    // without showing anything. Alone, it opens the app's location page
    // with "Allow all the time".
    final status = await ph.Permission.locationAlways.request();
    log.info('[location] always request: $status');
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    if (!Platform.isAndroid) return openAppSettings();
    try {
      await _settings.invokeMethod<void>('openLocationSettings');
    } on PlatformException catch (e, st) {
      log.error('Opening location settings failed', e, st);
      await openAppSettings();
    }
  }
}
