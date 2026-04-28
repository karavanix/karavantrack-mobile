import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip displaying a load's current status with semantic colors.
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  static Color _statusColor(BuildContext context, String status) {
    final colors = AppColors.of(context);
    switch (status) {
      case 'created':
        return colors.mutedForeground;
      case 'assigned':
        return const Color.fromARGB(255, 129, 140, 248);
      case 'accepted':
        return colors.primary;
      case 'pickingUp':
      case 'picking_up':
        return const Color.fromARGB(255, 251, 146, 60);
      case 'pickedUp':
      case 'picked_up':
        return const Color.fromARGB(255, 96, 165, 250);
      case 'in_transit':
      case 'inTransit':
        return colors.warning;
      case 'droppingOff':
      case 'dropping_off':
        return const Color.fromARGB(255, 245, 158, 11);
      case 'droppedOff':
      case 'dropped_off':
        return const Color.fromARGB(255, 52, 211, 153);
      case 'completed':
        return colors.success;
      case 'confirmed':
        return const Color.fromARGB(255, 52, 211, 153);
      case 'cancelled':
        return colors.destructive;
      default:
        return colors.mutedForeground;
    }
  }
}
