import 'package:flutter/foundation.dart';

/// Tracks whether the app has finished starting up; until then the router
/// keeps the splash screen up. The splash stays at least [minSplash] so it
/// doesn't flash by on a fast start.
class AppStartup extends ChangeNotifier {
  AppStartup({this.minSplash = const Duration(milliseconds: 900)});

  final Duration minSplash;

  bool _ready = false;

  bool get ready => _ready;

  Future<void> run(List<Future<void> Function()> tasks) async {
    await Future.wait([
      Future<void>.delayed(minSplash),
      for (final task in tasks) task(),
    ]);
    _ready = true;
    notifyListeners();
  }
}
