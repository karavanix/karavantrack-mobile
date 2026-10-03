import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Whether the phone is online. Assumed online until told otherwise, so
/// the offline banner doesn't flash at startup.
class ConnectivityRepository extends ChangeNotifier {
  ConnectivityRepository({required ConnectivityService service}) {
    _sub = service.online().listen((online) {
      if (online == _online) return;
      _online = online;
      notifyListeners();
    });
  }

  late final StreamSubscription<bool> _sub;
  bool _online = true;

  bool get online => _online;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
