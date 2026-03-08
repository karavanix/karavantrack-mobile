import 'package:flutter/material.dart';
import '../models/load.dart';
import '../store/app_store.dart';
import '../widgets/load_status_chip.dart';
import '../widgets/status_pill.dart';
import '../theme/app_theme.dart';
import 'load_details_screen.dart';
import 'active_load_screen.dart';

/// Driver home screen with 3 tabs: Assigned, Active, Finished.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('KaravanTrack'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: store.fetchLoads,
                  tooltip: 'Refresh',
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Active'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _LoadsList(
                  loads: store.pendingLoads,
                  emptyMessage: 'No pending loads',
                  store: store,
                  onTap: (load) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoadDetailsScreen(store: store, loadId: load.id),
                    ),
                  ),
                ),
                _ActiveLoadTab(store: store),
                _LoadsList(
                  loads: store.finishedLoads,
                  emptyMessage: 'No completed loads yet',
                  store: store,
                  onTap: (load) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoadDetailsScreen(store: store, loadId: load.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Active load tab ────────────────────────────────────────────────────────

class _ActiveLoadTab extends StatelessWidget {
  const _ActiveLoadTab({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final load = store.activeLoad;

    if (load == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No active load',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LoadCard(
          load: load,
          store: store,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ActiveLoadScreen(store: store, loadId: load.id),
            ),
          ),
          isActive: true,
        ),
      ],
    );
  }
}

// ─── Loads list ─────────────────────────────────────────────────────────────

class _LoadsList extends StatelessWidget {
  const _LoadsList({
    required this.loads,
    required this.emptyMessage,
    required this.store,
    required this.onTap,
  });

  final List<LoadItem> loads;
  final String emptyMessage;
  final AppStore store;
  final void Function(LoadItem) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: store.fetchLoads,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: store.fetchLoads,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: loads.length,
        itemBuilder: (context, index) {
          final load = loads[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LoadCard(
              load: load,
              store: store,
              onTap: () => onTap(load),
            ),
          );
        },
      ),
    );
  }
}

// ─── Load card ──────────────────────────────────────────────────────────────

class _LoadCard extends StatelessWidget {
  const _LoadCard({
    required this.load,
    required this.store,
    required this.onTap,
    this.isActive = false,
  });

  final LoadItem load;
  final AppStore store;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

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
                      load.title.isNotEmpty ? load.title : 'Load #${load.id.substring(0, 8)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
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

              // Pickup
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.pickupAddress.isNotEmpty
                          ? load.pickupAddress
                          : 'Pickup location',
                      style: TextStyle(fontSize: 13, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Dropoff
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      load.dropoffAddress.isNotEmpty
                          ? load.dropoffAddress
                          : 'Dropoff location',
                      style: TextStyle(fontSize: 13, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (load.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  load.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
              ],

              // Active load tracking info
              if (isActive) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      label: store.networkOnline ? 'Online' : 'Offline',
                      color:
                          store.networkOnline ? AppColors.success : AppColors.warning,
                    ),
                    StatusPill(
                      label: 'Buffer: ${store.offlineBufferCount(load.id)}',
                      color: store.offlineBufferCount(load.id) == 0
                          ? AppColors.primary
                          : AppColors.warning,
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
