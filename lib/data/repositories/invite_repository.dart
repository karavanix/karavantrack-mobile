import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/invite.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../services/api/invites_api.dart';
import '../services/deep_link_service.dart';

/// A driver invite opened from a link, until it's accepted or dismissed.
class InviteRepository extends ChangeNotifier {
  InviteRepository({required this._api, required DeepLinkService links}) {
    _linksSub = links.links().listen(
      handleLink,
      onError: (Object e, StackTrace st) => log.error('Link stream', e, st),
    );
  }

  final InvitesApi _api;
  late final StreamSubscription<Uri> _linksSub;

  String? _token;
  bool _acceptAfterSignIn = false;
  String? _acceptedLoadId;

  /// The invite waiting to be dealt with.
  String? get token => _token;

  /// The driver chose "Log in & accept": the sign-in screens come first and
  /// the invite is accepted as soon as they're through.
  bool get acceptAfterSignIn => _acceptAfterSignIn;

  /// The load from the invite just accepted: leaving the invite screen goes
  /// straight to it.
  String? get acceptedLoadId => _acceptedLoadId;

  /// Takes the token from `yoollive://invite/{token}` (host `invite`) or
  /// `https://<web>/invite/{token}`; other links are ignored.
  void handleLink(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final token = switch (segments) {
      [final token, ...] when uri.host == 'invite' => token,
      ['invite', final token, ...] => token,
      _ => null,
    };
    if (token == null || token.isEmpty) return;
    _token = token;
    _acceptAfterSignIn = false;
    _acceptedLoadId = null;
    notifyListeners();
  }

  void requestSignIn() {
    _acceptAfterSignIn = true;
    notifyListeners();
  }

  void cancelSignIn() {
    _acceptAfterSignIn = false;
    notifyListeners();
  }

  Future<Result<Invite>> fetch() => _api.get(_token!);

  /// Ok with the id of the load the driver now has.
  Future<Result<String>> accept() async {
    final result = await _api.accept(_token!);
    if (result case Ok(:final value)) {
      _token = null;
      _acceptAfterSignIn = false;
      _acceptedLoadId = value;
      notifyListeners();
    }
    return result;
  }

  void clear() {
    if (_token == null && !_acceptAfterSignIn && _acceptedLoadId == null) {
      return;
    }
    _token = null;
    _acceptAfterSignIn = false;
    _acceptedLoadId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _linksSub.cancel();
    super.dispose();
  }
}
