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
import 'load_history_screen.dart';

/// Driver home screen — active load panel on top, pending loads below.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late final ScrollController _scrollCtrl;

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
      widget.store.loadMorePending();
    }
  }

  void _openDetails(BuildContext context, String loadId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LoadDetailsScreen(store: widget.store, loadId: loadId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
        final store = widget.store;
        final active = store.activeLoad;
        final pending = store.pendingLoads;
        final hasAny = active != null || pending.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(t.tr('appName')),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_outlined),
                tooltip: t.tr('history'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoadHistoryScreen(store: store),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(34),
              child: InternetStatusBanner(store: store),
            ),
          ),
          body: store.isInitialFetching && !hasAny
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => store.refreshAll(),
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    slivers: [
                      // Active load section — always shown, collapses when scrolling
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _ActiveLoadHeaderDelegate(
                          expandedHeight: active != null ? 220.0 : 88.0,
                          collapsedHeight: 56.0,
                          scrollController: _scrollCtrl,
                          expandedChild: active != null
                              ? _ActiveLoadPanel(
                                  load: active,
                                  store: store,
                                  onTap: () =>
                                      _openDetails(context, active.id),
                                )
                              : const _ActiveLoadEmptyState(),
                          collapsedChild: active != null
                              ? _ActiveLoadCollapsed(load: active)
                              : const _ActiveLoadEmptyCollapsed(),
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
                                    final colors = AppTheme.of(context);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
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
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
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
                                  onTap: () =>
                                      _openDetails(context, load.id),
                                ),
                              );
                            },
                            childCount: pending.length,
                          ),
                        ),
                      ],

                      // Pagination loading footer
                      if (store.isFetchingPending)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),

                      // Bottom padding / global empty state
                      if (!store.isInitialFetching && !hasAny)
                        SliverFillRemaining(
                          child: _EmptyState(store: store),
                        )
                      else
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                    ],
                  ),
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
    final colors = AppTheme.of(context);
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
                            : 'Load #${load.id.length >= 8 ? load.id.substring(0, 8) : load.id}',
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
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],

                // Status stepper
                const SizedBox(height: 14),
                StatusStepper(
                  currentStepIndex: load.status.stepIndex,
                  compact: true,
                  isAwaitingConfirmation:
                      load.status == LoadStatus.droppedOff,
                ),

                // GPS / network pills
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

// ─── Collapsible header delegate ─────────────────────────────────────────────

class _ActiveLoadHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ActiveLoadHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.expandedChild,
    required this.collapsedChild,
    required this.scrollController,
  });

  final double expandedHeight;
  final double collapsedHeight;
  final Widget expandedChild;
  final Widget collapsedChild;
  final ScrollController scrollController;

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final showCollapsed = t > 0.5;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: showCollapsed,
          child: Opacity(
            opacity: (1.0 - t * 2).clamp(0.0, 1.0),
            child: expandedChild,
          ),
        ),
        IgnorePointer(
          ignoring: !showCollapsed,
          child: Opacity(
            opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
            child: showCollapsed
                ? GestureDetector(
                    onTap: () => scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    child: collapsedChild,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_ActiveLoadHeaderDelegate old) => true;
}

// ─── Collapsed active load bar ────────────────────────────────────────────────

class _ActiveLoadCollapsed extends StatelessWidget {
  const _ActiveLoadCollapsed({required this.load});

  final LoadItem load;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Material(
      color: theme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping,
              size: 16,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                load.title.isNotEmpty
                    ? load.title
                    : 'Load #${load.id.length >= 8 ? load.id.substring(0, 8) : load.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            LoadStatusChip(
              label: load.status.localizedLabel(t),
              status: load.status.name,
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Collapsed active load empty bar ─────────────────────────────────────────

class _ActiveLoadEmptyCollapsed extends StatelessWidget {
  const _ActiveLoadEmptyCollapsed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Material(
      color: theme.cardColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Text(
              t.tr('noActiveLoad'),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active load empty state ─────────────────────────────────────────────────

class _ActiveLoadEmptyState extends StatelessWidget {
  const _ActiveLoadEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 32,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('noActiveLoad'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.tr('noActiveLoadSubtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ],
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
    final colors = AppTheme.of(context);
    final isLoading = store.isLoadingId(load.id);
    final hasActiveLoad = store.activeLoad != null;

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
                          : 'Load #${load.id.length >= 8 ? load.id.substring(0, 8) : load.id}',
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
                          onPressed: hasActiveLoad
                              ? null
                              : () => store.acceptLoad(load.id),
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

// ─── Empty state (no active + no pending) ────────────────────────────────────

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
        ],
      ),
    );
  }
}
