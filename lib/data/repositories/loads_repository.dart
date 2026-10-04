import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/fix.dart';
import '../../domain/models/load.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../services/api/api_exception.dart';
import '../services/api/loads_api.dart';
import '../services/local_store.dart';

/// The driver's loads: the active one, the pending ones waiting to be
/// accepted, and the history. Every load is kept once, by id, and the lists
/// only point at it, so whichever request brought the latest copy (a list,
/// the active load, a load's details) every screen shows that copy.
///
/// The active load is also saved on the device: a driver who opens the app
/// with no signal still sees the load they're driving.
class LoadsRepository extends ChangeNotifier {
  LoadsRepository({required this._api, required this._store});

  static const pageSize = 15;

  final LoadsApi _api;
  final LocalStore _store;

  final _loads = <String, Load>{};
  String? _activeId;
  bool _activeKnown = false;
  final _pending = _Paged();
  final _history = _Paged();
  Future<Result<void>>? _refreshing;
  Exception? _refreshError;

  /// Bumped by [clear]: answers to requests sent before it are dropped.
  int _epoch = 0;

  /// The load the driver has now (accepted, not yet confirmed).
  Load? get active => switch (_loads[_activeId]) {
    final load? when load.status.isActive => load,
    _ => null,
  };

  /// [active] is the server's word since sign-in, not just the copy saved
  /// on the device or nothing fetched yet. Only then does "no active load"
  /// really mean there's none.
  bool get activeKnown => _activeKnown;

  /// Assigned loads waiting to be accepted, in the server's order.
  List<Load> get pending => [
    for (final id in _pending.ids)
      if (_loads[id] case final load? when load.status == LoadStatus.assigned)
        load,
  ];

  bool get hasMorePending => _pending.hasMore;

  bool get loadingMorePending => _pending.loadingMore;

  /// The pending list has been fetched at least once since sign-in.
  bool get pendingLoaded => _pending.loaded;

  List<Load> get history => [for (final id in _history.ids) ?_loads[id]];

  bool get hasMoreHistory => _history.hasMore;

  bool get loadingMoreHistory => _history.loadingMore;

  bool get historyLoaded => _history.loaded;

  /// Why the last [refresh] failed; null once one succeeds.
  Exception? get refreshError => _refreshError;

  Exception? get historyError => _history.error;

  Load? byId(String id) => _loads[id];

  /// Takes the active load saved on the device, if any. Part of startup,
  /// before anyone listens, so it doesn't notify.
  void restore() {
    final cached = _store.getString(StoreKeys.cachedActiveLoad);
    if (cached == null) return;
    try {
      _activeId = _put(Load.fromJson(jsonDecode(cached)));
    } catch (e, st) {
      log.error('Corrupt cached active load, ignoring', e, st);
    }
  }

  /// Fetches the active load and the first page of pending ones. Calls
  /// made while one is running share it.
  ///
  /// Doesn't notify when it starts, only when done: it may be called while
  /// the widget tree is being built.
  Future<Result<void>> refresh() => _refreshing ??= _refresh();

  Future<Result<void>> _refresh() async {
    final epoch = _epoch;
    final (active, pending) = await (
      _api.active(),
      _reload(_pending, _api.pending),
    ).wait;
    if (epoch != _epoch) return const Result.ok(null);
    if (active case Ok(:final value)) {
      _activeId = value == null ? null : _put(value);
      _activeKnown = true;
    }
    final error = switch ((active, pending)) {
      (Error(:final error), _) || (_, Error(:final error)) => error,
      _ => null,
    };
    if (error != null) log.warning('Loads not refreshed: $error');
    _refreshError = error;
    await _saveActive();
    _refreshing = null;
    notifyListeners();
    return error == null ? const Result.ok(null) : Result.error(error);
  }

  Future<void> loadMorePending() => _loadMore(_pending, _api.pending);

  /// Like [refresh], notifies only when done.
  Future<Result<void>> refreshHistory() async {
    final epoch = _epoch;
    final result = await _reload(_history, _api.history);
    if (epoch == _epoch) notifyListeners();
    return result;
  }

  Future<void> loadMoreHistory() => _loadMore(_history, _api.history);

