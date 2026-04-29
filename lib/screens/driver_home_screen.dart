import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/internet_status_banner.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/status_pill.dart';
import '../widgets/status_stepper.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'load_details_screen.dart';

/// Driver home screen — active load panel on top, pending loads below.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key, required this.store});

  final AppStore store;

  void _openDetails(BuildContext context, String loadId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoadDetailsScreen(store: store, loadId: loadId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final active = store.activeLoad;
        final pending = store.pendingLoads;
        final hasAny = active != null || pending.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(t.tr('appName')),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: store.fetchLoads,
                tooltip: t.tr('refresh'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(34),
              child: InternetStatusBanner(store: store),
            ),
          ),
          body: !hasAny
              ? _EmptyState(store: store)
              : CustomScrollView(
                  slivers: [
                    if (active != null)
                      SliverToBoxAdapter(
                        child: _ActiveLoadPanel(
                          load: active,
                          store: store,
                          onTap: () => _openDetails(context, active.id),
                        ),
                      ),

                    if (pending.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                t.tr('pending'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final colors = AppColors.of(context);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${pending.length}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final load = pending[index];
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              index == pending.length - 1 ? 24 : 12,
                            ),
                            child: _PendingLoadCard(
                              load: load,
                              store: store,
                              onTap: () => _openDetails(context, load.id),
                            ),
                          );
                        }, childCount: pending.length),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// ─── Active load panel ───────────────────────────────────────────────────────

class _ActiveLoadPanel extends StatelessWidget {
  const _ActiveLoadPanel({
    required this.load,
    required this.store,
    required this.onTap,
  });

  final LoadItem load;
  final AppStore store;
  final VoidCallback onTap;

  Future<void> _handleAction(BuildContext context, AppStore store) async {
    final key = load.status.nextActionKey;
    if (key == null) return;
    switch (load.status) {
      case LoadStatus.accepted:
        await store.beginPickup(load.id);
        break;
      case LoadStatus.pickingUp:
        await store.confirmPickup(load.id);
        break;
      case LoadStatus.pickedUp:
        await store.startLoad(load.id);
        break;
      case LoadStatus.inTransit:
        await store.beginDropoff(load.id);
        break;
      case LoadStatus.droppingOff:
        await store.confirmDropoff(load.id);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isLoading = store.isLoadingId(load.id);
    final actionKey = load.status.nextActionKey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
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

                if (load.referenceId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    load.referenceId!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],

                // Status stepper
                const SizedBox(height: 14),
                StatusStepper(
                  currentStepIndex: load.status.stepIndex,
                  compact: true,
                  isAwaitingConfirmation: load.status == LoadStatus.droppedOff,
                ),

                // GPS / network pills — hidden when awaiting shipper confirmation
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: store.networkOnline
                          ? t.tr('online')
                          : t.tr('offline'),
                      color: store.networkOnline
                          ? colors.success
                          : colors.warning,
                    ),
                    StatusPill(
                      label: store.lastGpsPosition != null
                          ? 'GPS: ${store.lastGpsPosition!.latitude.toStringAsFixed(4)}, '
                                '${store.lastGpsPosition!.longitude.toStringAsFixed(4)}'
                          : t.tr('gpsWaiting'),
                      color: store.lastGpsPosition != null
                          ? colors.success
                          : colors.warning,
                    ),
                    StatusPill(
                      label:
                          '${t.tr('buffer')}: ${store.offlineBufferCount(load.id)}',
                      color: store.offlineBufferCount(load.id) == 0
                          ? colors.primary
                          : colors.warning,
                    ),
                  ],
                ),

                // Action button
                if (actionKey != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _handleAction(context, store),
                            child: Text(t.tr(actionKey)),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pending load card ────────────────────────────────────────────────────────

class _PendingLoadCard extends StatelessWidget {
  const _PendingLoadCard({
    required this.load,
    required this.store,
    required this.onTap,
  });

  final LoadItem load;
  final AppStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final t = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isLoading = store.isLoadingId(load.id);

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
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: colors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.pickupAddress.isNotEmpty
                          ? load.pickupAddress
                          : t.tr('pickupLocation'),
                      style: TextStyle(fontSize: 13, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
              if (load.status == LoadStatus.assigned) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : OutlinedButton(
                          onPressed: () => store.acceptLoad(load.id),
                          child: Text(t.tr('acceptLoad')),
                        ),
                ),
              ],
              if (load.status == LoadStatus.droppedOff) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 13,
                      color: AppColors.statusDroppedOff,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.tr('awaitingShipperConfirmation'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.statusDroppedOff,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.store});

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
            Icons.inbox_outlined,
            size: 52,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            t.tr('noPendingLoads'),
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
