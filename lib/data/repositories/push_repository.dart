import 'dart:async';
import 'dart:math';

import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../services/api/account_api.dart';
import '../services/local_store.dart';
import '../services/push_service.dart';

/// This device's push registration with the server.
class PushRepository {
  PushRepository({
    required this._push,
    required this._api,
    required this._store,
  });

  final PushService _push;
  final AccountApi _api;
  final LocalStore _store;

  StreamSubscription<String>? _refreshSub;
  bool _registered = false;

  /// The token sent (or being sent) to the server. A token FCM creates
  /// comes both from requestToken and on onTokenRefresh, at the same time;
  /// it's sent once.
  String? _sent;

  Stream<PushMessage> get foregroundMessages => _push.foregroundMessages;

  Stream<String> get openedLoadIds => _push.openedLoadIds;

  /// Asks for the notification permission (the system prompt, the first
  /// time) and sends the token to the server; later token changes follow
  /// on their own. Safe to call again.
  Future<void> register() async {
    if (_registered) return;
    _registered = true;
    _refreshSub ??= _push.tokenRefreshes.listen(_send);
    final token = await _push.requestToken();
    if (token != null) await _send(token);
  }

  /// Signed out: the token is invalidated so this phone stops getting the
  /// previous user's notifications.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (!_registered) return;
    _registered = false;
    _sent = null;
    await _push.deleteToken();
  }

  Future<void> _send(String token) async {
    if (token == _sent) return;
    _sent = token;
    final result = await _api.registerDevice(
      deviceId: _deviceId(),
      token: token,
      platform: _push.platform,
    );
    log.info('[push] device registration: $result');
    // Not sent: the next time the token comes, it's tried again.
    if (result is Error<void> && _sent == token) _sent = null;
  }

  /// A stable id for this install; the server keys tokens by it.
  String _deviceId() {
    final saved = _store.getString(StoreKeys.pushDeviceId);
    if (saved != null) return saved;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _store.setString(StoreKeys.pushDeviceId, id);
    return id;
  }
}
