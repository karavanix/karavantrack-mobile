import 'dart:async';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/loads_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../utils/logger.dart';
import '../models/location_state.dart';

/// When tracking runs, in one place. It runs while the driver has an
/// active load: from accepting it until the shipper confirms delivery,
/// "dropped off" included (the server takes points until then and shows
/// where the truck went after the drop-off).
///
/// - An active load: tracking follows it. Tracking that is off starts
///   only on the server's word, not for the copy saved on the device: it
///   may be off because the server stopped it in the background, the
///   load confirmed since.
/// - The server says there's no active load: tracking stops. A failed
///   fetch or an empty cache stops nothing: after a reboot the library
///   resumes on its own, and an app with no signal mustn't switch it off.
/// - The server's answer to a batch says "stop" (the load was confirmed,
///   cancelled, waits for confirmation too long): the library stops; the
///   loads are fetched again to see what happened. If there's still an
///   active load, tracking follows it again.
/// - Sign-out: SessionLifecycle sends what's queued and then resets.
///
/// Starting waits for the location prompts to be over and some access to
/// be granted: started without it, the library would ask on its own, over
/// our disclosure.
class TrackingLifecycle {
  TrackingLifecycle({
    required this._auth,
    required this._loads,
    required this._location,
    required this._tracking,
  });

  final AuthRepository _auth;
  final LoadsRepository _loads;
  final LocationRepository _location;
  final TrackingRepository _tracking;
  bool _signedIn = false;
  StreamSubscription<void>? _serverStops;

  void start() {
    _signedIn = _auth.isSignedIn;
    _auth.addListener(_onAuthChanged);
    _loads.addListener(_reconcile);
    _location.addListener(_reconcile);
    _serverStops = _tracking.serverStops.listen((_) {
      unawaited(_loads.refresh());
    });
    _reconcile();
  }

  void _onAuthChanged() {
    final signedIn = _auth.isSignedIn;
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    // A new session: the library's requests go with its tokens.
    if (signedIn) unawaited(_tracking.setTokens());
  }

  void _reconcile() {
    if (!_auth.isSignedIn) return;
    final load = _loads.active;
    if (load != null) {
      if (_tracking.enabled && _tracking.loadId == load.id) return;
      if (!_tracking.enabled && !_loads.activeKnown) return;
      if (!_canStart) return;
      unawaited(_tracking.follow(load.id));
    } else if (_loads.activeKnown && _tracking.enabled) {
      log.info('[tracking] no active load on the server');
      unawaited(_tracking.stop());
    }
  }

  bool get _canStart =>
      _location.promptsDone && _location.state.access != LocationAccess.denied;

  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _loads.removeListener(_reconcile);
    _location.removeListener(_reconcile);
    unawaited(_serverStops?.cancel());
  }
}
