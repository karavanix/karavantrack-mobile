import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/invite_repository.dart';
import '../../../data/services/api/api_exception.dart';
import '../../../domain/models/invite.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

sealed class InviteState {
  const InviteState();
}

final class InviteLoading extends InviteState {
  const InviteLoading();
}

/// The link points nowhere (unknown token).
final class InviteNotFound extends InviteState {
  const InviteNotFound();
}

/// Couldn't fetch it (network, server).
final class InviteFailed extends InviteState {
  const InviteFailed(this.error);

  final Exception error;
}

/// The driver already has an active load and can't take another.
final class InviteBlockedByActiveLoad extends InviteState {
  const InviteBlockedByActiveLoad();
}

final class InviteReady extends InviteState {
  const InviteReady(this.invite);

  final Invite invite;
}

/// The offer behind an invite link, and accepting it.
class InviteViewModel extends ChangeNotifier {
  InviteViewModel({required this._invites, required this._auth}) {
    accept = Command0(_accept);
    load = Command0(_load)..execute();
  }

  final InviteRepository _invites;
  final AuthRepository _auth;
  late final Command0<void> load;
  late final Command0<void> accept;

  InviteState _state = const InviteLoading();

  InviteState get state => _state;

  bool get signedIn => _auth.isSignedIn;

  /// Accepting on its own, with no button pressed: shown as a spinner.
  bool get autoAccepting =>
      accept.running && _state is InviteReady && _shouldAutoAccept;

  bool get _shouldAutoAccept => switch (_state) {
    InviteReady(:final invite) when signedIn => switch (invite.status) {
      // The driver chose "Log in & accept" and is now signed in.
      InviteStatus.pending => _invites.acceptAfterSignIn,
      // Reopening one's own accepted link continues to the load; the
      // server accepts it again idempotently.
      InviteStatus.accepted => invite.acceptedByMe,
      _ => false,
    },
    _ => false,
  };

  /// Back to the normal app without this invite.
  void dismiss() => _invites.clear();

  Future<Result<void>> _load() async {
    _setState(const InviteLoading());
    switch (await _invites.fetch()) {
      case Ok(:final value):
        _setState(InviteReady(value));
        if (_shouldAutoAccept) await accept.execute();
        return const Result.ok(null);
      case Error(error: HttpException(statusCode: 404)):
        _setState(const InviteNotFound());
        return const Result.ok(null);
      case Error(:final error):
        _setState(InviteFailed(error));
        return Result.error(error);
    }
  }

  Future<Result<void>> _accept() async {
    if (!signedIn) {
      _invites.requestSignIn();
      return const Result.ok(null);
    }
    switch (await _invites.accept()) {
      case Ok():
        // The router takes it from here (to the load).
        return const Result.ok(null);
      case Error(error: HttpException(code: 'CARRIER_HAS_ACTIVE_LOAD')):
        _setState(const InviteBlockedByActiveLoad());
        return const Result.ok(null);
      case Error(:final error):
        // Most likely someone else took it meanwhile: show the fresh state.
        await _load();
        return Result.error(error);
    }
  }

  void _setState(InviteState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    load.dispose();
    accept.dispose();
    super.dispose();
  }
}
