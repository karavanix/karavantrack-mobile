import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/load.dart';
import '../../../routing/routes.dart';
import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/load_texts.dart';
import '../../core/themes/app_theme.dart';
import '../../core/ui/floating_dock.dart';
import '../../core/ui/load_status_chip.dart';
import '../../core/ui/status_pill.dart';
import '../../core/ui/status_stepper.dart';
import '../view_models/accept_block.dart';
import '../view_models/loads_view_model.dart';
import '../widgets/internet_status_banner.dart';
import '../widgets/loads_blocked_overlay.dart';

/// The loads tab: the active load on top, pending loads below.
class LoadsScreen extends StatefulWidget {
  const LoadsScreen({super.key, required this.viewModel});

  final LoadsViewModel viewModel;

  @override
  State<LoadsScreen> createState() => _LoadsScreenState();
}

class _LoadsScreenState extends State<LoadsScreen> {
  late final ScrollController _scrollCtrl;
  bool _showScrollTop = false;

  LoadsViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _vm.advance.addListener(_onAdvanceChanged);
  }

  @override
  void dispose() {
    _vm.advance.removeListener(_onAdvanceChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onAdvanceChanged() {
    if (_vm.advance.result case Error(:final error)) {
      _vm.advance.clearResult();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loadActionErrorText(context.l10n, error))),
      );
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _vm.loadMorePending();
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

  void _openDetails(BuildContext context, String loadId) =>
      context.push(Routes.loadDetails(loadId));

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.advance]),
      builder: (context, child) {
        final vm = _vm;
        final active = vm.active;
        final pending = vm.pending;
        final showInitialSpinner = vm.loadingFirstTime;
        final problem = vm.locationProblem;

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
                  bottom:
                      kDockHeight +
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
            title: Text(t.appName),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: t.history,
                onPressed: () => context.push(Routes.history),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(34),
              child: InternetStatusBanner(online: vm.online),
            ),
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: vm.refresh.execute,
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
                                online: vm.online,
                                advancing: vm.advancing == active.id,
                                onAction: () => vm.advance.execute(active),
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
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
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
                                acceptBlock: vm.acceptBlockFor(load),
                                accepting: vm.advancing == load.id,
                                onAccept: () => vm.advance.execute(load),
                                onTap: () => _openDetails(context, load.id),
                              ),
                            );
                          }, childCount: pending.length),
                        ),
                      ] else if (active != null) ...[
                        // Active load + no pending → inline hint
                        SliverToBoxAdapter(
                          child: _NoPendingHint(error: vm.pendingError),
                        ),
                      ] else ...[
                        // No active + no pending → full empty state
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            error: vm.pendingError,
                            onRefresh: vm.refresh.execute,
                          ),
                        ),
                      ],

                      // ── Pagination loader ─────────────────────────────────
                      if (vm.loadingMorePending && pending.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),

                      if (pending.isNotEmpty &&
                          !vm.loadingMorePending &&
                          !vm.hasMorePending)
                        const SliverToBoxAdapter(child: _EndOfListMarker()),

                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: dockClearance(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (problem != null)
                LoadsBlockedOverlay(
                  problem: problem,
                  onOpenLocationSettings: vm.openLocationSettings,
                  onOpenAppSettings: vm.openAppSettings,
                ),
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
    required this.online,
    required this.advancing,
    required this.onAction,
    required this.onTap,
  });

  final Load load;
  final bool online;
  final bool advancing;
  final VoidCallback onAction;
  final VoidCallback onTap;

  IconData? _actionIcon() => switch (load.status) {
    LoadStatus.accepted => Icons.local_shipping_outlined,
    LoadStatus.pickingUp => Icons.inventory_2_outlined,
    LoadStatus.pickedUp => Icons.route_outlined,
    LoadStatus.inTransit => Icons.flag_outlined,
    LoadStatus.droppingOff => Icons.check_circle_outline,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;
    final colors = AppTheme.of(context);
    final isLoading = advancing;
    final action = load.status.nextAction;
    final actionIcon = _actionIcon();

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
                              t.loadTitle(load),
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
                      LoadStatusChip(status: load.status),
                    ],
                  ),

                  // ── Stepper + status label ──────────────────────────
                  const SizedBox(height: 16),
                  StatusStepper(
                    currentStepIndex: load.status.step ?? -1,
                    compact: true,
                    isAwaitingConfirmation:
                        load.status == LoadStatus.droppedOff,
                  ),

                  // ── Status pills row ────────────────────────────────
                  // GPS and unsent-points pills come with the tracker.
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: online ? t.online : t.offline,
                        color: online ? colors.success : colors.warning,
                      ),
                    ],
                  ),

                  // ── Action button ───────────────────────────────────
                  if (action != null) ...[
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
                                    onPressed: onAction,
                                    icon: Icon(actionIcon, size: 20),
                                    label: Text(t.loadAction(action)),
                                  )
                                : ElevatedButton(
                                    onPressed: onAction,
                                    child: Text(t.loadAction(action)),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.awaitingShipperConfirmation,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Tracking keeps going until the shipper confirms; the
                    // driver should know rather than wonder.
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.trackingUntilConfirmed,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
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
    final t = context.l10n;
    final colors = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 1),
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
                      t.noActiveLoad,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.noActiveLoadSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
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
    final t = context.l10n;
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
                t.pending,
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
    required this.acceptBlock,
    required this.accepting,
    required this.onAccept,
    required this.onTap,
  });

  final Load load;
  final AcceptBlock? acceptBlock;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;
    final colors = AppTheme.of(context);
    final isLoading = accepting;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);

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
                      t.loadTitle(load),
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
                  LoadStatusChip(status: load.status),
                ],
              ),

              // Route line (pickup → dropoff)
              const SizedBox(height: 12),
              _RouteLine(
                pickup: load.pickupAddress.isNotEmpty
                    ? load.pickupAddress
                    : t.pickupLocation,
                dropoff: load.dropoffAddress.isNotEmpty
                    ? load.dropoffAddress
                    : t.dropoffLocation,
                pickupColor: colors.success,
                dropoffColor: colors.destructive,
                textColor: mutedColor,
                connectorColor: colors.border,
              ),

              // Accept-blocked hint (only when assigned + something else active)
              if (load.status == LoadStatus.assigned &&
                  acceptBlock != null) ...[
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
                      child: Text(switch (acceptBlock!) {
                        AcceptBlock.activeLoad => t.acceptBlockedHint,
                        AcceptBlock.awaitingConfirmation =>
                          t.acceptBlockedAwaitingConfirmation,
                      }, style: TextStyle(fontSize: 12, color: colors.warning)),
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
                              valueColor: AlwaysStoppedAnimation(
                                colors.primary,
                              ),
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: acceptBlock != null ? null : onAccept,
                          child: Text(t.acceptLoad),
                        ),
                ),
              ],

              // Awaiting shipper confirmation pill
              if (load.status == LoadStatus.droppedOff) ...[
                const SizedBox(height: 12),
                StatusPill(
                  label: t.awaitingShipperConfirmation,
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
  const _NoPendingHint({required this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final error = this.error;
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
            error != null ? errorText(t, error) : t.noPendingLoads,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state (no active + no pending) ────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.error, required this.onRefresh});

  /// Why the list couldn't be fetched; null when it's really empty.
  final Exception? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final error = this.error;
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
              error != null ? errorText(t, error) : t.noPendingLoads,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.mutedForeground,
              ),
            ),
            if (error == null) ...[
              const SizedBox(height: 6),
              Text(
                t.noActiveLoadSubtitleNew,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.mutedForeground.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(t.refresh),
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
    final t = context.l10n;
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
              t.endOfList,
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
