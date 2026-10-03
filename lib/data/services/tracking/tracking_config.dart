import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../../../config/env.dart';

/// What the app hands the tracking library each time it configures it.
class TrackingSetup {
  const TrackingSetup({
    required this.accessToken,
    required this.refreshToken,
    required this.loadId,
    required this.texts,
  });

  final String? accessToken;
  final String? refreshToken;

  /// Stamped into every point as it's recorded, so points still queued
  /// when the load changes keep the load they were taken for.
  final String? loadId;

  final TrackingTexts texts;
}

/// The library's own UI: the Android notification that keeps the tracking
/// service alive, and its prompt for "Allow all the time".
class TrackingTexts {
  const TrackingTexts({
    required this.notificationTitle,
    required this.notificationText,
    required this.rationaleTitle,
    required this.rationaleMessage,
    required this.rationaleAllow,
    required this.rationaleCancel,
  });

  final String notificationTitle;
  final String notificationText;
  final String rationaleTitle;

  /// May use `{backgroundPermissionOptionLabel}`: the library puts in the
  /// system's own wording of "Allow all the time".
  final String rationaleMessage;
  final String rationaleAllow;
  final String rationaleCancel;
}

/// Where the points go: `POST /tracking/locations` (decision Q1 of the
/// rewrite), the library's own queue and HTTP client.
const trackingUrl = '${Env.apiPrefix}/tracking/locations';
const trackingRefreshUrl = '${Env.apiPrefix}/auth/refresh';

/// One point as the server reads it (`RegisterLocationsPoint`). load_id is
/// not here: the library adds the extras to every record itself, as it
/// does with `provider` on Android's providerchange records.
///
/// The library fails a record whose template names a variable it doesn't
/// have; `mock` is always there on Android (true/false) and present in the
/// iOS SDK, to be confirmed on an iPhone. Strings must be quoted here, the
/// library doesn't.
const locationTemplate =
    '{"uuid":"<%= uuid %>",'
    '"recorded_at":"<%= timestamp %>",'
    '"lat":<%= latitude %>,'
    '"lng":<%= longitude %>,'
    '"accuracy_m":<%= accuracy %>,'
    '"altitude_m":<%= altitude %>,'
    '"speed_mps":<%= speed %>,'
    '"heading_deg":<%= heading %>,'
    '"event":"<%= event %>",'
    '"is_moving":<%= is_moving %>,'
    '"activity_type":"<%= activity.type %>",'
    '"activity_confidence":<%= activity.confidence %>,'
    '"odometer_m":<%= odometer %>,'
    '"battery_level":<%= battery.level %>,'
    '"is_charging":<%= battery.is_charging %>,'
    '"is_mock":<%= mock %>}';

/// The production preset ("Рабочий" of the September test drives, with the
/// distance filter the drives settled on).
///
/// Passed whole to `ready()` on every launch and to `setConfig()` on every
/// change: `reset: true` puts back the library's default for anything left
/// out, so nothing set here survives by accident.
bg.Config trackingConfig(TrackingSetup setup) => bg.Config(
  reset: true,
  geolocation: bg.GeoConfig(
    desiredAccuracy: bg.DesiredAccuracy.high,
    // Elastic: the library scales it with speed, so a point comes about
    // every 10 s at any speed (50 m / 5 m/s); slower than 5 m/s, every 50 m.
    distanceFilter: 50,
    // Five minutes without motion and the library calls it a stop and
    // switches the GPS off until the phone moves again.
    stopTimeout: 5,
    filter: bg.LocationFilter(
      policy: bg.LocationFilterPolicy.adjust,
      trackingAccuracyThreshold: 50,
    ),
    // Our own flow asks for "Allow all the time" behind the disclosure, and
    // the loads screen explains what's missing. The library mustn't prompt
    // on its own or nag with its alert.
    locationAuthorizationRequest: 'Any',
    disableLocationAuthorizationAlert: true,
  ),
  activity: const bg.ActivityConfig(),
  app: bg.AppConfig(
    // Tracking outlives the app: swiped away, the library's service keeps
    // going (Android) or iOS relaunches the app in the background.
    stopOnTerminate: false,
    // An app update counts as a reboot: with false the library switches
    // tracking off by itself (seen on Honor, Android 14, 29.09).
    startOnBoot: true,
    // Android: the server's answer still reaches Dart with the app killed
    // (see headless.dart).
    enableHeadless: true,
    notification: bg.Notification(
      title: setup.texts.notificationTitle,
      text: setup.texts.notificationText,
      priority: bg.NotificationPriority.low,
    ),
    backgroundPermissionRationale: bg.PermissionRationale(
      title: setup.texts.rationaleTitle,
      message: setup.texts.rationaleMessage,
      positiveAction: setup.texts.rationaleAllow,
      negativeAction: setup.texts.rationaleCancel,
    ),
  ),
  http: bg.HttpConfig(
    url: trackingUrl,
    method: 'POST',
    autoSync: true,
    batchSync: true,
    // About a minute of driving per request; a stop or a start goes at
    // once (decision Q4).
    autoSyncThreshold: 6,
    maxBatchSize: 250,
    rootProperty: 'points',
  ),
  persistence: bg.PersistenceConfig(
    locationTemplate: locationTemplate,
    // A driver may be out of coverage for days; the server takes late
    // points of a load until it's confirmed.
    maxDaysToPersist: 14,
    persistMode: bg.PersistMode.location,
    extras: {'load_id': ?setup.loadId},
  ),
  authorization: bg.Authorization(
    strategy: bg.Authorization.STRATEGY_JWT,
    accessToken: setup.accessToken,
    refreshToken: setup.refreshToken,
    refreshUrl: trackingRefreshUrl,
    refreshPayload: {'refresh_token': '{refreshToken}'},
    // The library refreshes on a 401. It would read our expires_in (a
    // duration) as a point in time, so it gets no expiry at all.
    expires: -1,
  ),
  logger: bg.LoggerConfig(
    debug: false,
    logLevel: kDebugMode ? bg.LogLevel.verbose : bg.LogLevel.info,
    logMaxDays: 3,
  ),
);
