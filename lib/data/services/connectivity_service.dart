import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network connection at all (not whether the
/// server is reachable through it).
class ConnectivityService {
  final _connectivity = Connectivity();

  /// The current state, then every change.
  Stream<bool> online() async* {
    yield _isOnline(await _connectivity.checkConnectivity());
    yield* _connectivity.onConnectivityChanged.map(_isOnline);
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
