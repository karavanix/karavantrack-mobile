import 'package:driver_tracking_app/config/dependencies.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'fake_backend.dart';
import 'fake_local_store.dart';
import 'fake_services.dart';
import 'fake_tracking_service.dart';

/// The real App and object graph on a fake device and backend, driven the
/// way a driver would.
class Harness {
  Harness({Map<String, Object>? device})
    : store = FakeLocalStore(device),
      backend = FakeBackend();

  final FakeLocalStore store;
  final FakeBackend backend;
  final push = FakePushService();
  final links = FakeDeepLinkService();
  final telegram = FakeTelegramAuthService();
  final location = FakeLocationStatusService();
  final connectivity = FakeConnectivityService();
  final lifecycle = FakeAppLifecycleService();
  final camera = FakeCameraService();
  late final tracking = FakeTrackingService(backend);

  Future<void> start(WidgetTester tester) async {
    // The stepper's pulse never ends; "reduce motion" holds it still so
    // pumpAndSettle can settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final services = Services(
      store: store,
      telegram: telegram,
      tracking: tracking,
      push: push,
      links: links,
      apple: FakeAppleSignInService(),
      appInfo: FakeAppInfoService(),
      location: location,
      connectivity: connectivity,
      lifecycle: lifecycle,
      camera: camera,
      http: backend.server,
    );
    await tester.pumpWidget(
      MultiProvider(providers: providers(services), child: const App()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }
}

const signedInDevice = <String, Object>{
  StoreKeys.accessToken: 'access-0',
  StoreKeys.refreshToken: 'refresh-0',
  StoreKeys.seenLanguage: true,
  StoreKeys.seenOnboarding: true,
};

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Snackbars stay 4 s and in the 800×600 test window can cover the button
/// pressed next.
Future<void> clearSnackBars(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .clearSnackBars();
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
}
