import 'package:flutter/foundation.dart';

import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../services/api/api_exception.dart';
import '../services/api/auth_api.dart';
import '../services/api/auth_interceptor.dart';
import '../services/api/models/token_pair.dart';
import '../services/local_store.dart';

/// The only owner of the session tokens. Signed in means a refresh token is
/// stored; listeners (the router) are notified when that changes.
class AuthRepository extends ChangeNotifier implements TokenSource {
  AuthRepository({required this._api, required this._store})
    : _accessToken = _store.getString(StoreKeys.accessToken),
      _refreshToken = _store.getString(StoreKeys.refreshToken);

  final AuthApi _api;
  final LocalStore _store;

  String? _accessToken;
  String? _refreshToken;
  Future<Result<String>>? _refreshing;

  bool get isSignedIn => _refreshToken != null;

  @override
  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  /// Stores the tokens from a successful sign-in.
  Future<void> signIn(TokenPair tokens) async {
    await _save(tokens);
    notifyListeners();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.remove(StoreKeys.accessToken);
    await _store.remove(StoreKeys.refreshToken);
    notifyListeners();
  }

  /// Concurrent callers share one request: the HTTP interceptor and, later,
  /// the tracking library can both ask at the same moment.
  @override
  Future<Result<String>> refreshAccessToken() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Result<String>> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      return const Result.error(UnauthorizedException());
    }
    switch (await _api.refresh(refreshToken)) {
      case Ok(:final value):
        // Signed out while the request was in flight: don't resurrect.
        if (_refreshToken != refreshToken) {
          return const Result.error(UnauthorizedException());
        }
        await _save(value);
        return Result.ok(value.accessToken);
      case Error(error: HttpException(isClientError: true) && final error):
        log.warning('Refresh token rejected (${error.statusCode}), signing out');
        await signOut();
        return const Result.error(UnauthorizedException());
      case Error(:final error):
        return Result.error(error);
    }
  }

  Future<void> _save(TokenPair tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _store.setString(StoreKeys.accessToken, tokens.accessToken);
    await _store.setString(StoreKeys.refreshToken, tokens.refreshToken);
  }
}
