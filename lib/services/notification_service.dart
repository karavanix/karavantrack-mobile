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

  /// Called when a foreground FCM message arrives. Wire this up in app.dart.
  void Function(RemoteMessage)? onForegroundMessage;

  /// Initialize Firebase, request permissions, get FCM token, register with backend.
  /// Safe to call multiple times — only runs once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token != null) await _registerToken(token);

    messaging.onTokenRefresh.listen(_registerToken);
    FirebaseMessaging.onMessage.listen(
      (msg) => onForegroundMessage?.call(msg),
    );
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
