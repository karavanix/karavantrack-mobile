import 'package:driver_tracking_app/config/dependencies.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../testing/fake_local_store.dart';

/// Boots the real App with the real object graph on an empty device.
void main() {
  Future<void> boot(WidgetTester tester, FakeLocalStore store) async {
    await tester.pumpWidget(
      MultiProvider(providers: providers(store), child: const App()),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('fresh install: splash, then the language picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(providers: providers(FakeLocalStore()), child: const App()),
    );
    expect(find.text('/splash'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('/language'), findsOneWidget);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.text('/onboarding'), findsOneWidget);
  });

  testWidgets('signed in: lands on the loads tab, in the chosen language', (
    tester,
  ) async {
    await boot(
      tester,
      FakeLocalStore({
        StoreKeys.refreshToken: 'r',
        StoreKeys.locale: 'ru',
        StoreKeys.seenLanguage: true,
        StoreKeys.seenOnboarding: true,
      }),
    );

    expect(find.text('/loads'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Грузы'), findsOneWidget);
  });
}
