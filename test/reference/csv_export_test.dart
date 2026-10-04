import 'package:driver_tracking_app/reference/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_reference_recorder.dart';

void main() {
  List<Map<String, String>> parse(String csv) {
    final lines = csv.trim().split('\n');
    final header = lines.first.split(',');
    return [
      for (final line in lines.skip(1))
        Map.fromIterables(header, line.split(',')),
    ];
  }

  test('gps-lab columns first, one row per fix', () {
    final csv = buildReferenceCsv([
      record(at: '2026-10-04T10:00:00.000Z', uuid: 'a'),
      record(at: '2026-10-04T10:00:01.000Z', uuid: 'b'),
    ]);

    expect(
      csv.content.split('\n').first,
      startsWith(
        'point_id,load_id,lat,lng,accuracy_m,speed_mps,heading_deg,'
        'recorded_at,created_at,load_status_history_id,',
      ),
    );
    final rows = parse(csv.content);
    expect(csv.rows, 2);
    expect(rows.map((r) => r['point_id']), ['1', '2']);
    expect(rows.first, containsPair('recorded_at', '2026-10-04T10:00:00.000Z'));
    expect(rows.first, containsPair('lat', '41.3'));
    expect(rows.first, containsPair('uuid', 'a'));
    expect(rows.first, containsPair('preset', 'reference'));
    expect(rows.first, containsPair('activity_type', 'in_vehicle'));
    expect(rows.first, containsPair('is_charging', '1'));
    expect(rows.first, containsPair('mock', '0'));
  });

  test('interim samples are left out', () {
    final csv = buildReferenceCsv([
      record(at: '2026-10-04T10:00:00.000Z', sample: true),
      record(at: '2026-10-04T10:00:01.000Z', sample: true),
      record(at: '2026-10-04T10:00:02.000Z', event: 'motionchange'),
    ]);

    expect(csv.rows, 1);
    expect(csv.samplesSkipped, 2);
  });

  test('records of one fix make one row with their events joined', () {
    // motionchange comes again as the first point of the stream, and a
    // providerchange is written with the same fix.
    final csv = buildReferenceCsv([
      record(at: '2026-10-04T10:00:00.000Z', event: 'motionchange'),
      record(at: '2026-10-04T10:00:00.000Z'),
      record(at: '2026-10-04T10:00:00.000Z', event: 'providerchange'),
      record(at: '2026-10-04T10:00:01.000Z'),
    ]);

    final rows = parse(csv.content);
    expect(csv.rows, 2);
    expect(csv.duplicatesMerged, 2);
    expect(rows.first['event'], 'motionchange+providerchange');
    expect(rows.last['event'], '');
  });

  test("the production app's points in the shared database are skipped", () {
    final production = record(at: '2026-10-04T09:00:00.000Z')
      ..['extras'] = {'load_id': 'L1'};
    final csv = buildReferenceCsv([
      production,
      record(at: '2026-10-04T09:30:00.000Z', preset: 'working'),
      record(at: '2026-10-04T10:00:00.000Z'),
    ]);

    expect(csv.rows, 1);
    expect(csv.foreignSkipped, 2);
  });

  test('unknown speed and heading (-1) are empty cells', () {
    final csv = buildReferenceCsv([
      record(at: '2026-10-04T10:00:00.000Z', speed: -1, heading: -1),
    ]);

    final row = parse(csv.content).single;
    expect(row['speed_mps'], '');
    expect(row['heading_deg'], '');
    expect(row['heading_accuracy_deg'], '');
    expect(row['speed_accuracy_mps'], '0.5');
  });

  test('nothing recorded: the header alone', () {
    final csv = buildReferenceCsv([]);

    expect(csv.rows, 0);
    expect(csv.content.trim().split('\n'), hasLength(1));
  });

  test("the file name keeps the phone where gps-lab's runs.py looks", () {
    final name = referenceFileName(
      'reference',
      'LLY_LX1 (Honor)',
      DateTime(2026, 10, 4, 9, 5),
      'csv',
    );

    expect(name, 'reference_LLY-LX1--Honor-_20261004-0905.csv');
    expect(name.split('_')[1], 'LLY-LX1--Honor-');
  });
}
