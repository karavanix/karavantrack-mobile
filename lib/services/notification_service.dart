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

    // Set up listeners before the APNs check so onTokenRefresh is always active.
    // This is critical on iOS: if getAPNSToken() returns null (APNs is slow on
    // first launch), we return early below — but onTokenRefresh will still fire
    // and register the device the moment Firebase gets a valid token.
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

    // On iOS, FCM tokens depend on APNs tokens which may not be ready immediately.
    // Wait for the APNs token before requesting the FCM token.
    if (Platform.isIOS) {
      String? apnsToken;
      for (int i = 0; i < 5 && apnsToken == null; i++) {
        DebugService.talker.debug('[FCM] Requesting APNs token (attempt ${i + 1}/5)…');
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      if (apnsToken == null) {
        // APNs is not ready yet — onTokenRefresh (registered above) will fire
        // and handle registration automatically when the token arrives.
        DebugService.talker.debug('[FCM] APNs token not ready — onTokenRefresh will handle it.');
        return;
      }
      DebugService.talker.debug('[FCM] APNs token received.');
    }

    final token = await messaging.getToken();
    if (token != null) {
      DebugService.talker.debug('[FCM] FCM token received — registering device.');
      await _registerToken(token);
      _initialized = true;
    } else {
      DebugService.talker.debug('[FCM] FCM getToken() returned null.');
    }
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