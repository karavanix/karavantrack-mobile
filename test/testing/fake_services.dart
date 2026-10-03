import 'dart:async';

import 'package:driver_tracking_app/data/services/app_info_service.dart';
import 'package:driver_tracking_app/data/services/app_lifecycle_service.dart';
import 'package:driver_tracking_app/data/services/apple_sign_in_service.dart';
import 'package:driver_tracking_app/data/services/camera_service.dart';
import 'package:driver_tracking_app/data/services/connectivity_service.dart';
import 'package:driver_tracking_app/data/services/deep_link_service.dart';
import 'package:driver_tracking_app/data/services/location_status_service.dart';
import 'package:driver_tracking_app/data/services/push_service.dart';
import 'package:driver_tracking_app/data/services/telegram_auth_service.dart';
import 'package:driver_tracking_app/domain/models/location_state.dart';
import 'package:driver_tracking_app/utils/result.dart';

class FakePushService implements PushService {
  String? token = 'push-token';
  int permissionRequests = 0;
  int deletedTokens = 0;
  final refreshes = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final opened = StreamController<String>.broadcast();

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
  Stream<String> get openedLoadIds => opened.stream;

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

/// The phone's location settings, and how the driver answers the prompts.
class FakeLocationStatusService implements LocationStatusService {
  FakeLocationStatusService({
    this.serviceEnabled = true,
    this.access = LocationAccess.always,
  });

  bool serviceEnabled;
  LocationAccess access;
  bool precise = true;

  /// What the driver picks at the system prompts.
  LocationAccess grantAtWhileInUse = LocationAccess.whileInUse;
  LocationAccess grantAtAlways = LocationAccess.always;

  final requests = <String>[];
  int settingsOpened = 0;

  @override
  Future<LocationState> read() async => LocationState(
    serviceEnabled: serviceEnabled,
    access: access,
    precise: precise,
  );

  @override
  Future<void> requestWhileInUse() async {
    requests.add('whileInUse');
    access = grantAtWhileInUse;
  }

  @override
  Future<void> requestAlways() async {
    requests.add('always');
    access = grantAtAlways;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.initial = true});

  final bool initial;
  final changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> online() async* {
    yield initial;
    yield* changes.stream;
  }
}

class FakeAppLifecycleService implements AppLifecycleService {
  final resumes = StreamController<void>.broadcast();
  final pauses = StreamController<void>.broadcast();

  @override
  Stream<void> get resumed => resumes.stream;

  @override
  Stream<void> get paused => pauses.stream;

  @override
  bool get isResumed => true;
}

class FakeCameraService implements CameraService {
  /// The next photo taken; null as if the driver backed out.
  String? next;

  @override
  Future<String?> takePhoto() async => next;
}
