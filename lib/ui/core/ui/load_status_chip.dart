import 'package:material_ui/material_ui.dart';

import '../../../domain/models/load.dart';
import '../l10n/l10n.dart';
import '../l10n/load_texts.dart';
import '../themes/app_theme.dart';

/// Chip displaying a load's current status with semantic colors.
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.status});

  final LoadStatus status;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.l10n.loadStatus(status),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _accent(BuildContext context) {
    final colors = AppTheme.of(context);
    return switch (status) {
      LoadStatus.assigned => const Color(0xFF818CF8),
      LoadStatus.accepted => colors.primary,
      LoadStatus.pickingUp => const Color(0xFFFB923C),
      LoadStatus.pickedUp => const Color(0xFF60A5FA),
      LoadStatus.inTransit => colors.warning,
      LoadStatus.droppingOff => const Color(0xFFF59E0B),
      LoadStatus.droppedOff || LoadStatus.confirmed => const Color(0xFF34D399),
      LoadStatus.cancelled => colors.destructive,
      LoadStatus.created || LoadStatus.unknown => colors.mutedForeground,
    };
  }
}
