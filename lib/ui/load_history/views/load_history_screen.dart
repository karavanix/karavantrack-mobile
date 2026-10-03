import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/load.dart';
import '../../../routing/routes.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/load_texts.dart';
import '../../core/themes/app_theme.dart';
import '../../core/ui/load_status_chip.dart';
import '../view_models/load_history_view_model.dart';

/// History screen — dropped off, confirmed, and cancelled loads.
class LoadHistoryScreen extends StatefulWidget {
  const LoadHistoryScreen({super.key, required this.viewModel});

  final LoadHistoryViewModel viewModel;

  @override
  State<LoadHistoryScreen> createState() => _LoadHistoryScreenState();
}

class _LoadHistoryScreenState extends State<LoadHistoryScreen> {
  late final ScrollController _scrollCtrl;

  LoadHistoryViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _vm.loadMore();
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[local.month - 1];
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$m $d, ${local.year}  $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.refresh]),
      builder: (context, child) {
        final loads = _vm.loads;
        final isInitial = _vm.loadingFirstTime;
        final error = _vm.error;

        return Scaffold(
          appBar: AppBar(title: Text(t.history)),
          body: RefreshIndicator(
            onRefresh: _vm.refresh.execute,
            child: isInitial
                ? const CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : loads.isEmpty
                ? _EmptyHistory(
                    message: error != null
                        ? errorText(t, error)
                        : t.noCompletedLoads,
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: loads.length + (_vm.loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == loads.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final load = loads[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(
                          load: load,
                          formatDate: _formatDate,
                          onTap: () =>
                              context.push(Routes.loadDetails(load.id)),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.load,
    required this.formatDate,
    required this.onTap,
  });

  final Load load;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final t = context.l10n;
    final colors = AppTheme.of(context);

    final isCancelled = load.status == LoadStatus.cancelled;
    final date = load.dropoffAt ?? load.updatedAt ?? load.createdAt;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.loadTitle(load),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  LoadStatusChip(status: load.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: colors.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.dropoffAddress.isNotEmpty
                          ? load.dropoffAddress
                          : t.dropoffLocation,
                      style: TextStyle(fontSize: 13, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isCancelled
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    size: 14,
                    color: isCancelled ? colors.destructive : colors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDate(date),
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 52,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
