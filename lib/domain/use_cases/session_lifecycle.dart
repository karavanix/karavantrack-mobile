import 'dart:async';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/invite_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../data/services/api/account_api.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';

/// What happens when a session starts and ends, in one place. A session can
/// end from the settings screen or because the server rejected the refresh
/// token; either way AuthRepository reports it and the same cleanup runs.
class SessionLifecycle {
  SessionLifecycle({
    required this._auth,
    required this._profile,
    required this._push,
    required this._invites,
    required this._account,
  });

  final AuthRepository _auth;
  final ProfileRepository _profile;
  final PushRepository _push;
  final InviteRepository _invites;
  final AccountApi _account;

  bool _signedIn = false;

  void start() {
    _auth.addListener(_onAuthChanged);
    _profile.addListener(_onProfileChanged);
    if (_auth.isSignedIn) {
      _signedIn = true;
      // The saved copy gets the driver straight in; the fresh one follows.
      _profile.restore();
      unawaited(_profile.refresh());
    }
  }

  void _onAuthChanged() {
    if (_auth.isSignedIn == _signedIn) return;
    _signedIn = _auth.isSignedIn;
    if (_signedIn) {
      unawaited(_profile.refresh());
    } else {
      unawaited(_ended());
    }
  }

  Future<void> _ended() async {
    log.info('[session] ended, clearing user data');
    await _profile.clear();
    await _push.unregister();
  }

  /// Notifications are asked for once the driver is fully in: signed in
  /// with a profile. Not earlier, so the system prompt never lands on top
  /// of the sign-in screens.
  void _onProfileChanged() {
    if (_signedIn && (_profile.user?.isProfileComplete ?? false)) {
      unawaited(_push.register());
    }
  }

  Future<void> signOut() async {
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
    final result = await _account.delete();
    if (result is Ok<void>) {
      _invites.clear();
      await _auth.signOut();
    }
    return result;
  }
}
