import 'package:flutter/foundation.dart';

import '../../../data/repositories/connectivity_repository.dart';
import '../../../data/repositories/loads_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../domain/models/load.dart';
import '../../../domain/models/location_state.dart';
import '../../../domain/use_cases/advance_load.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';
import 'accept_block.dart';

/// The loads tab: the active load with its next step, and the pending
/// loads below it.
class LoadsViewModel extends ChangeNotifier {
  LoadsViewModel({
    required this._loads,
    required this._location,
    required this._connectivity,
    required this._advance,
  }) {
    refresh = Command0(_loads.refresh);
    advance = Command1(_advanceLoad);
    _loads.addListener(notifyListeners);
    _location.addListener(notifyListeners);
    _connectivity.addListener(notifyListeners);
  }

  final LoadsRepository _loads;
  final LocationRepository _location;
  final ConnectivityRepository _connectivity;
  final AdvanceLoadUseCase _advance;

  late final Command0<void> refresh;

  /// The next step of a load: accept for a pending one, the stepper's
  /// next status for the active one.
  late final Command1<void, Load> advance;
  String? _advancing;

  Load? get active => _loads.active;

  List<Load> get pending => _loads.pending;

  bool get hasMorePending => _loads.hasMorePending;

  bool get loadingMorePending => _loads.loadingMorePending;

  /// First fetch, nothing to show yet.
  bool get loadingFirstTime =>
      !_loads.pendingLoaded && _loads.refreshError == null && active == null;

  /// The pending list couldn't be fetched at all, so "no pending loads"
  /// would be a guess.
  Exception? get pendingError =>
      _loads.pendingLoaded ? null : _loads.refreshError;

  bool get online => _connectivity.online;

  LocationProblem? get locationProblem => _location.state.problem;

  /// The load whose step is being sent, for its spinner.
  String? get advancing => advance.running ? _advancing : null;

  AcceptBlock? acceptBlockFor(Load load) => AcceptBlock.of(active, load);

  void loadMorePending() => _loads.loadMorePending();

  void openLocationSettings() => _location.openLocationSettings();

  void openAppSettings() => _location.openAppSettings();

  Future<Result<void>> _advanceLoad(Load load) {
    _advancing = load.id;
    return _advance(load);
  }

  @override
  void dispose() {
    _loads.removeListener(notifyListeners);
    _location.removeListener(notifyListeners);
    _connectivity.removeListener(notifyListeners);
    refresh.dispose();
    advance.dispose();
    super.dispose();
  }
}
