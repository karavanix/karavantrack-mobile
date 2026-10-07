import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/location_state.dart';
import '../../utils/logger.dart';
import '../services/location_status_service.dart';

/// Location access for tracking: the current state of the phone's settings
/// and the flow that asks for "Allow all the time" and physical activity.
///
/// Google Play wants the request in context, behind our own disclosure, at
/// the moment the feature is about to be used: that's when the signed-in
/// driver with a complete profile first reaches the app. On iOS there's no
/// disclosure: [requestAccess] gets a consent that is always given.
///
/// Nothing here sends the driver to the settings on its own: Apple rejects
/// that after "Don't Allow" (5.1.1(iv), 06.10.2026). The blocking overlay
/// on the loads screen does it when the driver asks.
class LocationRepository extends ChangeNotifier {
  LocationRepository({
    required this._service,
    this.pollInterval = const Duration(seconds: 2),
  }) {
    _changes = _service.changes.listen((_) => check());
  }

  final LocationStatusService _service;
  late final StreamSubscription<void> _changes;

  /// How often [watch] re-reads the settings. The library reports changes
  /// itself; the poll is there in case it stays quiet while tracking is
  /// off.
  final Duration pollInterval;

  LocationState _state = LocationState.assumedFine;
  bool _flowRunning = false;
  bool _disclosureShown = false;
  bool _motionAsked = false;
  bool _promptsDone = false;
  Timer? _poll;

  LocationState get state => _state;

  /// The disclosure and system prompts are over for this session. The
  /// notification prompt waits for this so it can't cover them.
  bool get promptsDone => _promptsDone;

  Future<void> check() async => _set(await _service.read());

  /// Asks for "Allow all the time" if it's missing: first [askConsent]
  /// (our disclosure, true for "Allow"), then the system prompts. Then
  /// physical activity, which the disclosure covers too.
  ///
  /// Each request returns once its prompt is answered, so the prompts come
  /// one at a time and [promptsDone] only after the last one.
  ///
  /// Each system prompt pauses and resumes the app, and a resume may call
  /// this again: a second call while one runs does nothing. The disclosure
  /// is shown at most once per sign-in; after "Not now" or a refusal at a
  /// system prompt the blocking overlay explains what's missing. Physical activity is asked once per
  /// sign-in too, and a refusal blocks nothing: tracking just wakes up
  /// later after a stop.
  Future<void> requestAccess(Future<bool> Function() askConsent) async {
    if (_flowRunning) return;
    _flowRunning = true;
    try {
      var state = await _service.read();
      _set(state);
      var consent = state.access == LocationAccess.always;
      if (!consent && !_disclosureShown) {
        _disclosureShown = true;
        consent = await askConsent();
        var access = state.access;
        if (consent) {
          // The access each prompt ended with, not a read(): right after a
          // prompt the library may still report the old one on iOS.
          if (access == LocationAccess.denied) {
            access = await _service.requestWhileInUse();
          }
          if (access == LocationAccess.whileInUse) {
            access = await _service.requestAlways();
          }
        }
        final now = await _service.read();
        state = consent
            ? LocationState(
                serviceEnabled: now.serviceEnabled,
                access: access,
                precise: now.precise,
              )
            : now;
        _set(state);
      }
      if (consent && !_motionAsked && state.access != LocationAccess.denied) {
        _motionAsked = true;
        await _service.requestMotion();
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
    _motionAsked = false;
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
    _changes.cancel();
    super.dispose();
  }
}
