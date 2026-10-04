import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/location_state.dart';
import '../../utils/logger.dart';
import '../services/location_status_service.dart';

/// Location access for tracking: the current state of the phone's settings
/// and the flow that asks for "Allow all the time".
///
/// Google Play wants the request in context, behind our own disclosure, at
/// the moment the feature is about to be used: that's when the signed-in
/// driver with a complete profile first reaches the app.
class LocationRepository extends ChangeNotifier {
  LocationRepository({
    required this._service,
    this.pollInterval = const Duration(seconds: 2),
  });

  final LocationStatusService _service;

  /// How often [watch] re-reads the settings. The phone doesn't tell us
  /// when GPS is switched off; the tracking library will (step 6).
  final Duration pollInterval;

  LocationState _state = LocationState.assumedFine;
  bool _flowRunning = false;
  bool _disclosureShown = false;
  bool _promptsDone = false;
  Timer? _poll;

  LocationState get state => _state;

  /// The disclosure and system prompts are over for this session. The
  /// notification prompt waits for this so it can't cover them.
  bool get promptsDone => _promptsDone;

  Future<void> check() async => _set(await _service.read());

  /// Asks for "Allow all the time" if it's missing: first [askConsent]
  /// (our disclosure, true for "Allow"), then the system prompts.
  ///
  /// Each system prompt pauses and resumes the app, and a resume may call
  /// this again: a second call while one runs does nothing. The disclosure
  /// is shown at most once per sign-in; after "Not now" the blocking
  /// overlay explains what's missing.
  Future<void> requestAccess(Future<bool> Function() askConsent) async {
    if (_flowRunning) return;
    _flowRunning = true;
    try {
      var state = await _service.read();
      _set(state);
      if (state.access != LocationAccess.always && !_disclosureShown) {
        _disclosureShown = true;
        if (await askConsent()) {
          if (state.access == LocationAccess.denied) {
            await _service.requestWhileInUse();
            state = await _service.read();
          }
          if (state.access == LocationAccess.whileInUse) {
            await _service.requestAlways();
          }
        }
        _set(await _service.read());
      }
    } catch (e, st) {
      log.error('Location permission flow failed', e, st);
    } finally {
      _flowRunning = false;
      if (!_promptsDone) {
        _promptsDone = true;
        notifyListeners();
      }
    }
  }

  /// Re-reads the settings every [pollInterval] while [on] (the loads
  /// screen is up and the app in the foreground).
  void watch(bool on) {
    _poll?.cancel();
    _poll = on ? Timer.periodic(pollInterval, (_) => check()) : null;
  }

  Future<void> openAppSettings() => _service.openAppSettings();

  Future<void> openLocationSettings() => _service.openLocationSettings();

  /// Signed out: the next driver gets the disclosure again.
  void reset() {
    watch(false);
    _disclosureShown = false;
    _promptsDone = false;
    _state = LocationState.assumedFine;
    notifyListeners();
  }

  void _set(LocationState state) {
    if (state == _state) return;
    log.info('[location] $state');
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
