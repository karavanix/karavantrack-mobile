import 'dart:async';

import 'package:flutter/widgets.dart';

/// Runs [request] for a system prompt that may return before the driver
/// answers, and returns once they have. On iOS permission_handler's
/// "Always" returns at once (its README, WARNING 1) and the library's
/// Motion & Fitness request gives up after about 30 s, both with the prompt
/// still up.
///
/// A prompt takes the app out of the foreground (inactive) and closing it
/// brings the app back (resumed): that return is the answer, whatever it
/// was, including "Keep Only While Using", which changes nothing the
/// library could report. When the app doesn't leave within [appear], no
/// prompt was shown: iOS may skip the upgrade to "Always" without a word.
/// [answer] caps the wait so a lost resume can't hold the flow forever.
///
/// True if a prompt was shown.
Future<bool> untilPromptAnswered(
  Future<void> Function() request, {
  required Stream<AppLifecycleState> lifecycle,
  required AppLifecycleState? Function() current,
  Duration appear = const Duration(seconds: 3),
  Duration answer = const Duration(minutes: 5),
}) async {
  final left = Completer<void>();
  final back = Completer<void>();
  final sub = lifecycle.listen((state) {
    if (state == AppLifecycleState.resumed) {
      if (left.isCompleted && !back.isCompleted) back.complete();
    } else if (!left.isCompleted) {
      left.complete();
    }
  });
  try {
    await request();
    if (!left.isCompleted && current() != AppLifecycleState.resumed) {
      left.complete();
    }
    await left.future.timeout(appear, onTimeout: () {});
    if (!left.isCompleted) return false;
    await back.future.timeout(answer, onTimeout: () {});
    return true;
  } finally {
    await sub.cancel();
  }
}

/// The app's lifecycle as a stream, for [untilPromptAnswered].
Future<T> withLifecycle<T>(
  Future<T> Function(Stream<AppLifecycleState> lifecycle) body,
) async {
  final states = StreamController<AppLifecycleState>.broadcast(sync: true);
  final listener = AppLifecycleListener(onStateChange: states.add);
  try {
    return await body(states.stream);
  } finally {
    listener.dispose();
    await states.close();
  }
}
