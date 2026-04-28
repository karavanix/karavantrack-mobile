import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/load_status_chip.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'load_details_screen.dart';

/// History screen — completed, confirmed, and cancelled loads.
class LoadHistoryScreen extends StatelessWidget {
  const LoadHistoryScreen({super.key, required this.store});

  final AppStore store;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[local.month - 1];
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$m $d, ${local.year}  $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final loads = store.finishedLoads;

        return Scaffold(
          appBar: AppBar(
            title: Text(t.tr('history')),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: store.fetchLoads,
                tooltip: t.tr('refresh'),
              ),
            ],
          ),
          body: loads.isEmpty
              ? _EmptyHistory(store: store)
              : RefreshIndicator(
                  onRefresh: store.fetchLoads,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: loads.length,
                    itemBuilder: (context, index) {
                      final load = loads[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(
                          load: load,
                          formatDate: _formatDate,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LoadDetailsScreen(store: store, loadId: load.id),
                            ),
                          ),
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

  final LoadItem load;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);

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
                      load.title.isNotEmpty
                          ? load.title
                          : 'Load #${load.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  LoadStatusChip(
                    label: load.status.localizedLabel(t),
                    status: load.status.name,
                  ),
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
                          : t.tr('dropoffLocation'),
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
                    isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
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
  const _EmptyHistory({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 52,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            t.tr('noCompletedLoads'),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: store.fetchLoads,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(t.tr('refresh')),
          ),
        ],
      ),
    );
  }
}
