/// Where the phone is, as one GPS fix. Sent with a status change, it marks
/// the step on the load's map.
class Fix {
  const Fix({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
  });

  final double lat;
  final double lng;
  final DateTime recordedAt;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;

  /// The `location` of a status change (the server's `LocationInput`).
  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'accuracy_m': ?accuracyM,
    'speed_mps': ?speedMps,
    'heading_deg': ?headingDeg,
  };
}
