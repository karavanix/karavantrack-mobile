import 'dart:async';

import 'package:driver_tracking_app/data/services/app_info_service.dart';
import 'package:driver_tracking_app/data/services/apple_sign_in_service.dart';
import 'package:driver_tracking_app/data/services/deep_link_service.dart';
import 'package:driver_tracking_app/data/services/push_service.dart';
import 'package:driver_tracking_app/data/services/telegram_auth_service.dart';
import 'package:driver_tracking_app/utils/result.dart';

class FakePushService implements PushService {
  String? token = 'push-token';
  int permissionRequests = 0;
  int deletedTokens = 0;
  final refreshes = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();

  @override
  Future<String?> requestToken() async {
    permissionRequests++;
    return token;
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushMessage> get foregroundMessages => messages.stream;

  @override
  Future<void> deleteToken() async => deletedTokens++;

  @override
  String get platform => 'android';
}

class FakeDeepLinkService implements DeepLinkService {
  final controller = StreamController<Uri>();

  @override
  Stream<Uri> links() => controller.stream;
}

class FakeAppleSignInService implements AppleSignInService {
  Result<AppleCredential> next = const Result.error(AppleSignInCancelled());

  @override
  bool get isAvailable => true;

  @override
  Future<Result<AppleCredential>> requestCredential() async => next;
}

class FakeTelegramAuthService implements TelegramAuthService {
  final controller = StreamController<TelegramCallback>();
  final opened = <Uri>[];

  @override
  Stream<TelegramCallback> get callbacks => controller.stream;

  @override
  void listen() {}

  @override
  Uri authorizeUrl({
    required String state,
    required String codeChallenge,
    required String redirectUri,
  }) => Uri.https('oauth.telegram.org', '/auth', {
    'state': state,
    'code_challenge': codeChallenge,
  });

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }

  /// What the native side does when Telegram redirects back.
  void redirect({required String code, required String state}) =>
      controller.add((code: code, state: state));
}

class FakeAppInfoService implements AppInfoService {
  @override
  Future<String> version() async => '9.9.9+99';
}
