import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip displaying a load's current status with semantic colors.
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    final isAwaiting = status == 'droppedOff' || status == 'dropped_off';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: isAwaiting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 11, color: bg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                      color: bg, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            )
          : Text(
              label,
              style:
                  TextStyle(color: bg, fontWeight: FontWeight.w600, fontSize: 12),
            ),
    );
  }

  static (Color, Color) _colors(String status) {
    switch (status) {
      case 'created':
        return (AppColors.mutedForeground, AppColors.foreground);
      case 'assigned':
        return (AppColors.statusAssigned, AppColors.foreground);
      case 'accepted':
        return (AppColors.primary, AppColors.primaryForeground);
      case 'pickingUp':
      case 'picking_up':
        return (AppColors.statusPickingUp, AppColors.foreground);
      case 'pickedUp':
      case 'picked_up':
        return (AppColors.statusPickedUp, AppColors.foreground);
      case 'in_transit':
      case 'inTransit':
        return (AppColors.warning, AppColors.foreground);
      case 'droppingOff':
      case 'dropping_off':
        return (AppColors.statusDroppingOff, AppColors.foreground);
      case 'droppedOff':
      case 'dropped_off':
        return (AppColors.statusDroppedOff, AppColors.foreground);
      case 'completed':
        return (AppColors.success, AppColors.foreground);
      case 'confirmed':
        return (AppColors.statusDroppedOff, AppColors.foreground);
      case 'cancelled':
        return (AppColors.destructive, AppColors.foreground);
      default:
        return (AppColors.mutedForeground, AppColors.foreground);
    }
  }
}
