import 'dart:async';

import 'package:driver_tracking_app/utils/command.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports running, then the result', () async {
    final gate = Completer<Result<int>>();
    final command = Command0(() => gate.future);
    final seen = <(bool, bool, bool)>[];
    command.addListener(
      () => seen.add((command.running, command.completed, command.error)),
    );

    final run = command.execute();
    expect(command.running, isTrue);
    gate.complete(const Result.ok(1));
    await run;

    expect(seen, [(true, false, false), (false, true, false)]);
    expect((command.result! as Ok<int>).value, 1);
  });

  test('keeps an error result until cleared', () async {
    final command = Command1<void, String>(
      (_) async => Result.error(Exception('boom')),
    );

    await command.execute('x');
    expect(command.error, isTrue);

    command.clearResult();
    expect(command.result, isNull);
    expect(command.error, isFalse);
  });

  test('ignores a second execute while running', () async {
    var calls = 0;
    final gate = Completer<Result<void>>();
    final command = Command0(() {
      calls++;
      return gate.future;
    });

    final first = command.execute();
    await command.execute();
    gate.complete(const Result.ok(null));
    await first;

    expect(calls, 1);
  });

  test('finishes quietly when disposed while running', () async {
    final gate = Completer<Result<void>>();
    final command = Command0(() => gate.future);

    final run = command.execute();
    command.dispose();
    gate.complete(const Result.ok(null));

    await expectLater(run, completes);
  });
}