  /// The load with its status history.
  Future<Result<Load>> fetch(String id) async {
    final epoch = _epoch;
    final result = await _api.get(id);
    if (epoch != _epoch) return result;
    switch (result) {
      case Ok(:final value):
        _put(value);
        if (value.status.isActive) {
          _activeId = value.id;
          _activeKnown = true;
        }
      // Reassigned to someone else or deleted: it's no longer ours.
      case Error(error: HttpException(statusCode: 403 || 404)):
        _forget(id);
      case Error():
        break;
    }
    await _saveActive();
    notifyListeners();
    return result;
  }

  /// Moves the load on to its next status. Whether or not the server
  /// accepted it, the load is fetched again afterwards: on failure the
  /// reason is usually that it changed in the meantime (the shipper
  /// cancelled it), and the driver should see that.
  Future<Result<void>> perform(
    String id,
    LoadAction action, {
    List<String> attachmentIds = const [],
    Fix? location,
  }) async {
    final result = await _api.perform(
      id,
      action,
      attachmentIds: attachmentIds,
      location: location,
    );
    log.info('[loads] ${action.name} $id: $result');
    await (fetch(id), refresh()).wait;
    return result;
  }

  /// Signed out: forgets everything, on the device too.
  Future<void> clear() async {
    _epoch++;
    _loads.clear();
    _activeId = null;
    _activeKnown = false;
    _pending.reset();
    _history.reset();
    _refreshing = null;
    _refreshError = null;
    await _store.remove(StoreKeys.cachedActiveLoad);
    notifyListeners();
  }

  /// Keeps [load] and returns its id. A copy from a list carries no
  /// history; it keeps the one already known while the status is the same.
  String _put(Load load) {
    final known = _loads[load.id];
    _loads[load.id] =
        load.history.isEmpty && known != null && known.status == load.status
        ? load.withHistory(known.history)
        : load;
    return load.id;
  }

  void _forget(String id) {
    _loads.remove(id);
    _pending.ids.remove(id);
    _history.ids.remove(id);
    if (_activeId == id) _activeId = null;
  }

  Future<void> _saveActive() async {
    final load = active;
    if (load == null) {
      await _store.remove(StoreKeys.cachedActiveLoad);
    } else {
      await _store.setString(
        StoreKeys.cachedActiveLoad,
        jsonEncode(load.toJson()),
      );
    }
  }

  /// Fetches the first page again. A page still loading for the old list is
  /// dropped when it arrives.
  Future<Result<void>> _reload(_Paged list, _PageFetch fetch) async {
    final generation = ++list.generation;
    list.loadingMore = false;
    final result = await fetch(limit: pageSize, offset: 0);
    if (generation != list.generation) return const Result.ok(null);
    switch (result) {
      case Ok(value: final page):
        list.ids = [for (final load in page.items) _put(load)];
        list.hasMore = _hasMore(page, list.ids.length);
        list.loaded = true;
        list.error = null;
        return const Result.ok(null);
      case Error(:final error):
        list.error = error;
        return Result.error(error);
    }
  }

  Future<void> _loadMore(_Paged list, _PageFetch fetch) async {
    if (list.loadingMore || !list.hasMore) return;
    final generation = list.generation;
    list.loadingMore = true;
    notifyListeners();
    final result = await fetch(limit: pageSize, offset: list.ids.length);
    if (generation != list.generation) return;
    list.loadingMore = false;
    switch (result) {
      case Ok(value: final page):
        for (final load in page.items) {
          // Offsets shift when a load is added or leaves the list between
          // pages; one already shown isn't repeated.
          if (!list.ids.contains(load.id)) list.ids.add(_put(load));
        }
        list.hasMore = _hasMore(page, list.ids.length);
      case Error(:final error):
        // Scrolling to the end again retries.
        log.warning('Next page not loaded: $error');
    }
    notifyListeners();
  }

  static bool _hasMore(LoadPage page, int shown) =>
      page.items.length == pageSize && shown < page.total;
}

typedef _PageFetch =
    Future<Result<LoadPage>> Function({
      required int limit,
      required int offset,
    });

/// A list fetched page by page.
class _Paged {
  List<String> ids = [];
  bool hasMore = false;
  bool loadingMore = false;
  bool loaded = false;
  Exception? error;

  /// Bumped on every reload.
  int generation = 0;

  void reset() {
    ids = [];
    hasMore = false;
    loadingMore = false;
    loaded = false;
    error = null;
    generation++;
  }
}
