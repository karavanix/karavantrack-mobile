import 'package:flutter/foundation.dart';

import '../../../data/repositories/loads_repository.dart';
import '../../../data/services/camera_service.dart';
import '../../../domain/models/load.dart';
import '../../../domain/use_cases/advance_load.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';
import '../../loads/view_models/accept_block.dart';

/// One load in full: details, status history, and the driver's next step
/// with an optional photo.
class LoadDetailsViewModel extends ChangeNotifier {
  LoadDetailsViewModel({
    required this.loadId,
    required this._loads,
    required this._advance,
    required this._camera,
  }) {
    fetch = Command0(() => _loads.fetch(loadId));
    advance = Command0(_advanceLoad);
    _status = _loads.byId(loadId)?.status;
    _loads.addListener(_onLoadsChanged);
    fetch.execute();
  }

  final String loadId;
  final LoadsRepository _loads;
  final AdvanceLoadUseCase _advance;
  final CameraService _camera;

  late final Command0<Load> fetch;
  late final Command0<void> advance;

  LoadStatus? _status;
  String? _photoPath;
  bool _disposed = false;

  /// The latest copy, whichever screen or request brought it.
  Load? get load => _loads.byId(loadId);

  LoadAction? get nextAction => load?.status.nextAction;

  bool get photoAllowed => nextAction?.takesPhoto ?? false;

  AcceptBlock? get acceptBlock => switch (load) {
    final load? => AcceptBlock.of(_loads.active, load),
    null => null,
  };

  /// The photo to send with the next step.
  String? get photoPath => _photoPath;

  Future<void> takePhoto() async {
    final path = await _camera.takePhoto();
    if (path == null || _disposed) return;
    _photoPath = path;
    notifyListeners();
  }

  void removePhoto() {
    _photoPath = null;
    notifyListeners();
  }

  Future<Result<void>> _advanceLoad() async {
    final load = this.load;
    if (load == null) return Result.error(Exception('Load $loadId unknown'));
    final result = await _advance(load, photoPath: _photoPath);
    // Sent with the step: the next step starts without it. After a failed
    // step the driver may retry with the same photo.
    if (result is Ok<void> && !_disposed) {
      _photoPath = null;
    }
    return result;
  }

  /// A list refresh carries no history; when the status moved on that way
  /// (a push, another screen), the history shown would be out of date.
  void _onLoadsChanged() {
    final status = load?.status;
    if (status != null && status != _status) {
      _status = status;
      if (load!.history.isEmpty) fetch.execute();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loads.removeListener(_onLoadsChanged);
    fetch.dispose();
    advance.dispose();
    super.dispose();
  }
}
