import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip displaying a load's current status with semantic colors.
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  static Color _accent(String status, BuildContext context) {
    final colors = AppColors.of(context);
    switch (status) {
      case 'created':
        return colors.mutedForeground;
      case 'assigned':
        return const Color(0xFF818CF8);
      case 'accepted':
        return colors.primary;
      case 'pickingUp':
      case 'picking_up':
        return const Color(0xFFFB923C);
      case 'pickedUp':
      case 'picked_up':
        return const Color(0xFF60A5FA);
      case 'in_transit':
      case 'inTransit':
        return colors.warning;
      case 'droppingOff':
      case 'dropping_off':
        return const Color(0xFFF59E0B);
      case 'droppedOff':
      case 'dropped_off':
        return const Color(0xFF34D399);
      case 'completed':
        return colors.success;
      case 'confirmed':
        return const Color(0xFF34D399);
      case 'cancelled':
        return colors.destructive;
      default:
        return colors.mutedForeground;
    }
  }
}
