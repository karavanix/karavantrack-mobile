import 'package:flutter/foundation.dart';

import '../../../data/repositories/loads_repository.dart';
import '../../../domain/models/load.dart';
import '../../../utils/command.dart';

/// Dropped off, confirmed and cancelled loads.
class LoadHistoryViewModel extends ChangeNotifier {
  LoadHistoryViewModel({required this._loads}) {
    refresh = Command0(_loads.refreshHistory)..execute();
    _loads.addListener(notifyListeners);
  }

  final LoadsRepository _loads;

  late final Command0<void> refresh;

  List<Load> get loads => _loads.history;

  bool get hasMore => _loads.hasMoreHistory;

  bool get loadingMore => _loads.loadingMoreHistory;

  bool get loadingFirstTime => !_loads.historyLoaded && refresh.running;

  /// The list couldn't be fetched at all.
  Exception? get error => _loads.historyLoaded ? null : _loads.historyError;

  void loadMore() => _loads.loadMoreHistory();

  @override
  void dispose() {
    _loads.removeListener(notifyListeners);
    refresh.dispose();
    super.dispose();
  }
}
