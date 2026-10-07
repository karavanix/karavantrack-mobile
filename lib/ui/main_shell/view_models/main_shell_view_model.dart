import 'dart:async';

import '../../../data/repositories/location_repository.dart';
import '../../../data/repositories/push_repository.dart';
import '../../../data/services/app_lifecycle_service.dart';

/// The signed-in app around its tabs. Reaching it is the first moment the
/// driver uses tracking, so this is where location access is asked for,
/// and kept an eye on while the app is in the foreground.
///
/// The notification prompt comes first and the location ones after it:
/// two system prompts at once would cover each other.
class MainShellViewModel {
  MainShellViewModel({
    required this._location,
    required this._push,
    required this._lifecycle,
  });

  final LocationRepository _location;
  final PushRepository _push;
  final AppLifecycleService _lifecycle;
  final _subs = <StreamSubscription<void>>[];
  Future<bool> Function()? _askConsent;

  /// [askConsent] shows the location disclosure; true for "Allow".
  Future<void> start(Future<bool> Function() askConsent) async {
    _subs
      ..add(_lifecycle.resumed.listen((_) => _onResumed()))
      ..add(_lifecycle.paused.listen((_) => _location.watch(false)));
    _location.watch(_lifecycle.isResumed);
    await _push.register();
    _askConsent = askConsent;
    await _location.requestAccess(askConsent);
  }

  /// The driver may have changed the settings while away. The flow itself
  /// pauses and resumes the app with every system prompt; it ignores the
  /// calls that come while it runs.
  void _onResumed() {
    _location.watch(true);
    // Not before start() gets to it: the notification prompt is still up.
    if (_askConsent case final askConsent?) {
      unawaited(_location.requestAccess(askConsent));
    }
  }

  void dispose() {
    _location.watch(false);
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
  }
}
