import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

import '../utils/command.dart';
import '../utils/result.dart';
import 'csv_export.dart';
import 'reference_recorder.dart';

/// A line of the event journal on the screen.
class JournalEntry {
  const JournalEntry(this.at, this.text);
  final DateTime at;
  final String text;
}

/// The Эталон screen's state. The points themselves live in the library's
/// database; here is only what the screen shows. While the screen is in
/// the background no Dart callbacks come, so the counters are re-read from
/// the database on [refresh].
class ReferenceViewModel extends ChangeNotifier {
  ReferenceViewModel({
    required this._recorder,
    required RecorderState atLaunch,
    this._clock = DateTime.now,
  }) : enabled = atLaunch.enabled,
       isMoving = atLaunch.isMoving {
    start = Command0(() => _act(_start));
    stop = Command0(() => _act(_stop));
    exportCsv = Command0(() => _act(_exportCsv));
    exportLog = Command0(() => _act(_exportLog));
    destroyLocations = Command0(() => _act(_destroy));
    for (final c in _commands) {
      c.addListener(notifyListeners);
    }
    _events = _recorder.events.listen(_onEvent);
    _log(
      'ready: запись ${enabled ? 'уже идёт' : 'выключена'}'
      '${atLaunch.launchedInBackground ? ' (запуск в фоне)' : ''}',
    );
    unawaited(refresh());
  }

  static const _maxJournal = 100;

  final ReferenceRecorder _recorder;
  final DateTime Function() _clock;
  late final StreamSubscription<RecorderEvent> _events;
  bool _acting = false;
  bool _disposed = false;

  bool enabled;
  bool isMoving;
  String? activity;
  int activityConfidence = 0;
  bg.Location? lastLocation;

  /// Between the fixes of the last two points: about a second while the
  /// stream is healthy, anything longer is a hole.
  Duration? lastInterval;

  int storedCount = 0;
  ProviderStatus? provider;
  bool? ignoringBatteryOptimizations;
  final journal = <JournalEntry>[];

  late final Command0<void> start;
  late final Command0<void> stop;
  late final Command0<void> exportCsv;
  late final Command0<void> exportLog;
  late final Command0<void> destroyLocations;

  List<Command<void>> get _commands => [
    start,
    stop,
    exportCsv,
    exportLog,
    destroyLocations,
  ];

  /// One action at a time: an export while stopping makes no sense.
  bool get busy => _commands.any((c) => c.running);

  /// Re-reads what may have changed while the screen was away: the point
  /// count, the GPS and permission, the battery optimisation.
  Future<void> refresh() async {
    try {
      storedCount = await _recorder.count();
      provider = await _recorder.provider();
      ignoringBatteryOptimizations = await _recorder
          .ignoringBatteryOptimizations();
    } on Exception catch (e) {
      _log('ошибка: $e');
    }
    notifyListeners();
  }

  Future<void> openBatteryOptimizations() => _openSettings(
    _recorder.showBatteryOptimizations,
    'Настройки → Приложения → YoolLive → Батарея',
  );

  /// The library doesn't know every firmware's screen: on Honor LLY-LX1
  /// (MagicOS, Android 14) it finds none.
  Future<void> openPowerManager() => _openSettings(
    _recorder.showPowerManager,
    'Настройки → Батарея → Запуск приложений → YoolLive → '
    'Управлять вручную (включить все переключатели). '
    'Xiaomi: Настройки → Приложения → YoolLive → Автозапуск + '
    'Контроль активности «Нет ограничений»',
  );

  Future<void> _start() async {
    final state = await _recorder.start();
    enabled = state.enabled;
    isMoving = state.isMoving;
    lastInterval = null;
    _log('старт');
  }

  Future<void> _stop() async {
    final state = await _recorder.stop();
    enabled = state.enabled;
    isMoving = false;
    _log('стоп');
  }

  Future<void> _exportCsv() async {
    final csv = buildReferenceCsv(await _recorder.readAll());
    final name = referenceFileName(
      'reference',
      await _recorder.deviceModel(),
      _clock(),
      'csv',
    );
    await _recorder.share(name, csv.content, 'text/csv');
    _log(
      'CSV $name: ${csv.rows} строк; отброшено проб ${csv.samplesSkipped}, '
      'дублей ${csv.duplicatesMerged}, чужих точек ${csv.foreignSkipped}',
    );
  }

  Future<void> _exportLog() async {
    final name = referenceFileName(
      'bglog',
      await _recorder.deviceModel(),
      _clock(),
      'txt',
    );
    await _recorder.share(name, await _recorder.log(), 'text/plain');
    _log('лог $name');
  }

  Future<void> _destroy() async {
    await _recorder.destroyLocations();
    lastLocation = null;
    lastInterval = null;
    _log('точки в базе удалены');
  }

  Future<Result<void>> _act(Future<void> Function() action) async {
    // Each command only guards against itself; the buttons are disabled
    // while [busy], and this covers what gets past them.
    if (_acting) return Result.error(_Busy());
    _acting = true;
    try {
      await action();
      return const Result.ok(null);
    } on Exception catch (e) {
      _log('ошибка: $e');
      return Result.error(e);
    } finally {
      _acting = false;
      await refresh();
    }
  }

  Future<void> _openSettings(
    Future<void> Function() show,
    String manualHint,
  ) async {
    try {
      await show();
    } on Exception {
      _log('экран не найден, вручную: $manualHint');
      notifyListeners();
    }
  }

  void _onEvent(RecorderEvent event) {
    switch (event) {
      case LocationRecorded(:final location):
        final at = _fixTime(location);
        final previous = lastLocation == null ? null : _fixTime(lastLocation!);
        if (at != null && previous != null) {
          lastInterval = at.difference(previous);
        }
        lastLocation = location;
        storedCount++;
      case LocationFailed(:final message):
        _log('ошибка локации $message');
      case MotionChanged(:final moving):
        isMoving = moving;
        _log(moving ? '▶ едем' : '■ стоим');
      case ActivityChanged(:final type, :final confidence):
        activity = type;
        activityConfidence = confidence;
        _log('активность: ${activityLabel(type)} $confidence%');
      case ProviderChanged(provider: final p):
        provider = p;
        _log(
          'GPS ${p.gps ? 'вкл' : 'выкл'}, '
          'разрешение: ${authorizationLabel(p.authorization)}',
        );
      case EnabledChanged(enabled: final on):
        enabled = on;
        _log('запись ${on ? 'включена' : 'выключена'}');
    }
    notifyListeners();
  }

  void _log(String text) {
    journal.insert(0, JournalEntry(_clock(), text));
    if (journal.length > _maxJournal) journal.removeLast();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    for (final c in _commands) {
      c.dispose();
    }
    super.dispose();
  }

  static DateTime? _fixTime(bg.Location l) =>
      DateTime.tryParse(l.timestamp.toString());

  static String activityLabel(String type) => switch (type) {
    'still' => 'стоит',
    'on_foot' => 'пешком',
    'walking' => 'идёт',
    'running' => 'бежит',
    'in_vehicle' => 'в машине',
    'on_bicycle' => 'велосипед',
    _ => type,
  };

  static String authorizationLabel(int? status) => switch (status) {
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS => 'всегда',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE =>
      'только при использовании',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED => 'запрещено',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED_ALWAYS =>
      'запрещено навсегда',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED =>
      'не спрашивали',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED => 'ограничено',
    null => '—',
    _ => 'код $status',
  };
}

/// Another action is under way.
class _Busy implements Exception {}
