import 'dart:async';

import 'package:flutter/widgets.dart';

/// The app coming back to the foreground and leaving it.
class AppLifecycleService {
  final _resumed = StreamController<void>.broadcast();
  final _paused = StreamController<void>.broadcast();
  AppLifecycleListener? _listener;

  Stream<void> get resumed {
    _listen();
    return _resumed.stream;
  }

  Stream<void> get paused {
    _listen();
    return _paused.stream;
  }

  bool get isResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _listen() => _listener ??= AppLifecycleListener(
    onResume: () => _resumed.add(null),
    onPause: () => _paused.add(null),
  );
}
