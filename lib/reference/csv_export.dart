import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import 'reference_config.dart';

/// The Эталон's points as a gps-lab CSV, and what was left out of it.
class ReferenceCsv {
  const ReferenceCsv({
    required this.content,
    required this.rows,
    required this.samplesSkipped,
    required this.duplicatesMerged,
    required this.foreignSkipped,
  });

  final String content;
  final int rows;

  /// Interim samples the library takes before a motionchange.
  final int samplesSkipped;

  /// Records with the timestamp of the row before them.
  final int duplicatesMerged;

  /// Points that aren't the Эталон's: the production app's, left in the
  /// shared database.
  final int foreignSkipped;
}

/// gps-lab's `track.read_csv` reads columns by name: the first ten are
/// those of `export.sh` (the production database), the rest only the
/// library knows.
const referenceCsvHeader = [
  'point_id',
  'load_id',
  'lat',
  'lng',
  'accuracy_m',
  'speed_mps',
  'heading_deg',
  'recorded_at',
  'created_at',
  'load_status_history_id',
  'uuid',
  'preset',
  'event',
  'is_moving',
  'activity_type',
  'activity_confidence',
  'odometer_m',
  'age_s',
  'altitude_m',
  'speed_accuracy_mps',
  'heading_accuracy_deg',
  'battery_level',
  'is_charging',
  'mock',
];

/// [records] are the library's rows (`getLocations`), oldest first.
ReferenceCsv buildReferenceCsv(List<Object?> records) {
  var samples = 0, merged = 0, foreign = 0;
  final rows = <_Row>[];
  for (final record in records) {
    final l = bg.Location(record);
    if (l.extras?['preset'] != referenceExtras['preset']) {
      foreign++;
      continue;
    }
    if (l.sample) {
      samples++;
      continue;
    }
    final ts = l.timestamp.toString();
    // The motionchange point comes again as the first point of the stream,
    // and a providerchange is written with the same fix: one row, the
    // events joined with «+».
    if (rows.isNotEmpty && rows.last.timestamp == ts) {
      rows.last.addEvent(l.event);
      merged++;
      continue;
    }
    rows.add(_Row(l, ts));
  }

  final buf = StringBuffer()..writeln(referenceCsvHeader.join(','));
  for (var i = 0; i < rows.length; i++) {
    buf.writeln(rows[i].toCsv(i + 1));
  }
  return ReferenceCsv(
    content: buf.toString(),
    rows: rows.length,
    samplesSkipped: samples,
    duplicatesMerged: merged,
    foreignSkipped: foreign,
  );
}

/// `reference_<phone>_<yyyyMMdd-HHmm>`: gps-lab's runs.py takes the phone
/// from the second part, so the model loses its underscores.
String referenceFileName(String prefix, String model, DateTime at, String ext) {
  final phone = model.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-');
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}';
  return '${prefix}_${phone}_$stamp.$ext';
}

class _Row {
  _Row(this.l, this.timestamp) : events = [if (l.event.isNotEmpty) l.event];

  final bg.Location l;
  final String timestamp;
  final List<String> events;

  void addEvent(String e) {
    if (e.isNotEmpty && !events.contains(e)) events.add(e);
  }

  String toCsv(int pointId) {
    final c = l.coords;
    // -1 is the library's "unknown"; gps-lab reads an empty cell as that.
    String known(double v) => v < 0 ? '' : '$v';
    return [
      pointId,
      'reference',
      c.latitude,
      c.longitude,
      c.accuracy,
      known(c.speed),
      known(c.heading),
      timestamp,
      l.recordedAt,
      '',
      l.uuid,
      'reference',
      events.join('+'),
      l.isMoving ? 1 : 0,
      l.activity.type,
      l.activity.confidence,
      l.odometer,
      l.age,
      c.altitude,
      known(c.speedAccuracy),
      known(c.headingAccuracy),
      l.battery.level,
      l.battery.isCharging ? 1 : 0,
      l.mock ? 1 : 0,
    ].join(',');
  }
}
