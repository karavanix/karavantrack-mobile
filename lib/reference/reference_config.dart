import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

/// Marks every point of the Эталон in the library's database: the database
/// is shared with the production app (same applicationId), and the export
/// takes only these.
const referenceExtras = {'preset': 'reference'};

/// The Эталон: the raw GPS stream at 1 Hz, no filters, no stop detection.
/// The yardstick the production tracking is measured against on the second
/// phone. Nothing goes to the server; points stay in the library's SQLite
/// until exported to CSV.
///
/// Passed whole to `ready()` on every launch: `reset: true` puts back the
/// library's default for anything left out, including what the production
/// app may have set on this phone before.
bg.Config referenceConfig() => bg.Config(
  reset: true,
  isMoving: true,
  geolocation: bg.GeoConfig(
    desiredAccuracy: bg.DesiredAccuracy.high,
    // locationUpdateInterval is ignored unless this is 0.
    distanceFilter: 0,
    locationUpdateInterval: 1000,
    fastestLocationUpdateInterval: 1000,
    disableElasticity: true,
    // Otherwise Android drops a point equal to the previous one, and
    // while parked that's almost all of them.
    allowIdenticalLocations: true,
    filter: bg.LocationFilter(
      policy: bg.LocationFilterPolicy.passThrough,
      useKalman: false,
      trackingAccuracyThreshold: 0,
      odometerAccuracyThreshold: 0,
    ),
  ),
  // On Android: the GPS stays on until «Стоп».
  activity: const bg.ActivityConfig(disableStopDetection: true),
  app: bg.AppConfig(
    stopOnTerminate: false,
    // An app update counts as a reboot: with false the library switches
    // tracking off by itself (seen on Honor, Android 14, 29.09).
    startOnBoot: true,
    notification: bg.Notification(title: 'Эталон', text: 'Идёт запись точек'),
    backgroundPermissionRationale: bg.PermissionRationale(
      title: 'Разрешить доступ к геолокации в фоне?',
      message:
          'Для записи трека с выключенным экраном выберите '
          '«{backgroundPermissionOptionLabel}».',
      positiveAction: 'Выбрать «{backgroundPermissionOptionLabel}»',
      negativeAction: 'Отмена',
    ),
  ),
  http: bg.HttpConfig(autoSync: false),
  persistence: bg.PersistenceConfig(
    // The library's default is one day: a drive could be gone before
    // it's exported.
    maxDaysToPersist: 14,
    persistMode: bg.PersistMode.location,
    extras: referenceExtras,
  ),
  logger: const bg.LoggerConfig(logLevel: bg.LogLevel.verbose, logMaxDays: 7),
);
