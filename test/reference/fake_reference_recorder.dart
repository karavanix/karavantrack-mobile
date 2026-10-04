import 'dart:async';

import 'package:driver_tracking_app/reference/reference_recorder.dart';

/// A record of the library's database, as `getLocations` returns it.
Map<String, Object?> record({
  required String at,
  String preset = 'reference',
  String event = '',
  bool sample = false,
  double speed = 10,
  double heading = 90,
  bool moving = true,
  String uuid = 'u',
}) => {
  'uuid': uuid,
  'timestamp': at,
  'recorded_at': at,
  'event': event,
  'sample': sample,
  'is_moving': moving,
  'odometer': 120.5,
  'age': 0.4,
  'mock': false,
  'coords': {
    'latitude': 41.3,
    'longitude': 69.2,
    'accuracy': 4.5,
    'altitude': 450.0,
    'speed': speed,
    'heading': heading,
    'speed_accuracy': 0.5,
    'heading_accuracy': -1.0,
  },
  'battery': {'level': 0.8, 'is_charging': true},
  'activity': {'type': 'in_vehicle', 'confidence': 90},
  'extras': {'preset': preset},
};

/// The library on a fake phone: [records] is its database, [emit] plays
/// its events.
class FakeReferenceRecorder implements ReferenceRecorder {
  final records = <Object?>[];
  final calls = <String>[];
  final shared = <({String name, String content, String mime})>[];
  bool enabled = false;

  /// The next start() throws, as without a location permission.
  bool failStart = false;

  /// The phone has no power-manager screen (Honor).
  bool noPowerManager = false;

  /// While set, start() waits for it.
  Completer<void>? startHeld;

  final _events = StreamController<RecorderEvent>.broadcast();

  void emit(RecorderEvent event) => _events.add(event);

  @override
  Future<RecorderState> ready() async =>
      RecorderState(enabled: enabled, isMoving: enabled);

  @override
  Future<RecorderState> start() async {
    calls.add('start');
    if (startHeld case final held?) await held.future;
    if (failStart) throw Exception('no permission');
    enabled = true;
    return const RecorderState(enabled: true, isMoving: true);
  }

  @override
  Future<RecorderState> stop() async {
    calls.add('stop');
    enabled = false;
    return const RecorderState(enabled: false, isMoving: false);
  }

  @override
  Future<int> count() async => records.length;

  @override
  Future<List<Object?>> readAll() async => List.of(records);

  @override
  Future<void> destroyLocations() async {
    calls.add('destroy');
    records.clear();
  }

  @override
  Future<String> log() async => 'the log';

  @override
  Future<ProviderStatus> provider() async =>
      const ProviderStatus(gps: true, authorization: 3);

  @override
  Future<bool> ignoringBatteryOptimizations() async => false;

  @override
  Future<void> showBatteryOptimizations() async =>
      calls.add('battery settings');

  @override
  Future<void> showPowerManager() async {
    if (noPowerManager) throw Exception('Failed to find POWER_MANAGER screen');
    calls.add('power manager');
  }

  @override
  Future<String> deviceModel() async => 'LLY_LX1 (Honor)';

  @override
  Future<void> share(String fileName, String content, String mimeType) async =>
      shared.add((name: fileName, content: content, mime: mimeType));

  @override
  Stream<RecorderEvent> get events => _events.stream;
}
