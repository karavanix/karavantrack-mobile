import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

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
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // On iOS, FCM tokens depend on APNs tokens which may not be ready immediately.
    // Wait for the APNs token before requesting the FCM token.
    if (Platform.isIOS) {
      String? apnsToken;
      for (int i = 0; i < 5 && apnsToken == null; i++) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      if (apnsToken == null) return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
      _initialized = true;
    }

    // Set up listeners only once — even if token was null this time.
    if (!_listenersSetUp) {
      _listenersSetUp = true;
      messaging.onTokenRefresh.listen((t) async {
        await _registerToken(t);
        _initialized = true;
      });
      FirebaseMessaging.onMessage.listen(
        (msg) => onForegroundMessage?.call(msg),
      );
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
    await ApiService.instance.registerDevice(
      deviceId: deviceId,
      deviceToken: token,
      deviceType: Platform.isIOS ? 'ios' : 'android',
    );
  }
}
