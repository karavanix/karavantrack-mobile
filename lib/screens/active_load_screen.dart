import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/status_pill.dart';
import '../widgets/info_row.dart';
import '../theme/app_theme.dart';

/// Active load tracking screen — shows live tracking data and actions.
class ActiveLoadScreen extends StatelessWidget {
  const ActiveLoadScreen({
    super.key,
    required this.store,
    required this.loadId,
  });

  final AppStore store;
  final String loadId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final load = store.activeLoad?.id == loadId ? store.activeLoad : null;
        if (load == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Active Load')),
            body: Center(
              child: Text(
                'Load not found or no longer active',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        final bufferCount = store.offlineBufferCount(loadId);

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
              // ─── Status & tracking info ────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tracking',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          LoadStatusChip(
                            label: load.status.label,
                            status: load.status.name,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            label:
                                store.networkOnline ? 'Online' : 'Offline',
                            color: store.networkOnline
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          StatusPill(
                            label: 'Buffer: $bufferCount',
                            color: bufferCount == 0
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InfoRow(
                        label: 'Pickup',
                        value: load.pickupAddress,
                      ),
                      InfoRow(
                        label: 'Dropoff',
                        value: load.dropoffAddress,
                      ),
                     
                      InfoRow(
                        label: 'GPS Position',
                        value: store.lastGpsPosition == null
                            ? 'Waiting for GPS...'
                            : '${store.lastGpsPosition!.latitude.toStringAsFixed(6)}, '
                                '${store.lastGpsPosition!.longitude.toStringAsFixed(6)}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Actions ────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (load.status == LoadStatus.accepted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => store.startLoad(load.id),
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: const Text('Start Transit'),
                          ),
                        ),
                      SizedBox(
                        height: 48,
                        child: store.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: () async {
                                  await store.completeLoad(load.id);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Complete'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
