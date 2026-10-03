import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import 'tracking_service.dart';

/// Android, the app killed but tracking going on: the library runs this in
/// a bare Dart isolate for each of its events. The only one that needs us
/// is the server's answer to a batch: when it says the load needs no more
/// points, tracking stops here, without waiting for the driver to open the
/// app. (iOS has no such mode: it relaunches the whole app in the
/// background, and the usual listeners hear the answer.)
@pragma('vm:entry-point')
Future<void> trackingHeadlessTask(bg.HeadlessEvent event) async {
  if (event.name != bg.Event.HTTP) return;
  final http = event.event as bg.HttpEvent;
  if (BatchResult.parse(http.status, http.responseText).stopTracking) {
    await bg.BackgroundGeolocation.stop();
  }
}
