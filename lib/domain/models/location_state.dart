enum LocationAccess { denied, whileInUse, always }

/// What stands in the way of tracking, most easily fixed first: when
/// several apply, the driver is shown the first.
enum LocationProblem {
  /// Location services are off on the phone: one system toggle.
  gpsOff,

  /// No "Allow all the time": tracking can't run in the background.
  noAlwaysAccess,

  /// Only approximate location: fixes come fuzzed by 1-3 km, which ruins
  /// the track without visibly breaking anything.
  notPrecise,
}

/// The phone's location settings as far as this app is concerned.
class LocationState {
  const LocationState({
    required this.serviceEnabled,
    required this.access,
    required this.precise,
  });

  /// Before the first check: nothing is reported as wrong, so the blocking
  /// overlay doesn't flash up for a driver whose settings are fine.
  static const assumedFine = LocationState(
    serviceEnabled: true,
    access: LocationAccess.always,
    precise: true,
  );

  final bool serviceEnabled;
  final LocationAccess access;
  final bool precise;

  LocationProblem? get problem {
    if (!serviceEnabled) return LocationProblem.gpsOff;
    if (access != LocationAccess.always) return LocationProblem.noAlwaysAccess;
    if (!precise) return LocationProblem.notPrecise;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LocationState &&
      other.serviceEnabled == serviceEnabled &&
      other.access == access &&
      other.precise == precise;

  @override
  int get hashCode => Object.hash(serviceEnabled, access, precise);

  @override
  String toString() =>
      'LocationState(service: $serviceEnabled, $access, precise: $precise)';
}
