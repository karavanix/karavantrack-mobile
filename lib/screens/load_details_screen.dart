import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/info_row.dart';
import '../utils/formatters.dart';
import 'active_load_screen.dart';

/// Detail view for a load — shows info and Accept button for assigned loads.
class LoadDetailsScreen extends StatelessWidget {
  const LoadDetailsScreen({
    super.key,
    required this.store,
    required this.loadId,
  });

  final AppStore store;
  final String loadId;

  LoadItem? _find() {
    for (final l in store.allLoads) {
      if (l.id == loadId) return l;
    }
    for (final l in store.pendingLoads) {
      if (l.id == loadId) return l;
    }
    return store.activeLoad?.id == loadId ? store.activeLoad : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        final load = _find();
        if (load == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Load')),
            body: Center(
              child: Text(
                'Load not found',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

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
              // Status card
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
                              'Details',
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
                      const SizedBox(height: 16),
                      InfoRow(label: 'Pickup', value: load.pickupAddress),
                      InfoRow(label: 'Dropoff', value: load.dropoffAddress),
                      if (load.description.isNotEmpty)
                        InfoRow(label: 'Description', value: load.description),
                      if (load.pickupAt != null)
                        InfoRow(
                          label: 'Pickup time',
                          value: formatDateTime(load.pickupAt),
                        ),
                      if (load.dropoffAt != null)
                        InfoRow(
                          label: 'Dropoff time',
                          value: formatDateTime(load.dropoffAt),
                        ),
                      InfoRow(
                        label: 'Created',
                        value: formatDateTime(load.createdAt),
                      ),
                    ],
                  ),
                ),
              ),

              // Accept button for assigned loads
              if (load.status == LoadStatus.assigned) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: store.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () async {
                            await store.acceptLoad(load.id);
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => ActiveLoadScreen(
                                  store: store,
                                  loadId: load.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept Load'),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
