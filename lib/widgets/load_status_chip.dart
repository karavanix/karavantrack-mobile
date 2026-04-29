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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: bg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  static Color _statusColor(BuildContext context, String status) {
    final colors = AppColors.of(context);

    ({Color background, Color foreground}) tinted(Color accent) =>
        (background: accent.withValues(alpha: 0.15), foreground: accent);

    switch (status) {
      case 'created':
        return colors.mutedForeground;
      case 'assigned':
        return (Color.fromARGB(255, 129, 140, 248), AppColors.foreground);
      case 'accepted':
        return colors.primary;
      case 'pickingUp':
      case 'picking_up':
        return (Color.fromARGB(255, 251, 146, 60), AppColors.foreground);
      case 'pickedUp':
      case 'picked_up':
        return (Color.fromARGB(255, 96, 165, 250), AppColors.foreground);
      case 'in_transit':
      case 'inTransit':
        return colors.warning;
      case 'droppingOff':
      case 'dropping_off':
        return (Color.fromARGB(255, 245, 158, 11), AppColors.foreground);
      case 'droppedOff':
      case 'dropped_off':
        return (Color.fromARGB(255, 52, 211, 153), AppColors.foreground);
      case 'completed':
        return colors.success;
      case 'confirmed':
        return (Color.fromARGB(255, 52, 211, 153), AppColors.foreground);
      case 'cancelled':
        return colors.destructive;
      default:
        return colors.mutedForeground;
    }
  }
}
