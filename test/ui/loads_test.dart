import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/domain/models/location_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../testing/app_harness.dart';
import '../testing/fake_backend.dart';

/// A driver already in the app.
Harness inApp() => Harness(
  device: {
    ...signedInDevice,
    StoreKeys.cachedProfile: '{"id":"u1","first_name":"Ali"}',
  },
);

/// Gives the driver load `A`, titled Cotton, in [status].
void activeLoad(Harness h, [String status = 'accepted']) {
  h.backend.activeLoadId = 'A';
  h.backend.loads['A']!
    ..title = 'Cotton'
    ..status = status
    ..history.add((from: 'assigned', to: 'accepted'));
}

ButtonStyleButton buttonWithText(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(text),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  testWidgets('the active load with its next step, pending loads below', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h);
    h.backend.addPending(2);
    await h.start(tester);

    expect(find.text('Cotton'), findsOneWidget);
    expect(find.text('Load P1'), findsOneWidget);
    expect(
      find.text('Finish your active load to accept a new one'),
      findsNWidgets(2),
    );
    expect(
      tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .map((b) => b.onPressed),
      everyElement(isNull),
    );

    await tapText(tester, 'Begin Pickup');

    expect(h.backend.loads['A']!.status, 'picking_up');
    expect(find.text('Picking Up'), findsOneWidget);
    expect(find.text('Confirm Cargo Loaded'), findsOneWidget);
  });

  testWidgets('accepting a pending load makes it the active one', (
    tester,
  ) async {
    final h = inApp()..backend.addPending(1);
    await h.start(tester);
    expect(find.text('No active load'), findsOneWidget);

    await tapText(tester, 'Accept Load');

    expect(h.backend.loads['P1']!.status, 'accepted');
    expect(find.text('Begin Pickup'), findsOneWidget);
    expect(find.text('No pending loads'), findsOneWidget);
  });

  testWidgets('dropped off: waits for the shipper, and says tracking goes on', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h, 'dropped_off');
    h.backend.addPending(1);
    await h.start(tester);

    expect(find.text('Awaiting shipper confirmation'), findsOneWidget);
    expect(
      find.text(
        'Your location is still being shared until the shipper confirms '
        'the delivery.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'You can accept a new load once the shipper confirms the current one',
      ),
      findsOneWidget,
    );
    expect(find.text('Begin Pickup'), findsNothing);
  });

  testWidgets('a load cancelled meanwhile: said so, and shown as it is', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h);
    await h.start(tester);
    h.backend.loads['A']!.status = 'cancelled';

    await tapText(tester, 'Begin Pickup');

    expect(
      find.text('The load has changed. Showing its current status.'),
      findsOneWidget,
    );
    expect(find.text('No active load'), findsOneWidget);
  });

  testWidgets('details: history and the next step', (tester) async {
    final h = inApp();
    activeLoad(h);
    await h.start(tester);

    await tapText(tester, 'Cotton');

    expect(find.text('Status History'), findsOneWidget);
    expect(find.text('Assigned → Accepted'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Begin Pickup'));
    await tester.pumpAndSettle();

    expect(h.backend.loads['A']!.status, 'picking_up');
    expect(find.text('Accepted → Picking Up'), findsOneWidget);
    expect(find.text('Confirm Cargo Loaded'), findsOneWidget);

    // Back on the tab, the card moved on too.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Confirm Cargo Loaded'), findsOneWidget);
  });

  testWidgets('details of a pending load while busy: accept is off', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h);
    h.backend.addPending(1);
    await h.start(tester);

    await tapText(tester, 'Load P1');

    expect(buttonWithText(tester, 'Accept Load').onPressed, isNull);
  });

  testWidgets('no signal: the saved active load is still there', (
    tester,
  ) async {
    final h = Harness(
      device: {
        ...signedInDevice,
        StoreKeys.cachedProfile: '{"id":"u1","first_name":"Ali"}',
        StoreKeys.cachedActiveLoad:
            '{"id":"A","title":"Cotton","status":"in_transit",'
            '"created_at":"2026-10-01T08:00:00Z"}',
      },
    )..backend.online = false;
    await h.start(tester);

    expect(find.text('Cotton'), findsOneWidget);
    expect(find.text('Begin Dropoff'), findsOneWidget);
    // Not "no pending loads": that would be a guess.
    expect(
      find.text('No internet connection. Check it and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('location: the disclosure once, then the overlay explains', (
    tester,
  ) async {
    final h = inApp();
    h.location.access = LocationAccess.denied;
    await h.start(tester);

    expect(find.text('Background Location Access'), findsOneWidget);
    expect(h.push.permissionRequests, 0);

    await tapText(tester, 'Not Now');

    expect(find.text('Background Location Required'), findsOneWidget);
    expect(h.location.requests, isEmpty);
    // The notification prompt only now.
    expect(h.push.permissionRequests, 1);

    // Coming back from the background re-checks, without a second dialog.
    h.lifecycle.resumes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Background Location Access'), findsNothing);

    // The card scrolls in the small test window.
    await tester.ensureVisible(find.text('Open Settings'));
    await tapText(tester, 'Open Settings');
    expect(h.location.settingsOpened, 1);
  });

  testWidgets('location: "Allow" goes through the system prompts', (
    tester,
  ) async {
    final h = inApp();
    h.location.access = LocationAccess.denied;
    await h.start(tester);

    await tapText(tester, 'Allow');

    expect(h.location.requests, ['whileInUse', 'always', 'motion']);
    expect(find.text('Background Location Required'), findsNothing);
  });

  testWidgets('GPS off: the overlay leads to the location settings', (
    tester,
  ) async {
    final h = inApp();
    h.location.serviceEnabled = false;
    await h.start(tester);

    expect(find.text('GPS is Off'), findsOneWidget);
    await tapText(tester, 'Turn On GPS');
    expect(h.location.settingsOpened, 1);
  });

  testWidgets('a tapped notification opens its load', (tester) async {
    final h = inApp();
    activeLoad(h);
    await h.start(tester);

    h.push.opened.add('A');
    await tester.pumpAndSettle();

    expect(find.text('Status History'), findsOneWidget);
  });

  testWidgets('a notification tapped at launch waits for the app', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h);
    // Arrives during the splash.
    h.push.opened.onListen = () => h.push.opened.add('A');
    await h.start(tester);

    expect(find.text('Status History'), findsOneWidget);
  });

  testWidgets('history lists the finished loads', (tester) async {
    final h = inApp();
    h.backend.loads['H'] = FakeLoad(
      'H',
      status: 'confirmed',
      title: 'Old cotton',
    );
    await h.start(tester);

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('Old cotton'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('the card shows tracking, and points that don\'t get through', (
    tester,
  ) async {
    final h = inApp();
    activeLoad(h);
    await h.start(tester);

    expect(h.tracking.enabled, isTrue);
    expect(h.tracking.setup?.loadId, 'A');
    expect(find.text('GPS active'), findsOneWidget);

    // A point a few seconds old is just waiting for its batch.
    h.tracking.record(at: DateTime.now());
    await tester.pumpAndSettle();
    expect(find.textContaining('waiting to be sent'), findsNothing);
    await tester.runAsync(h.tracking.autoSync);

    // One that has waited six minutes isn't getting through.
    h.tracking
      ..record(at: DateTime.now().subtract(const Duration(minutes: 6)))
      ..record(at: DateTime.now());
    await tester.pumpAndSettle();
    expect(find.text('2 points waiting to be sent'), findsOneWidget);

    await tester.runAsync(h.tracking.autoSync);
    await tester.pumpAndSettle();
    expect(find.textContaining('waiting to be sent'), findsNothing);
  });
}
