import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/attachment_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/connectivity_repository.dart';
import '../data/repositories/invite_repository.dart';
import '../data/repositories/loads_repository.dart';
import '../data/repositories/location_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/push_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tracking_repository.dart';
import '../data/services/api/account_api.dart';
import '../data/services/api/api_client.dart';
import '../data/services/api/attachments_api.dart';
import '../data/services/api/auth_api.dart';
import '../data/services/api/invites_api.dart';
import '../data/services/api/loads_api.dart';
import '../data/services/app_info_service.dart';
import '../data/services/app_lifecycle_service.dart';
import '../data/services/apple_sign_in_service.dart';
import '../data/services/camera_service.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/deep_link_service.dart';
import '../data/services/local_store.dart';
import '../data/services/location_status_service.dart';
import '../data/services/push_service.dart';
import '../data/services/telegram_auth_service.dart';
import '../data/services/tracking/tracking_service.dart';
import '../domain/use_cases/advance_load.dart';
import '../domain/use_cases/session_lifecycle.dart';
import '../domain/use_cases/tracking_lifecycle.dart';
import '../routing/app_startup.dart';
import '../ui/core/l10n/tracking_texts.dart';

/// The services that talk to the platform or the network directly. Tests
/// replace them with fakes.
class Services {
  Services({
    required this.store,
    required this.telegram,
    required this.tracking,
    this.trackingAtLaunch = TrackingSnapshot.off,
    PushService? push,
    DeepLinkService? links,
    AppleSignInService? apple,
    AppInfoService? appInfo,
    LocationStatusService? location,
    ConnectivityService? connectivity,
    AppLifecycleService? lifecycle,
    CameraService? camera,
    this.http,
  }) : push = push ?? FirebasePushService(),
       links = links ?? DeepLinkService(),
       apple = apple ?? AppleSignInService(),
       appInfo = appInfo ?? AppInfoService(),
       location = location ?? TrackingLocationStatusService(),
       connectivity = connectivity ?? ConnectivityService(),
       lifecycle = lifecycle ?? AppLifecycleService(),
       camera = camera ?? CameraService();

  final LocalStore store;
  final TelegramAuthService telegram;

  /// Made ready in main before anything else (see TrackingRepository.ready).
  final TrackingService tracking;
  final TrackingSnapshot trackingAtLaunch;
  final PushService push;
  final DeepLinkService links;
  final AppleSignInService apple;
  final AppInfoService appInfo;
  final LocationStatusService location;
  final ConnectivityService connectivity;
  final AppLifecycleService lifecycle;
  final CameraService camera;

  /// Replaces the network under every API client.
  final HttpClientAdapter? http;
}

/// The object graph: services first, repositories on top of them. Views and
/// view models get what they need with `context.read<T>()`.
List<SingleChildWidget> providers(Services services) => [
  Provider<LocalStore>.value(value: services.store),
  Provider<TelegramAuthService>.value(value: services.telegram),
  Provider<TrackingService>.value(value: services.tracking),
  Provider<PushService>.value(value: services.push),
  Provider<DeepLinkService>.value(value: services.links),
  Provider<AppleSignInService>.value(value: services.apple),
  Provider<AppInfoService>.value(value: services.appInfo),
  Provider<LocationStatusService>.value(value: services.location),
  Provider<ConnectivityService>.value(value: services.connectivity),
  Provider<AppLifecycleService>.value(value: services.lifecycle),
  Provider<CameraService>.value(value: services.camera),
  Provider(create: (_) => AuthApi(ApiClient.public(adapter: services.http))),
  ChangeNotifierProvider(
    create: (context) => AuthRepository(
      api: context.read(),
      store: context.read(),
      apple: context.read(),
      telegram: context.read(),
    ),
  ),
  Provider(
    create: (context) => ApiClient.authenticated(
      tokens: context.read<AuthRepository>(),
      adapter: services.http,
    ),
  ),
  Provider(create: (context) => AccountApi(context.read())),
  Provider(create: (context) => InvitesApi(context.read())),
  Provider(create: (context) => LoadsApi(context.read())),
  Provider(create: (context) => AttachmentsApi(context.read())),
  ChangeNotifierProvider(
    create: (context) => SettingsRepository(store: context.read()),
  ),
  ChangeNotifierProvider(
    create: (context) =>
        ProfileRepository(api: context.read(), store: context.read()),
  ),
  ChangeNotifierProvider(
    create: (context) =>
        InviteRepository(api: context.read(), links: context.read()),
  ),
  ChangeNotifierProvider(
    create: (context) =>
        LoadsRepository(api: context.read(), store: context.read()),
  ),
  Provider(create: (context) => AttachmentRepository(api: context.read())),
  ChangeNotifierProvider(
    create: (context) => TrackingRepository(
      service: context.read(),
      store: context.read(),
      texts: () => trackingTexts(services.store),
      launch: services.trackingAtLaunch,
    ),
  ),
  Provider(
    create: (context) => AdvanceLoadUseCase(
      loads: context.read(),
      attachments: context.read(),
      tracking: context.read(),
    ),
  ),
  ChangeNotifierProvider(
    create: (context) => LocationRepository(service: context.read()),
  ),
  ChangeNotifierProvider(
    create: (context) => ConnectivityRepository(service: context.read()),
  ),
  Provider(
    create: (context) => PushRepository(
      push: context.read(),
      api: context.read(),
      store: context.read(),
    ),
  ),
  // Not lazy: it restores the session and must hear every sign-in and
  // sign-out from the start.
  Provider(
    lazy: false,
    create: (context) => SessionLifecycle(
      auth: context.read(),
      profile: context.read(),
      push: context.read(),
      invites: context.read(),
      account: context.read(),
      loads: context.read(),
      location: context.read(),
      connectivity: context.read(),
      lifecycle: context.read(),
      tracking: context.read(),
    )..start(),
    dispose: (_, session) => session.dispose(),
  ),
  // Not lazy either: tracking must resume for the active load whatever
  // screen the app opens on.
  Provider(
    lazy: false,
    create: (context) => TrackingLifecycle(
      auth: context.read(),
      loads: context.read(),
      location: context.read(),
      tracking: context.read(),
    )..start(),
    dispose: (_, lifecycle) => lifecycle.dispose(),
  ),
  ChangeNotifierProvider(create: (_) => AppStartup()..run(const [])),
];
