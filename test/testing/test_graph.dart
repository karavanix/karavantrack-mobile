import 'package:driver_tracking_app/data/repositories/attachment_repository.dart';
import 'package:driver_tracking_app/data/repositories/auth_repository.dart';
import 'package:driver_tracking_app/data/repositories/connectivity_repository.dart';
import 'package:driver_tracking_app/data/repositories/invite_repository.dart';
import 'package:driver_tracking_app/data/repositories/loads_repository.dart';
import 'package:driver_tracking_app/data/repositories/location_repository.dart';
import 'package:driver_tracking_app/data/repositories/profile_repository.dart';
import 'package:driver_tracking_app/data/repositories/push_repository.dart';
import 'package:driver_tracking_app/data/repositories/settings_repository.dart';
import 'package:driver_tracking_app/data/repositories/tracking_repository.dart';
import 'package:driver_tracking_app/data/services/api/account_api.dart';
import 'package:driver_tracking_app/data/services/api/api_client.dart';
import 'package:driver_tracking_app/data/services/api/attachments_api.dart';
import 'package:driver_tracking_app/data/services/api/auth_api.dart';
import 'package:driver_tracking_app/data/services/api/invites_api.dart';
import 'package:driver_tracking_app/data/services/api/loads_api.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/data/services/tracking/tracking_service.dart';
import 'package:driver_tracking_app/domain/use_cases/advance_load.dart';
import 'package:driver_tracking_app/domain/use_cases/session_lifecycle.dart';
import 'package:driver_tracking_app/domain/use_cases/tracking_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';
import 'fake_local_store.dart';
import 'fake_services.dart';
import 'fake_tracking_service.dart';

/// The data layer wired the way config/dependencies.dart wires it, over
/// fakes. Everything is created on first use.
class TestGraph {
  TestGraph({FakeBackend? backend, FakeLocalStore? store})
    : backend = backend ?? FakeBackend(),
      store = store ?? FakeLocalStore();

  /// A device already signed in (tokens the backend accepts on refresh are
  /// not needed: requests just carry a header).
  factory TestGraph.signedIn({
    FakeBackend? backend,
    bool cachedProfile = true,
  }) => TestGraph(
    backend: backend,
    store: FakeLocalStore({
      StoreKeys.accessToken: 'access-0',
      StoreKeys.refreshToken: 'refresh-0',
      StoreKeys.seenLanguage: true,
      StoreKeys.seenOnboarding: true,
      if (cachedProfile)
        StoreKeys.cachedProfile:
            '{"id":"u1","first_name":"Ali","last_name":"Valiev"}',
    }),
  );

  final FakeBackend backend;
  final FakeLocalStore store;
  final push = FakePushService();
  final links = FakeDeepLinkService();
  final apple = FakeAppleSignInService();
  final telegram = FakeTelegramAuthService();
  final locationService = FakeLocationStatusService();
  final connectivityService = FakeConnectivityService();
  final lifecycle = FakeAppLifecycleService();
  late final trackingService = FakeTrackingService(backend);

  /// What the clock says, for the tracking queue's age.
  DateTime now = DateTime.utc(2026, 10, 4, 12);

  late final auth = AuthRepository(
    api: AuthApi(ApiClient.public(adapter: backend.server)),
    store: store,
    apple: apple,
    telegram: telegram,
  );
  late final _client = ApiClient.authenticated(
    tokens: auth,
    adapter: backend.server,
  );
  late final account = AccountApi(_client);
  late final settings = SettingsRepository(store: store);
  late final profile = ProfileRepository(api: account, store: store);
  late final invites = InviteRepository(api: InvitesApi(_client), links: links);
  late final pushes = PushRepository(push: push, api: account, store: store);
  late final loads = LoadsRepository(api: LoadsApi(_client), store: store);
  late final attachments = AttachmentRepository(api: AttachmentsApi(_client));
  late final tracking = TrackingRepository(
    service: trackingService,
    store: store,
    texts: () => testTrackingTexts,
    launch: TrackingSnapshot(
      enabled: trackingService.enabled,
      isMoving: trackingService.isMoving,
    ),
    flushTimeout: const Duration(milliseconds: 50),
    now: () => now,
  );
  late final advance = AdvanceLoadUseCase(
    loads: loads,
    attachments: attachments,
    tracking: tracking,
  );
  late final location = LocationRepository(
    service: locationService,
    pollInterval: const Duration(days: 1),
  );
  late final connectivity = ConnectivityRepository(
    service: connectivityService,
  );
  late final session = SessionLifecycle(
    auth: auth,
    profile: profile,
    push: pushes,
    invites: invites,
    account: account,
    loads: loads,
    location: location,
    connectivity: connectivity,
    lifecycle: lifecycle,
    tracking: tracking,
  )..start();
  late final trackingLifecycle = TrackingLifecycle(
    auth: auth,
    loads: loads,
    location: location,
    tracking: tracking,
  )..start();
}

/// Lets queued futures and stream events run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await settle();
  }
  expect(condition(), isTrue);
}
