import 'dart:async';

import 'package:driver_tracking_app/data/services/system_prompt.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<AppLifecycleState> lifecycle;
  late AppLifecycleState current;

  setUp(() {
    lifecycle = StreamController<AppLifecycleState>.broadcast(sync: true);
    current = AppLifecycleState.resumed;
  });

  tearDown(() => lifecycle.close());

  Future<bool> run(Future<void> Function() request) => untilPromptAnswered(
    request,
    lifecycle: lifecycle.stream,
    current: () => current,
    appear: const Duration(milliseconds: 50),
    answer: const Duration(seconds: 2),
  );

  test('a request returning at once (iOS "Always") waits for the prompt to '
      'close', () async {
    var done = false;
    final waiting = run(() async {}).then((shown) {
      done = true;
      return shown;
    });

    lifecycle.add(AppLifecycleState.inactive);
    // The driver takes their time over the prompt.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(done, isFalse);

    lifecycle.add(AppLifecycleState.resumed);
    expect(await waiting, isTrue);
  });

  test('the prompt already up when the request returns', () async {
    var done = false;
    final waiting = run(() async {
      current = AppLifecycleState.inactive;
    }).then((shown) => done = shown);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(done, isFalse);

    lifecycle.add(AppLifecycleState.resumed);
    await waiting;
    expect(done, isTrue);
  });

  test('a request that waited for the answer itself returns at once', () async {
    final shown = await run(() async {
      lifecycle
        ..add(AppLifecycleState.inactive)
        ..add(AppLifecycleState.resumed);
    });

    expect(shown, isTrue);
  });

  test('no prompt shown (iOS skipped the upgrade): on after a short '
      'wait', () async {
    expect(await run(() async {}), isFalse);
  });
}
