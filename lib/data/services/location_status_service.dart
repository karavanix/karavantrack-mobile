import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
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

  /// Physical activity (Android) / Motion & Fitness (iOS): without it the
  /// library can't tell driving from standing and only wakes up once the
  /// phone is 150-200 m away from where it stopped. True if granted.
  Future<bool> requestMotion();

  /// The phone tells us the settings changed (GPS switched, access taken
  /// away in the settings); [read] has the new state.
  Stream<void> get changes;

  Future<void> openAppSettings();

  /// The system location toggle (Android); the app's settings on iOS,
  /// which has no way to open Location Services directly.
  Future<void> openLocationSettings();
}

/// [LocationStatusService] on the tracking library, which reports the
/// state of location access (precise or not, too) and when it changes;
/// the location prompts themselves go through permission_handler, whose
/// Android flow behind our disclosure was proven on 03.10.
///
/// Reads need the library's ready(), done in main before anything else.
class TrackingLocationStatusService implements LocationStatusService {
  static const _settings = MethodChannel('yool.live.app/settings');

  @override
  Future<LocationState> read() async {
    final p = await bg.BackgroundGeolocation.providerState;
    return LocationState(
      serviceEnabled: p.enabled,
      access: switch (p.status) {
        bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS =>
          LocationAccess.always,
        bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE =>
          LocationAccess.whileInUse,
        _ => LocationAccess.denied,
      },
      precise:
          p.accuracyAuthorization !=
          bg.ProviderChangeEvent.ACCURACY_AUTHORIZATION_REDUCED,
    );
  }

  @override
  Stream<void> get changes {
    // One subscription per listener; LocationRepository is the only one.
    late final StreamController<void> controller;
    bg.Subscription? sub;
    controller = StreamController<void>(
      onListen: () => sub = bg.BackgroundGeolocation.onProviderChange((e) {
        log.info('[location] provider change: $e');
        controller.add(null);
      }),
      onCancel: () => sub?.remove(),
    );
    return controller.stream;
  }

  @override
  Future<bool> requestMotion() async {
    try {
      final status = await bg.BackgroundGeolocation.requestPermission(
        bg.Permission.motion,
      );
      log.info('[location] motion request: $status');
      return true;
    } catch (status) {
      // The Future errors with the status on a refusal.
      log.info('[location] motion request refused: $status');
      return false;
    }
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
