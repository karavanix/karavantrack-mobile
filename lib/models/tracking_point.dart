/// A single GPS fix recorded for a load.
class TrackingPoint {
  TrackingPoint({
    required this.timestampUtc,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.accuracyM,
    this.headingDeg,
  });

  final DateTime timestampUtc;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double accuracyM;
  final double? headingDeg;

  double get speedMps => speedKmh / 3.6;
}
