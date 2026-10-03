import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../utils/logger.dart';

typedef PushMessage = ({String? title, String? body});

/// Push notifications (FCM).
abstract interface class PushService {
  /// Shows the system permission prompt if it hasn't been answered, then
  /// returns the device token; null when notifications are denied or the
  /// token isn't available yet (it then arrives on [tokenRefreshes]).
  Future<String?> requestToken();

  Stream<String> get tokenRefreshes;

  /// Messages that arrive while the app is in the foreground (the system
  /// doesn't show those itself).
  Stream<PushMessage> get foregroundMessages;

  /// Invalidates this device's token; the server drops it on the next send.
  Future<void> deleteToken();

  String get platform;
}

class FirebasePushService implements PushService {
  Future<FirebaseApp>? _app;

  Future<FirebaseMessaging> _messaging() async {
    await (_app ??= Firebase.initializeApp());
    return FirebaseMessaging.instance;
  }

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<String?> requestToken() async {
    final messaging = await _messaging();
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      log.info('[push] notifications denied');
      return null;
    }
    // On iOS the FCM token is derived from the APNs token, which arrives
    // some time after the permission; asking earlier throws.
    if (Platform.isIOS && await _waitForApnsToken(messaging) == null) {
      log.info('[push] no APNs token yet, waiting for onTokenRefresh');
      return null;
    }
    try {
      return await messaging.getToken();
    } catch (e, st) {
      log.error('[push] getToken failed', e, st);
      return null;
    }
  }

  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var i = 0; i < 30; i++) {
      final token = await messaging.getAPNSToken();
      if (token != null) return token;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  @override
  Stream<String> get tokenRefreshes async* {
    final messaging = await _messaging();
    yield* messaging.onTokenRefresh;
  }

  @override
  Stream<PushMessage> get foregroundMessages async* {
    await _messaging();
    yield* FirebaseMessaging.onMessage
        .where((m) => m.notification != null)
        .map((m) => (title: m.notification!.title, body: m.notification!.body));
  }

  @override
  Future<void> deleteToken() async {
    try {
      await (await _messaging()).deleteToken();
    } catch (e, st) {
      log.error('[push] deleteToken failed', e, st);
    }
  }
}
