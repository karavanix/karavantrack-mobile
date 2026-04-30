import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'debug_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _kDeviceIdKey = 'fcm_device_id';

  bool _initialized = false;
  bool _listenersSetUp = false;

  /// Called when a foreground FCM message arrives. Wire this up in app.dart.
  void Function(RemoteMessage)? onForegroundMessage;

  /// Initialize Firebase, request permissions, get FCM token, register with backend.
  /// Retries on subsequent calls until a token is successfully registered.
  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      DebugService.talker.debug('[FCM] Permission denied — skipping registration.');
      return;
    }

    if (!_listenersSetUp) {
      _listenersSetUp = true;
      messaging.onTokenRefresh.listen((t) async {
        DebugService.talker.debug('[FCM] onTokenRefresh fired — registering new token.');
        await _registerToken(t);
        _initialized = true;
      });
      FirebaseMessaging.onMessage.listen(
        (msg) => onForegroundMessage?.call(msg),
      );
      DebugService.talker.debug('[FCM] Listeners set up.');
    }

    // iOS: FCM token is derived from the APNs token, which Apple delivers
    // asynchronously after requestPermission(). Wait for it before calling
    // getToken(), otherwise we get [firebase_messaging/apns-token-not-set].
    if (Platform.isIOS) {
      final apns = await _waitForApnsToken(messaging);
      if (apns == null) {
        DebugService.talker.debug(
          '[FCM] APNs token still null after waiting — onTokenRefresh will handle it later.',
        );
        return;
      }
      DebugService.talker.debug('[FCM] APNs token acquired.');
    }

    try {
      DebugService.talker.debug('[FCM] Requesting FCM token…');
      final token = await messaging.getToken();
      if (token != null) {
        DebugService.talker.debug('[FCM] FCM token received — registering device.');
        await _registerToken(token);
        _initialized = true;
      } else {
        DebugService.talker.debug('[FCM] getToken() returned null — onTokenRefresh will handle it.');
      }
    } catch (e, st) {
      DebugService.talker.error('[FCM] getToken() threw an error', e, st);
    }
  }

  /// Polls for the APNs token for up to 30 seconds. Returns null if it never
  /// arrives (usually means a misconfiguration on the Apple/Firebase side).
  Future<String?> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var i = 0; i < 30; i++) {
      DebugService.talker.debug('[FCM] Fetching APNs token… (attempt ${i + 1})');
      final apns = await messaging.getAPNSToken();
      if (apns != null) return apns;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Call on logout — deletes the FCM token so it becomes invalid and the
  /// backend will drop it automatically on the next failed delivery attempt.
  Future<void> deactivate() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _initialized = false;
  }

  Future<void> _registerToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_kDeviceIdKey);
    if (deviceId == null) {
      deviceId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      await prefs.setString(_kDeviceIdKey, deviceId);
    }
    DebugService.talker.debug('[FCM] Sending device token to backend (deviceId=$deviceId).');
    await ApiService.instance.registerDevice(
      deviceId: deviceId,
      deviceToken: token,
      deviceType: Platform.isIOS ? 'ios' : 'android',
    );
    DebugService.talker.debug('[FCM] Device registered.');
  }
}