import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/load.dart';
import '../services/api_service.dart';
import '../store/app_store.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/info_row.dart';
import '../widgets/status_stepper.dart';
import '../utils/formatters.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Detail view for any load — shows full stepper, info, inline action, and history.
class LoadDetailsScreen extends StatefulWidget {
  const LoadDetailsScreen({
    super.key,
    required this.store,
    required this.loadId,
  });

  final AppStore store;
  final String loadId;

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  List<LoadHistoryItem> _history = [];
  bool _historyLoading = false;

  // ─── Optional POD photo (see phase-5-product-features) ──────────────────
  // Attachable to any driver action, never required. Uploaded synchronously
  // before the status-change request fires — "ждём загрузки фото" — so a
  // failed upload blocks the status change rather than silently dropping
  // the photo.
  File? _pendingPhoto;
  bool _uploadingPhoto = false;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _pendingPhoto = File(picked.path));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _historyLoading = true);
    try {
      final data = await ApiService.instance.getLoad(widget.loadId);
      if (data != null && mounted) {
        final rawHistory = data['history'] as List<dynamic>? ?? [];
        setState(() {
          _history = rawHistory
              .map((e) => LoadHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _historyLoading = false);
  }

  LoadItem? _find() {
    // allLoads already includes activeLoad, pendingLoads, and historyLoads
    for (final l in widget.store.allLoads) {
      if (l.id == widget.loadId) return l;
    }
    return null;
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final t = AppLocalizations.of(context);
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return t.tr('justNow');
    if (diff.inHours < 1) return '${diff.inMinutes}${t.tr('minutesAgoShort')}';
    if (diff.inDays < 1) return '${diff.inHours}${t.tr('hoursAgoShort')}';
    return '${diff.inDays}${t.tr('daysAgoShort')}';
  }

  Future<void> _handleAction(BuildContext context, LoadItem load) async {
    List<String>? attachmentIds;

    if (_pendingPhoto != null) {
      setState(() => _uploadingPhoto = true);
      final attachmentId = await ApiService.instance.uploadImage(_pendingPhoto!);
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);

      if (attachmentId == null) {
        // "Ждём загрузки фото" — a failed upload blocks the status change
        // rather than silently proceeding without the photo the driver
        // meant to attach.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).tr('podUploadFailed'))),
          );
        }
        return;
      }
      attachmentIds = [attachmentId];
    }

    switch (load.status) {
      case LoadStatus.assigned:
        await widget.store.acceptLoad(load.id, attachmentIds: attachmentIds);
        break;
      case LoadStatus.accepted:
        await widget.store.beginPickup(load.id, attachmentIds: attachmentIds);
        break;
      case LoadStatus.pickingUp:
        await widget.store.confirmPickup(load.id, attachmentIds: attachmentIds);
        break;
      case LoadStatus.pickedUp:
        await widget.store.startLoad(load.id, attachmentIds: attachmentIds);
        break;
      case LoadStatus.inTransit:
        await widget.store.beginDropoff(load.id, attachmentIds: attachmentIds);
        break;
      case LoadStatus.droppingOff:
        await widget.store.confirmDropoff(load.id, attachmentIds: attachmentIds);
        break;
      default:
        break;
    }
    if (mounted) setState(() => _pendingPhoto = null);
    // Re-fetch history after status change
    _fetchDetail();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
        final load = _find();

        if (load == null) {
          return Scaffold(
            appBar: AppBar(title: Text(t.tr('load'))),
            body: Center(
              child: Text(
                t.tr('loadNotFound'),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        final isLoading = widget.store.isLoadingId(load.id);
        final actionKey = load.status.nextActionKey;
        // For completed/confirmed show all steps done (index 6 = past last step).
        // For cancelled or pre-active statuses hide the stepper (null).
        final rawStep = load.status.stepIndex;
        final displayStep = rawStep >= 0
            ? rawStep
            : (load.status == LoadStatus.completed ||
                  load.status == LoadStatus.confirmed)
            ? 6
            : null;
        final historyToShow = _history.isNotEmpty ? _history : load.history;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              load.title.isNotEmpty
                  ? load.title
                  : 'Load #${load.id.substring(0, 8)}',
            ),
          ),
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
                              load.title.isNotEmpty
                                  ? load.title
                                  : 'Load #${load.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
                              t.tr('awaitingShipperConfirmation'),
                              style: TextStyle(
                                color: AppColors.statusDroppedOff,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.tr('awaitingConfirmationDetail'),
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
                        t.tr('details'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoRow(label: t.tr('pickup'), value: load.pickupAddress),
                      InfoRow(
                        label: t.tr('dropoff'),
                        value: load.dropoffAddress,
                      ),
                      if (load.description.isNotEmpty)
                        InfoRow(
                          label: t.tr('description'),
                          value: load.description,
                        ),
                      if (load.pickupAt != null)
                        InfoRow(
                          label: t.tr('pickupTime'),
                          value: formatDateTime(load.pickupAt),
                        ),
                      if (load.dropoffAt != null)
                        InfoRow(
                          label: t.tr('dropoffTime'),
                          value: formatDateTime(load.dropoffAt),
                        ),
                      InfoRow(
                        label: t.tr('created'),
                        value: formatDateTime(load.createdAt),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Optional POD photo ───────────────────────────────────
              if (actionKey != null) ...[
                const SizedBox(height: 16),
                if (_uploadingPhoto)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.tr('podUploadingPhoto'),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      if (_pendingPhoto != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _pendingPhoto!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _pendingPhoto = null),
                          tooltip: t.tr('podRemovePhoto'),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text(t.tr('podAddPhoto')),
                        ),
                    ],
                  ),
              ],

              // ─── Action button ────────────────────────────────────────
              if (actionKey != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: (isLoading || _uploadingPhoto)
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: (load.status == LoadStatus.assigned &&
                                  widget.store.activeLoad != null)
                              ? null
                              : () => _handleAction(context, load),
                          child: Text(t.tr(actionKey)),
                        ),
                ),
              ],

              // ─── Status history ───────────────────────────────────────
              if (historyToShow.isNotEmpty || _historyLoading) ...[
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: Text(
                      t.tr('statusHistory'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    initiallyExpanded: true,
                    children: [
                      if (_historyLoading)
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
                                        '${LoadStatus.fromString(item.fromStatus).localizedLabel(t)} → ${LoadStatus.fromString(item.toStatus).localizedLabel(t)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _relativeTime(context, item.changedAt),
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
