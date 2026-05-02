import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/floating_dock.dart';
import '../widgets/internet_status_banner.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/status_pill.dart';
import '../widgets/status_stepper.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'load_details_screen.dart';
import 'load_history_screen.dart';

/// Driver home screen — active load on top, pending loads below.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  late final ScrollController _scrollCtrl;
  bool _showScrollTop = false;

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
    final shouldShow = _scrollCtrl.position.pixels > 300;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }
  }

  void _scrollToTop() {
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
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
        final showInitialSpinner = store.isInitialFetching && !hasAny;

        return Scaffold(
          floatingActionButton: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: _showScrollTop ? Offset.zero : const Offset(0, 0.3),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showScrollTop ? 1.0 : 0.0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: kDockHeight +
                      kDockBottomMargin +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: FloatingActionButton.small(
                  onPressed: _showScrollTop ? _scrollToTop : null,
                  elevation: 4,
                  child: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          appBar: AppBar(
            title: Text(t.tr('appName')),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
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
          body: RefreshIndicator(
            onRefresh: () async => store.refreshAll(),
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Initial loading spinner (still pull-to-refreshable) ──
                if (showInitialSpinner)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  // ── Active load ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: active != null
                        ? _ActiveLoadPanel(
                            load: active,
                            store: store,
                            onTap: () => _openDetails(context, active.id),
                          )
                        : const _ActiveLoadEmptyState(),
                  ),

                  // ── Pending section ──────────────────────────────────
                  if (pending.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _PendingSectionHeader(count: pending.length),
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
                              onTap: () => _openDetails(context, load.id),
                            ),
                          );
                        },
                        childCount: pending.length,
                      ),
                    ),
                  ] else if (active != null) ...[
                    // Active load + no pending → inline hint
                    const SliverToBoxAdapter(child: _NoPendingHint()),
                  ] else ...[
                    // No active + no pending → full empty state
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(store: store),
                    ),
                  ],

                  // ── Pagination loader ─────────────────────────────────
                  if (store.isFetchingPending && pending.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),

                  if (pending.isNotEmpty &&
                      !store.isFetchingPending &&
                      !store.hasMorePending)
                    const SliverToBoxAdapter(child: _EndOfListMarker()),

                  SliverPadding(
                    padding: EdgeInsets.only(bottom: dockClearance(context)),
                  ),
                ],
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

  IconData? _actionIcon() {
    switch (load.status) {
      case LoadStatus.accepted:
        return Icons.local_shipping_outlined;
      case LoadStatus.pickingUp:
        return Icons.inventory_2_outlined;
      case LoadStatus.pickedUp:
        return Icons.route_outlined;
      case LoadStatus.inTransit:
        return Icons.flag_outlined;
      case LoadStatus.droppingOff:
        return Icons.check_circle_outline;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    final isLoading = store.isLoadingId(load.id);
    final actionKey = load.status.nextActionKey;
    final actionIcon = _actionIcon();
    final hasGps = store.lastGpsPosition != null;
    final bufferCount = store.offlineBufferCount(load.id);
    final fallbackTitle =
        'Load #${load.id.length >= 8 ? load.id.substring(0, 8) : load.id}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colors.primary.withValues(alpha: 0.25),
              width: 1,
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
                  // ── Header: title + reference + status chip ─────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              load.title.isNotEmpty
                                  ? load.title
                                  : fallbackTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (load.referenceId != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                load.referenceId!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      LoadStatusChip(
                        label: load.status.localizedLabel(t),
                        status: load.status.name,
                      ),
                    ],
                  ),

                  // ── Stepper + status label ──────────────────────────
                  const SizedBox(height: 16),
                  StatusStepper(
                    currentStepIndex: load.status.stepIndex,
                    compact: true,
                    isAwaitingConfirmation:
                        load.status == LoadStatus.droppedOff,
                  ),

                  // ── Status pills row ────────────────────────────────
                  const SizedBox(height: 16),
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
                        label: hasGps
                            ? t.tr('gpsActive')
                            : t.tr('gpsSearching'),
                        color: hasGps ? colors.success : colors.warning,
                      ),
                      if (bufferCount > 0)
                        StatusPill(
                          label: '${t.tr('buffer')}: $bufferCount',
                          color: colors.warning,
                        ),
                    ],
                  ),

                  // ── Action button ───────────────────────────────────
                  if (actionKey != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: isLoading
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    colors.primary,
                                  ),
                                ),
                              ),
                            )
                          : (actionIcon != null
                              ? ElevatedButton.icon(
                                  onPressed: () =>
                                      _handleAction(context, store),
                                  icon: Icon(actionIcon, size: 20),
                                  label: Text(t.tr(actionKey)),
                                )
                              : ElevatedButton(
                                  onPressed: () =>
                                      _handleAction(context, store),
                                  child: Text(t.tr(actionKey)),
                                )),
                    ),
                  ],

                  // ── Awaiting shipper confirmation hint ──────────────
                  if (load.status == LoadStatus.droppedOff) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.tr('awaitingShipperConfirmation'),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 22,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
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
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.tr('noActiveLoadSubtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pending section header ──────────────────────────────────────────────────

class _PendingSectionHeader extends StatelessWidget {
  const _PendingSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Divider(
            height: 1,
            color: colors.border.withValues(alpha: 0.6),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Text(
                t.tr('pending'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(count: count),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ─── Pending load card ───────────────────────────────────────────────────────

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
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    final isLoading = store.isLoadingId(load.id);
    final hasActiveLoad = store.activeLoad != null;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final fallbackTitle =
        'Load #${load.id.length >= 8 ? load.id.substring(0, 8) : load.id}';

    return Card(
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
                      load.title.isNotEmpty ? load.title : fallbackTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.2,
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
                ],
              ),

              // Route line (pickup → dropoff)
              const SizedBox(height: 12),
              _RouteLine(
                pickup: load.pickupAddress.isNotEmpty
                    ? load.pickupAddress
                    : t.tr('pickupLocation'),
                dropoff: load.dropoffAddress.isNotEmpty
                    ? load.dropoffAddress
                    : t.tr('dropoffLocation'),
                pickupColor: colors.success,
                dropoffColor: colors.destructive,
                textColor: mutedColor,
                connectorColor: colors.border,
              ),

              // Accept-blocked hint (only when assigned + something else active)
              if (load.status == LoadStatus.assigned && hasActiveLoad) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.tr('acceptBlockedHint'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Accept button
              if (load.status == LoadStatus.assigned) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: isLoading
                      ? Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(colors.primary),
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: hasActiveLoad
                              ? null
                              : () => store.acceptLoad(load.id),
                          child: Text(t.tr('acceptLoad')),
                        ),
                ),
              ],

              // Awaiting shipper confirmation pill
              if (load.status == LoadStatus.droppedOff) ...[
                const SizedBox(height: 12),
                StatusPill(
                  label: t.tr('awaitingShipperConfirmation'),
                  color: colors.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Route line widget ───────────────────────────────────────────────────────

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.pickup,
    required this.dropoff,
    required this.pickupColor,
    required this.dropoffColor,
    required this.textColor,
    required this.connectorColor,
  });

  final String pickup;
  final String dropoff;
  final Color pickupColor;
  final Color dropoffColor;
  final Color textColor;
  final Color connectorColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical timeline: pickup dot → connector → dropoff dot
        SizedBox(
          width: 12,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: pickupColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: connectorColor,
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dropoffColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                dropoff,
                style: TextStyle(fontSize: 13, color: textColor, height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── No-pending hint (active load is present, but list is empty) ────────────

class _NoPendingHint extends StatelessWidget {
  const _NoPendingHint();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 32,
            color: colors.mutedForeground.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            t.tr('noPendingLoads'),
            style: TextStyle(
              fontSize: 13,
              color: colors.mutedForeground,
            ),
          ),
        ],
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
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: colors.mutedForeground.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              t.tr('noPendingLoads'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.tr('noActiveLoadSubtitleNew'),
              style: TextStyle(
                fontSize: 13,
                color: colors.mutedForeground.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => store.refreshAll(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(t.tr('refresh')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── End-of-list marker (shown after last pending card on final page) ────────

class _EndOfListMarker extends StatelessWidget {
  const _EndOfListMarker();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    final lineColor = colors.mutedForeground.withValues(alpha: 0.25);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              t.tr('endOfList'),
              style: TextStyle(
                fontSize: 12,
                color: colors.mutedForeground.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, height: 1)),
        ],
      ),
    );
  }
}
