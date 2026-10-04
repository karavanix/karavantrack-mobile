import 'dart:async';

import '../../../data/repositories/location_repository.dart';
import '../../../data/services/app_lifecycle_service.dart';

/// The signed-in app around its tabs. Reaching it is the first moment the
/// driver uses tracking, so this is where location access is asked for,
/// and kept an eye on while the app is in the foreground.
class MainShellViewModel {
  MainShellViewModel({required this._location, required this._lifecycle});

  final LocationRepository _location;
  final AppLifecycleService _lifecycle;
  final _subs = <StreamSubscription<void>>[];
  Future<bool> Function()? _askConsent;

  /// [askConsent] shows the location disclosure; true for "Allow".
  Future<void> start(Future<bool> Function() askConsent) async {
    _askConsent = askConsent;
    _subs
      ..add(_lifecycle.resumed.listen((_) => _onResumed()))
      ..add(_lifecycle.paused.listen((_) => _location.watch(false)));
    _location.watch(_lifecycle.isResumed);
    await _location.requestAccess(askConsent);
  }

  /// The driver may have changed the settings while away. The flow itself
  /// pauses and resumes the app with every system prompt; it ignores the
  /// calls that come while it runs.
  void _onResumed() {
    _location.watch(true);
    unawaited(_location.requestAccess(_askConsent!));
  }

  void dispose() {
    _location.watch(false);
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
  }
}
