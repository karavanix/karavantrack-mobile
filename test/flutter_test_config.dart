import 'dart:async';

import 'package:driver_tracking_app/utils/logger.dart';

/// Runs before every test file: keeps the app log out of the test output.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  log.disable();
  await testMain();
}
