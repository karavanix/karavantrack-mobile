import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/themes/app_theme.dart';
import 'reference_view_model.dart';

class ReferenceApp extends StatelessWidget {
  const ReferenceApp({super.key, required this.viewModel});

  final ReferenceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Эталон',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: ReferenceScreen(viewModel: viewModel),
    );
  }
}

/// The Эталон: start/stop, what the library is doing, and the export of
/// the drive. Texts are Russian only: it's a tool for test drives, not
/// part of the app.
class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key, required this.viewModel});

  final ReferenceViewModel viewModel;

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with WidgetsBindingObserver {
  ReferenceViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Points were recorded without Dart callbacks while away; and the
    // battery optimisation may have been switched off in the settings.
    if (state == AppLifecycleState.resumed) vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Эталон'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: vm.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Точка каждую секунду, без фильтров, GPS не гаснет до «Стоп». '
              'На сервер ничего не уходит. Держите телефон на зарядке.',
            ),
            const SizedBox(height: 12),
            _startStopButton(),
            const SizedBox(height: 12),
            _statusCard(),
            const SizedBox(height: 12),
            _lastPointCard(),
            const SizedBox(height: 12),
            // Battery optimization and power managers are Android's.
            if (defaultTargetPlatform != TargetPlatform.iOS) ...[
              _energyCard(),
              const SizedBox(height: 12),
            ],
            _journalCard(),
            const SizedBox(height: 12),
            _dataCard(),
          ],
        ),
      ),
    );
  }

  Widget _startStopButton() {
    final running = vm.enabled;
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: running
              ? Colors.red.shade700
              : Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        onPressed: vm.busy
            ? null
            : (running ? vm.stop.execute : vm.start.execute),
        icon: Icon(running ? Icons.stop : Icons.play_arrow),
        label: Text(
          running ? 'Стоп' : 'Старт',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final p = vm.provider;
    return _Section(
      title: 'Состояние',
      children: [
        _Row('Запись', vm.enabled ? 'включена' : 'выключена'),
        _Row('Движение', vm.enabled ? (vm.isMoving ? 'едем' : 'стоим') : '—'),
        _Row(
          'Активность',
          vm.activity == null
              ? '—'
              : '${ReferenceViewModel.activityLabel(vm.activity!)} '
                    '${vm.activityConfidence}%',
        ),
        _Row('GPS', p == null ? '—' : (p.gps ? 'вкл' : 'выкл')),
        _Row(
          'Разрешение',
          ReferenceViewModel.authorizationLabel(p?.authorization),
        ),
        const Divider(),
        _Row('Точек в базе', '${vm.storedCount}'),
      ],
    );
  }

  Widget _lastPointCard() {
    final l = vm.lastLocation;
    if (l == null) {
      return const _Section(title: 'Последняя точка', children: [Text('—')]);
    }
    final c = l.coords;
    final fixAt = DateTime.tryParse(l.timestamp.toString())?.toLocal();
    final interval = vm.lastInterval;
    return _Section(
      title: 'Последняя точка',
      children: [
        _Row('Время фикса', fixAt == null ? '—' : _time(fixAt)),
        _Row(
          'После предыдущей',
          interval == null
              ? '—'
              : '${(interval.inMilliseconds / 1000).toStringAsFixed(1)} с',
        ),
        _Row(
          'Координаты',
          '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}',
        ),
        _Row('Точность', '${c.accuracy.toStringAsFixed(0)} м'),
        _Row(
          'Скорость',
          c.speed < 0 ? '—' : '${(c.speed * 3.6).toStringAsFixed(0)} км/ч',
        ),
        _Row('Событие', l.event.isEmpty ? 'поток' : l.event),
        _Row('Одометр', '${(l.odometer / 1000).toStringAsFixed(2)} км'),
      ],
    );
  }

  Widget _energyCard() {
    final ignoring = vm.ignoringBatteryOptimizations;
    return _Section(
      title: 'Энергосбережение',
      children: [
        _Row(
          'Оптимизация батареи',
          ignoring == null
              ? '—'
              : (ignoring ? 'отключена ✓' : 'ВКЛЮЧЕНА — отключите'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: vm.openBatteryOptimizations,
              child: const Text('Батарея: без ограничений'),
            ),
            OutlinedButton(
              onPressed: vm.openPowerManager,
              child: const Text('Менеджер питания'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _journalCard() {
    return _Section(
      title: 'События',
      children: [
        if (vm.journal.isEmpty) const Text('—'),
        for (final e in vm.journal.take(30))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${_time(e.at)}  ${e.text}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _dataCard() {
    return _Section(
      title: 'Данные',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: vm.busy ? null : vm.exportCsv.execute,
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Экспорт CSV'),
            ),
            OutlinedButton.icon(
              onPressed: vm.busy ? null : vm.exportLog.execute,
              icon: const Icon(Icons.article_outlined),
              label: const Text('Экспорт лога'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: vm.busy ? null : _confirmDestroy,
          child: const Text('Удалить все точки из базы'),
        ),
      ],
    );
  }

  Future<void> _confirmDestroy() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить все точки?'),
        content: Text(
          'В базе ${vm.storedCount} точек. Если заезд ещё не выгружен в CSV, '
          'он пропадёт.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await vm.destroyLocations.execute();
  }

  static String _time(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
