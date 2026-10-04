import 'package:driver_tracking_app/reference/reference_recorder.dart';
import 'package:driver_tracking_app/reference/reference_screen.dart';
import 'package:driver_tracking_app/reference/reference_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_reference_recorder.dart';

void main() {
  late FakeReferenceRecorder recorder;
  late ReferenceViewModel vm;

  setUp(() {
    recorder = FakeReferenceRecorder()
      ..records.add(record(at: '2026-10-04T10:00:00.000Z'));
    vm = ReferenceViewModel(
      recorder: recorder,
      atLaunch: const RecorderState(enabled: false, isMoving: false),
    );
  });

  tearDown(() => vm.dispose());

  testWidgets('start and stop', (tester) async {
    await tester.pumpWidget(ReferenceApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.text('выключена'), findsOneWidget);

    await tester.tap(find.text('Старт'));
    await tester.pumpAndSettle();
    expect(find.text('Стоп'), findsOneWidget);
    expect(find.text('включена'), findsOneWidget);

    await tester.tap(find.text('Стоп'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['start', 'stop']);
  });

  testWidgets('deleting the points asks first', (tester) async {
    await tester.pumpWidget(ReferenceApp(viewModel: vm));
    await tester.pumpAndSettle();
    final delete = find.text('Удалить все точки из базы');

    await tester.scrollUntilVisible(delete, 200);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.textContaining('В базе 1 точек'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(recorder.calls, isEmpty);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(recorder.calls, ['destroy']);
    expect(recorder.records, isEmpty);
  });

  testWidgets(
    'the power saving block is Android only',
    (tester) async {
      await tester.pumpWidget(ReferenceApp(viewModel: vm));
      await tester.pumpAndSettle();

      final android = defaultTargetPlatform == TargetPlatform.android;
      expect(
        find.text('Энергосбережение', skipOffstage: false),
        android ? findsOneWidget : findsNothing,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
