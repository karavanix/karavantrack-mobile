import 'dart:async';
import 'dart:convert';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:share_plus/share_plus.dart';

import 'reference_config.dart';

/// What the library reports while the Эталон records.
sealed class RecorderEvent {
  const RecorderEvent();
}

/// A point recorded (interim samples are not passed on).
class LocationRecorded extends RecorderEvent {
  const LocationRecorded(this.location);
  final bg.Location location;
}

class LocationFailed extends RecorderEvent {
  const LocationFailed(this.message);
  final String message;
}

class MotionChanged extends RecorderEvent {
  const MotionChanged(this.moving);
  final bool moving;
}

class ActivityChanged extends RecorderEvent {
  const ActivityChanged(this.type, this.confidence);
  final String type;
  final int confidence;
}

class ProviderChanged extends RecorderEvent {
  const ProviderChanged(this.provider);
  final ProviderStatus provider;
}

class EnabledChanged extends RecorderEvent {
  const EnabledChanged(this.enabled);
  final bool enabled;
}

class ProviderStatus {
  const ProviderStatus({required this.gps, required this.authorization});

  final bool gps;

  /// One of `bg.ProviderChangeEvent.AUTHORIZATION_STATUS_*`.
  final int authorization;
}

class RecorderState {
  const RecorderState({
    required this.enabled,
    required this.isMoving,
    this.launchedInBackground = false,
  });

  final bool enabled;
  final bool isMoving;
  final bool launchedInBackground;
}

/// The tracking library as the Эталон uses it: records on the phone,
/// never sends. No state here; the view model keeps it.
abstract interface class ReferenceRecorder {
  /// Once per launch, before runApp, also when the OS starts the app in
  /// the background to resume recording.
  Future<RecorderState> ready();

  /// Starts recording, moving at once: otherwise the library starts as
  /// parked and the beginning of the drive is lost.
  Future<RecorderState> start();

  Future<RecorderState> stop();

  /// Points in the library's database, the production app's included.
  Future<int> count();

  /// Every record in the database, oldest first.
  Future<List<Object?>> readAll();

  Future<void> destroyLocations();

  /// The library's own log from its SQLite: on some phones (Honor) the
  /// system logcat is off, and there's no other way to see what happened
  /// in the background.
  Future<String> log();

  Future<ProviderStatus> provider();

  /// Android; always true on iOS.
  Future<bool> ignoringBatteryOptimizations();

  /// Throw when the phone has no such screen.
  Future<void> showBatteryOptimizations();
  Future<void> showPowerManager();

  Future<String> deviceModel();

  /// Through the system share sheet.
  Future<void> share(String fileName, String content, String mimeType);

  Stream<RecorderEvent> get events;
}

/// [ReferenceRecorder] on flutter_background_geolocation.
class BgReferenceRecorder implements ReferenceRecorder {
  static const _pageSize = 1000;

  final _events = StreamController<RecorderEvent>.broadcast();

  @override
  Future<RecorderState> ready() async {
    bg.BackgroundGeolocation.onLocation((l) {
      if (!l.sample) _events.add(LocationRecorded(l));
    }, (e) => _events.add(LocationFailed('${e.code}: ${e.message}')));
    bg.BackgroundGeolocation.onMotionChange(
      (l) => _events.add(MotionChanged(l.isMoving)),
    );
    bg.BackgroundGeolocation.onActivityChange(
      (e) => _events.add(ActivityChanged(e.activity, e.confidence)),
    );
    bg.BackgroundGeolocation.onProviderChange(
      (e) => _events.add(ProviderChanged(_provider(e))),
    );
    bg.BackgroundGeolocation.onEnabledChange(
      (on) => _events.add(EnabledChanged(on)),
    );
    final state = await bg.BackgroundGeolocation.ready(referenceConfig());
    return RecorderState(
      enabled: state.enabled,
      isMoving: state.isMoving ?? false,
      launchedInBackground: state.didLaunchInBackground,
    );
  }

  @override
  Future<RecorderState> start() async {
    final started = await bg.BackgroundGeolocation.start();
    final moving = await bg.BackgroundGeolocation.changePace(true);
    return RecorderState(
      enabled: started.enabled,
      isMoving: moving.isMoving ?? true,
    );
  }

  @override
  Future<RecorderState> stop() async {
    final state = await bg.BackgroundGeolocation.stop();
    return RecorderState(enabled: state.enabled, isMoving: false);
  }

  @override
  Future<int> count() => bg.BackgroundGeolocation.count;

  @override
  Future<List<Object?>> readAll() async {
    final out = <Object?>[];
    for (var offset = 0; ; offset += _pageSize) {
      final page = await bg.BackgroundGeolocation.getLocations(
        bg.LocationQuery(
          limit: _pageSize,
          offset: offset,
          order: bg.LocationQuery.ORDER_ASC,
        ),
      );
      out.addAll(page);
      if (page.length < _pageSize) return out;
    }
  }

  @override
  Future<void> destroyLocations() =>
      bg.BackgroundGeolocation.destroyLocations();

  @override
  Future<String> log() => bg.Logger.getLog();

  @override
  Future<ProviderStatus> provider() async =>
      _provider(await bg.BackgroundGeolocation.providerState);

  @override
  Future<bool> ignoringBatteryOptimizations() =>
      bg.DeviceSettings.isIgnoringBatteryOptimizations;

  @override
  Future<void> showBatteryOptimizations() async => bg.DeviceSettings.show(
    await bg.DeviceSettings.showIgnoreBatteryOptimizations(),
  );

  @override
  Future<void> showPowerManager() async =>
      bg.DeviceSettings.show(await bg.DeviceSettings.showPowerManager());

  @override
  Future<String> deviceModel() async =>
      (await bg.DeviceInfo.getInstance()).model;

  @override
  Future<void> share(String fileName, String content, String mimeType) =>
      SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(content),
              mimeType: mimeType,
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          subject: fileName,
        ),
      );

  @override
  Stream<RecorderEvent> get events => _events.stream;

  static ProviderStatus _provider(bg.ProviderChangeEvent e) =>
      ProviderStatus(gps: e.gps, authorization: e.status);
}
