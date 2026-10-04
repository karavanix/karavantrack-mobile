import 'dart:async';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/connectivity_repository.dart';
import '../../data/repositories/invite_repository.dart';
import '../../data/repositories/loads_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../data/services/api/account_api.dart';
import '../../data/services/app_lifecycle_service.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';

/// What happens when a session starts and ends, in one place. A session can
/// end from the settings screen or because the server rejected the refresh
/// token; either way AuthRepository reports it and the same cleanup runs.
///
/// While signed in it also keeps the loads fresh: they change on the
/// server (the shipper assigns or cancels one) without the app being told,
/// so they're fetched again whenever the driver is likely to look.
class SessionLifecycle {
  SessionLifecycle({
    required this._auth,
    required this._profile,
    required this._push,
    required this._invites,
    required this._account,
    required this._loads,
    required this._location,
    required this._connectivity,
    required this._lifecycle,
    required this._tracking,
  });

  final AuthRepository _auth;
  final ProfileRepository _profile;
  final PushRepository _push;
  final InviteRepository _invites;
  final AccountApi _account;
  final LoadsRepository _loads;
  final LocationRepository _location;
  final ConnectivityRepository _connectivity;
  final AppLifecycleService _lifecycle;
  final TrackingRepository _tracking;

  bool _signedIn = false;
  bool _online = true;
  String? _acceptedLoadId;
  final _subs = <StreamSubscription<Object?>>[];

  void start() {
    _auth.addListener(_onAuthChanged);
    _profile.addListener(_maybeRegisterPush);
    _location.addListener(_maybeRegisterPush);
    _invites.addListener(_onInvitesChanged);
    _connectivity.addListener(_onConnectivityChanged);
    _online = _connectivity.online;
    _subs
      ..add(_lifecycle.resumed.listen((_) => _refreshLoads()))
      ..add(
        _push.foregroundMessages.listen((m) {
          if (m.loadId case final id?) {
            unawaited(_loads.fetch(id));
            _refreshLoads();
          }
        }),
      );
    if (_auth.isSignedIn) {
      _signedIn = true;
      // The saved copies get the driver straight in; fresh ones follow.
      _profile.restore();
      _loads.restore();
      unawaited(_profile.refresh());
      _refreshLoads();
    }
  }

  void _onAuthChanged() {
    if (_auth.isSignedIn == _signedIn) return;
    _signedIn = _auth.isSignedIn;
    if (_signedIn) {
      unawaited(_profile.refresh());
      _refreshLoads();
    } else {
      unawaited(_ended());
    }
  }

  Future<void> _ended() async {
    log.info('[session] ended, clearing user data');
    _location.reset();
    await _tracking.reset();
    await _profile.clear();
    await _loads.clear();
    await _push.unregister();
  }

  /// Notifications are asked for once the driver is fully in (signed in
  /// with a profile) and past the location prompts, so the system prompt
  /// never lands on top of the sign-in screens or the location disclosure.
  void _maybeRegisterPush() {
    if (_signedIn &&
        (_profile.user?.isProfileComplete ?? false) &&
        _location.promptsDone) {
      unawaited(_push.register());
    }
  }

  /// An invite accepted: the load is now the driver's active one.
  void _onInvitesChanged() {
    final id = _invites.acceptedLoadId;
    if (id == null || id == _acceptedLoadId) return;
    _acceptedLoadId = id;
    unawaited(_loads.fetch(id));
    _refreshLoads();
  }

  void _onConnectivityChanged() {
    final online = _connectivity.online;
    if (online && !_online) _refreshLoads();
    _online = online;
  }

  void _refreshLoads() {
    if (_signedIn) unawaited(_loads.refresh());
  }

  Future<void> signOut() async {
    // Logout revokes the tracking library's tokens too: whatever it still
    // has queued goes now or never.
    await _tracking.flush();
    // Best effort: the server revokes the refresh token; offline, the
    // local sign-out still happens.
    await _account.logout().timeout(
      const Duration(seconds: 5),
      onTimeout: () => Result.error(TimeoutException('logout')),
    );
    _invites.clear();
    await _auth.signOut();
  }

  Future<Result<void>> deleteAccount() async {
    // The points belong to the load and stay with it on the server.
    await _tracking.flush();
    final result = await _account.delete();
    if (result is Ok<void>) {
      _invites.clear();
      await _auth.signOut();
    }
    return result;
  }

  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _profile.removeListener(_maybeRegisterPush);
    _location.removeListener(_maybeRegisterPush);
    _invites.removeListener(_onInvitesChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
  }
}
