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
import 'package:driver_tracking_app/utils/pkce.dart';
import 'package:driver_tracking_app/utils/result.dart';

/// FCM as it behaves on a device: a token it creates (first launch, or
/// the first one after [deleteToken]) comes on [tokenRefreshes] too, at the
/// same time as [requestToken] returns it.
class FakePushService implements PushService {
  String? token = 'push-token';
  int permissionRequests = 0;
  int deletedTokens = 0;
  String? _issued;
  final refreshes = StreamController<String>.broadcast();
  final messages = StreamController<PushMessage>.broadcast();
  final opened = StreamController<String>.broadcast();

  @override
  Future<String?> requestToken() async {
    permissionRequests++;
    final created = token;
    if (created != null && created != _issued) {
      _issued = created;
      refreshes.add(created);
    }
    return created;
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushMessage> get foregroundMessages => messages.stream;

  @override
  Stream<String> get openedLoadIds => opened.stream;

  @override
  Future<void> deleteToken() async {
    deletedTokens++;
    _issued = null;
  }

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

/// Telegram as the driver uses it. By default the Telegram app is
/// installed; [appLoginAvailable] = false sends the login to the browser.
class FakeTelegramAuthService implements TelegramAuthService {
  final controller = StreamController<TelegramCallback>();

  /// Links opened: `tg://` ones in the Telegram app, `https` in the browser.
  final opened = <Uri>[];
  bool appLoginAvailable = true;

  /// The challenge of the last link asked for, to check the verifier
  /// against in [exchange] — as Telegram does.
  String? challenge;
  final exchanges = <String>[];

  @override
  Stream<TelegramCallback> get callbacks => controller.stream;

  @override
  void listen(Stream<Uri> links) {}

  @override
  Future<Uri?> appLoginUrl({required String codeChallenge}) async {
    challenge = codeChallenge;
    return Uri.parse('tg://resolve?domain=oauth&startapp=t1');
  }

  @override
  Future<bool> openApp(Uri url) async {
    if (!appLoginAvailable) return false;
    opened.add(url);
    return true;
  }

  @override
  Future<Result<String>> exchange({
    required String code,
    required String codeVerifier,
  }) async {
    exchanges.add(code);
    if (code != 'tg-app-code' || pkceChallenge(codeVerifier) != challenge) {
      return const Result.error(TelegramLoginException('invalid_grant'));
    }
    return const Result.ok('tg-id-token');
  }

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

  /// Telegram opening the app's login link after "Log In".
  void appRedirect({String code = 'tg-app-code'}) =>
      controller.add(TelegramAppCallback(code));

  /// What the native side does when the browser login redirects back.
  void redirect({required String code, required String state}) =>
      controller.add(TelegramWebCallback(code, state: state));
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
  bool grantMotion = true;
  final changed = StreamController<void>.broadcast();

  final requests = <String>[];
  int settingsOpened = 0;

  /// Like the library's providerState on iOS: [read] still reports the
  /// access from before the latest prompt.
  bool readLags = false;
  LocationAccess? _before;

  /// While set, the "all the time" prompt is up until it completes.
  Completer<void>? alwaysPrompt;

  @override
  Future<LocationState> read() async => LocationState(
    serviceEnabled: serviceEnabled,
    access: readLags ? _before ?? access : access,
    precise: precise,
  );

  @override
  Future<LocationAccess> requestWhileInUse() async {
    requests.add('whileInUse');
    _before = access;
    return access = grantAtWhileInUse;
  }

  @override
  Future<LocationAccess> requestAlways() async {
    requests.add('always');
    await alwaysPrompt?.future;
    _before = access;
    return access = grantAtAlways;
  }

  @override
  Future<bool> requestMotion() async {
    requests.add('motion');
    return grantMotion;
  }

  @override
  Stream<void> get changes => changed.stream;

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
