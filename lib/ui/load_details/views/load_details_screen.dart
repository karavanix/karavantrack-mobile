import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../data/services/api/api_exception.dart';
import '../../../domain/models/load.dart';
import '../../../utils/formatters.dart';
import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/load_texts.dart';
import '../../core/themes/app_theme.dart';
import '../../core/ui/info_row.dart';
import '../../core/ui/load_status_chip.dart';
import '../../core/ui/status_stepper.dart';
import '../view_models/load_details_view_model.dart';

/// Detail view for any load — shows full stepper, info, inline action, and history.
class LoadDetailsScreen extends StatefulWidget {
  const LoadDetailsScreen({super.key, required this.viewModel});

  final LoadDetailsViewModel viewModel;

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  LoadDetailsViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.advance.addListener(_onAdvanceChanged);
  }

  @override
  void dispose() {
    _vm.advance.removeListener(_onAdvanceChanged);
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

  String _relativeTime(BuildContext context, DateTime dt) {
    final t = context.l10n;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return t.justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}${t.minutesAgoShort}';
    if (diff.inDays < 1) return '${diff.inHours}${t.hoursAgoShort}';
    return '${diff.inDays}${t.daysAgoShort}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;
    final colors = AppTheme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.fetch, _vm.advance]),
      builder: (context, child) {
        final load = _vm.load;

        if (load == null) {
          return Scaffold(
            appBar: AppBar(title: Text(t.load)),
            body: _vm.fetch.running
                ? const Center(child: CircularProgressIndicator())
                : _NotLoaded(
                    error: switch (_vm.fetch.result) {
                      Error(:final error) => error,
                      _ => null,
                    },
                    onRetry: _vm.fetch.execute,
                  ),
          );
        }

        final isLoading = _vm.advance.running;
        final uploadingPhoto = isLoading && _vm.photoPath != null;
        final action = _vm.nextAction;
        // Confirmed shows every step done; cancelled and the statuses
        // before accepting have no stepper.
        final displayStep = load.status.step;
        final historyToShow = load.history;
        final historyLoading = _vm.fetch.running && historyToShow.isEmpty;

        return Scaffold(
          appBar: AppBar(title: Text(t.loadTitle(load))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Header card ──────────────────────────────────────────
              Card(
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
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          LoadStatusChip(status: load.status),
                        ],
                      ),
                      if (load.referenceId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          load.referenceId!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── Status stepper ───────────────────────────────────────
              if (displayStep != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: StatusStepper(
                      currentStepIndex: displayStep,
                      compact: false,
                      isAwaitingConfirmation:
                          load.status == LoadStatus.droppedOff,
                    ),
                  ),
                ),
              ],

              // ─── Awaiting confirmation banner ─────────────────────────
              if (load.status == LoadStatus.droppedOff) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.statusDroppedOff.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.statusDroppedOff.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        color: AppColors.statusDroppedOff,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.awaitingShipperConfirmation,
                              style: TextStyle(
                                color: AppColors.statusDroppedOff,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.awaitingConfirmationDetail,
                              style: TextStyle(
                                color: AppColors.statusDroppedOff.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.trackingUntilConfirmed,
                              style: TextStyle(
                                color: AppColors.statusDroppedOff.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── Info card ────────────────────────────────────────────
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.details,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoRow(label: t.pickup, value: load.pickupAddress),
                      InfoRow(label: t.dropoff, value: load.dropoffAddress),
                      if (load.description.isNotEmpty)
                        InfoRow(label: t.description, value: load.description),
                      if (load.pickupAt != null)
                        InfoRow(
                          label: t.pickupTime,
                          value: formatDateTime(load.pickupAt),
                        ),
                      if (load.dropoffAt != null)
                        InfoRow(
                          label: t.dropoffTime,
                          value: formatDateTime(load.dropoffAt),
                        ),
                      InfoRow(
                        label: t.created,
                        value: formatDateTime(load.createdAt),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Optional POD photo ───────────────────────────────────
              if (action != null) ...[
                const SizedBox(height: 16),
                if (uploadingPhoto)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.podUploadingPhoto,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      if (_vm.photoPath case final photo?) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photo),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: isLoading ? null : _vm.removePhoto,
                          tooltip: t.podRemovePhoto,
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : _vm.takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text(t.podAddPhoto),
                        ),
                    ],
                  ),
              ],

              // ─── Action button ────────────────────────────────────────
              if (action != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _vm.acceptBlock != null
                              ? null
                              : _vm.advance.execute,
                          child: Text(t.loadAction(action)),
                        ),
                ),
              ],

              // ─── Status history ───────────────────────────────────────
              if (historyToShow.isNotEmpty || historyLoading) ...[
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: Text(
                      t.statusHistory,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    initiallyExpanded: true,
                    children: [
                      if (historyLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        for (final item in historyToShow.reversed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t.loadStatus(item.from)} → ${t.loadStatus(item.to)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _relativeTime(context, item.at),
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
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

/// The load couldn't be fetched: gone (not ours any more) or no network.
class _NotLoaded extends StatelessWidget {
  const _NotLoaded({required this.error, required this.onRetry});

  final Exception? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final gone = switch (error) {
      HttpException(statusCode: 403 || 404) || null => true,
      _ => false,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gone ? t.loadNotFound : errorText(t, error!),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (!gone) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text(t.tryAgain)),
            ],
          ],
        ),
      ),
    );
  }
}
