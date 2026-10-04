import 'dart:async';

import 'package:driver_tracking_app/reference/reference_recorder.dart';
import 'package:driver_tracking_app/reference/reference_view_model.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_test/flutter_test.dart';

import 'fake_reference_recorder.dart';

void main() {
  late FakeReferenceRecorder recorder;

  setUp(() => recorder = FakeReferenceRecorder());

  ReferenceViewModel open({bool recording = false}) {
    final vm = ReferenceViewModel(
      recorder: recorder,
      atLaunch: RecorderState(enabled: recording, isMoving: recording),
      clock: () => DateTime(2026, 10, 4, 12, 30),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('opens on what the library says at launch, counters read', () async {
    recorder.records.addAll([
      record(at: '2026-10-04T10:00:00.000Z'),
      record(at: '2026-10-04T10:00:01.000Z'),
    ]);
    final vm = open(recording: true);
    await settle();

    expect(vm.enabled, isTrue);
    expect(vm.storedCount, 2);
    expect(vm.provider?.gps, isTrue);
    expect(vm.ignoringBatteryOptimizations, isFalse);
    expect(vm.journal.single.text, 'ready: запись уже идёт');
  });

  test('start records moving at once, stop switches off', () async {
    final vm = open();

    await vm.start.execute();
    expect(vm.enabled, isTrue);
    expect(vm.isMoving, isTrue);

    await vm.stop.execute();
    expect(vm.enabled, isFalse);
    expect(vm.isMoving, isFalse);
    expect(recorder.calls, ['start', 'stop']);
  });

  test('a failed start lands in the journal, recording stays off', () async {
    recorder.failStart = true;
    final vm = open();

    await vm.start.execute();

    expect(vm.start.error, isTrue);
    expect(vm.enabled, isFalse);
    expect(vm.journal.first.text, contains('no permission'));
  });

  test('one action at a time', () async {
    recorder.startHeld = Completer();
    final vm = open();

    final starting = vm.start.execute();
    expect(vm.busy, isTrue);
    await vm.exportCsv.execute();
    expect(vm.busy, isTrue);
    recorder.startHeld!.complete();
    await starting;

    expect(vm.busy, isFalse);
    expect(recorder.shared, isEmpty);
  });

  test('CSV export shares the file and sums up what was left out', () async {
    recorder.records.addAll([
      record(at: '2026-10-04T10:00:00.000Z', sample: true),
      record(at: '2026-10-04T10:00:01.000Z', event: 'motionchange'),
      record(at: '2026-10-04T10:00:01.000Z'),
      record(at: '2026-10-04T10:00:02.000Z'),
      record(at: '2026-10-04T09:00:00.000Z')..['extras'] = {'load_id': 'L1'},
    ]);
    final vm = open();

    await vm.exportCsv.execute();

    final file = recorder.shared.single;
    expect(file.name, 'reference_LLY-LX1--Honor-_20261004-1230.csv');
    expect(file.mime, 'text/csv');
    expect(file.content.trim().split('\n'), hasLength(3));
    expect(
      vm.journal.first.text,
      'CSV ${file.name}: 2 строк; отброшено проб 1, дублей 1, чужих точек 1',
    );
  });

  test("the library's log goes out as text", () async {
    final vm = open();

    await vm.exportLog.execute();

    expect(
      recorder.shared.single.name,
      'bglog_LLY-LX1--Honor-_20261004-1230.txt',
    );
    expect(recorder.shared.single.content, 'the log');
  });

  test('deleting the points empties the database and the last point', () async {
    recorder.records.add(record(at: '2026-10-04T10:00:00.000Z'));
    final vm = open();
    recorder.emit(LocationRecorded(bg.Location(recorder.records.first)));
    await settle();

    await vm.destroyLocations.execute();

    expect(recorder.calls, ['destroy']);
    expect(vm.storedCount, 0);
    expect(vm.lastLocation, isNull);
  });

  test('each point shows the time since the one before', () async {
    final vm = open(recording: true);

    recorder.emit(
      LocationRecorded(bg.Location(record(at: '2026-10-04T10:00:00.000Z'))),
    );
    await settle();
    expect(vm.lastInterval, isNull);

    recorder.emit(
      LocationRecorded(bg.Location(record(at: '2026-10-04T10:00:01.200Z'))),
    );
    await settle();
    expect(vm.lastInterval, const Duration(milliseconds: 1200));
    expect(vm.lastLocation?.timestamp, '2026-10-04T10:00:01.200Z');
  });

  test('library events update the state and the journal', () async {
    final vm = open(recording: true);

    recorder
      ..emit(const MotionChanged(false))
      ..emit(const ActivityChanged('still', 75))
      ..emit(
        const ProviderChanged(
          ProviderStatus(
            gps: false,
            authorization: bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED,
          ),
        ),
      )
      ..emit(const EnabledChanged(false));
    await settle();

    expect(vm.isMoving, isFalse);
    expect(vm.activity, 'still');
    expect(vm.provider?.gps, isFalse);
    expect(vm.enabled, isFalse);
    expect(vm.journal.take(4).map((e) => e.text), [
      'запись выключена',
      'GPS выкл, разрешение: запрещено',
      'активность: стоит 75%',
      '■ стоим',
    ]);
  });

  test(
    "a phone without the power-manager screen gets the manual path",
    () async {
      recorder.noPowerManager = true;
      final vm = open();

      await vm.openPowerManager();

      expect(vm.journal.first.text, startsWith('экран не найден, вручную:'));
    },
  );
}
