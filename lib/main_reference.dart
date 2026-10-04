// The Эталон: a raw 1 Hz GPS recorder for test drives, measured against
// the production app on a second phone. Records on the phone only; the
// drive goes to gps-lab as a CSV.
//
//   flutter run -t lib/main_reference.dart
//   flutter build apk --debug -t lib/main_reference.dart
//
// Debug builds only: they need no licence key. Same applicationId as the
// app, so it replaces the app on the phone it's installed on, and the two
// share the library's database (the export takes only the Эталон's points).
import 'package:material_ui/material_ui.dart';

import 'reference/reference_recorder.dart';
import 'reference/reference_screen.dart';
import 'reference/reference_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before runApp: the library needs its ready() on every launch, also
  // when the OS starts the app in the background to resume recording.
  final recorder = BgReferenceRecorder();
  final atLaunch = await recorder.ready();
  runApp(
    ReferenceApp(
      viewModel: ReferenceViewModel(recorder: recorder, atLaunch: atLaunch),
    ),
  );
}
