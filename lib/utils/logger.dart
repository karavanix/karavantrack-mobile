import 'package:talker_flutter/talker_flutter.dart';

/// App-wide log. Also feeds the in-app log viewer (TalkerScreen) in
/// settings, which is how logs are read off a driver's phone.
final Talker log = TalkerFlutter.init();
