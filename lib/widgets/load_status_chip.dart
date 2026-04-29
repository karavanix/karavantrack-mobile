import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip displaying a load's current status with semantic colors.
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _colors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static ({Color background, Color foreground}) _colors(
    BuildContext context,
    String status,
  ) {
    final colors = AppColors.of(context);

    ({Color background, Color foreground}) tinted(Color accent) =>
        (background: accent.withValues(alpha: 0.15), foreground: accent);

    switch (status) {
      case 'created':
        return (background: colors.muted, foreground: colors.mutedForeground);
      case 'assigned':
        return tinted(const Color(0xFF818CF8));
      case 'accepted':
        return tinted(colors.primary);
      case 'pickingUp':
      case 'picking_up':
        return tinted(const Color(0xFFFB923C));
      case 'pickedUp':
      case 'picked_up':
        return tinted(const Color(0xFF60A5FA));
      case 'in_transit':
      case 'inTransit':
        return tinted(colors.warning);
      case 'droppingOff':
      case 'dropping_off':
        return tinted(const Color(0xFFF59E0B));
      case 'droppedOff':
      case 'dropped_off':
        return tinted(colors.statusDroppedOff);
      case 'completed':
        return tinted(colors.success);
      case 'confirmed':
        return tinted(colors.statusDroppedOff);
      case 'cancelled':
        return tinted(colors.destructive);
      default:
        return (background: colors.muted, foreground: colors.mutedForeground);
    }
  }
}
