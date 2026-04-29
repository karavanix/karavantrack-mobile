import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Horizontal 6-step status stepper.
///
/// [currentStepIndex] is 0-5 for the active step, 6 when all steps are complete,
/// and -1 when no step should be highlighted.
class StatusStepper extends StatefulWidget {
  const StatusStepper({
    super.key,
    required this.currentStepIndex,
    this.compact = false,
    this.isAwaitingConfirmation = false,
  });

  final int currentStepIndex;
  final bool compact;
  final bool isAwaitingConfirmation;

  @override
  State<StatusStepper> createState() => _StatusStepperState();
}

class _StatusStepperState extends State<StatusStepper>
    with SingleTickerProviderStateMixin {
  static const _labelKeys = [
    'stepAccepted',
    'stepPickup',
    'stepLoaded',
    'stepTransit',
    'stepDropoff',
    'stepDelivered',
  ];

  static const _stepCount = 6;

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = AppLocalizations.of(context);
    final labels = _labelKeys.map(t.tr).toList(growable: false);
    final nodeSize = widget.compact ? 20.0 : 26.0;
    final currentIndex = widget.currentStepIndex.clamp(-1, _stepCount);
    const labelTopSpacing = 8.0;
    const labelHeight = 26.0;

    return SizedBox(
      height: widget.compact
          ? nodeSize
          : nodeSize + labelTopSpacing + labelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final sectionWidth = totalWidth / _stepCount;
          final connectorWidth = (sectionWidth - nodeSize).clamp(
            0.0,
            totalWidth,
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < _stepCount - 1; i++)
                Positioned(
                  left: sectionWidth * i + (sectionWidth / 2),
                  top: nodeSize / 2 - 1,
                  width: connectorWidth,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i < currentIndex ? colors.success : colors.border,
                    ),
                  ),
                ),
              for (int i = 0; i < _stepCount; i++)
                Positioned(
                  left: sectionWidth * i + ((sectionWidth - nodeSize) / 2),
                  top: 0,
                  width: nodeSize,
                  height: nodeSize,
                  child: _StepNode(
                    index: i,
                    currentIndex: currentIndex,
                    nodeSize: nodeSize,
                    pulseAnim: _pulseAnim,
                    isAwaitingConfirmation: widget.isAwaitingConfirmation,
                  ),
                ),
              if (!widget.compact)
                for (int i = 0; i < _stepCount; i++)
                  Positioned(
                    left: sectionWidth * i,
                    top: nodeSize + labelTopSpacing,
                    width: sectionWidth,
                    height: labelHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        labels[i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: i == currentIndex
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _labelColor(colors, i, currentIndex),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Color _labelColor(AppSemanticColors colors, int index, int currentIndex) {
    if (index < currentIndex) return colors.success;
    if (index == currentIndex) {
      return widget.isAwaitingConfirmation
          ? colors.statusDroppedOff
          : colors.primary;
    }
    return colors.mutedForeground;
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.currentIndex,
    required this.nodeSize,
    required this.pulseAnim,
    required this.isAwaitingConfirmation,
  });

  final int index;
  final int currentIndex;
  final double nodeSize;
  final Animation<double> pulseAnim;
  final bool isAwaitingConfirmation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDone = index < currentIndex;
    final isCurrent =
        currentIndex >= 0 && currentIndex < 6 && index == currentIndex;

    if (isCurrent) {
      final activeColor = isAwaitingConfirmation
          ? colors.statusDroppedOff
          : colors.primary;
      final icon = isAwaitingConfirmation
          ? Icons.hourglass_top_rounded
          : Icons.circle;

      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          final glowSize = nodeSize + 6 + pulseAnim.value * 6;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withValues(
                    alpha: 0.25 - pulseAnim.value * 0.15,
                  ),
                ),
              ),
              Container(
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                ),
                child: Icon(
                  icon,
                  size: nodeSize * (isAwaitingConfirmation ? 0.52 : 0.4),
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    }

    if (isDone) {
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
        ),
        child: Icon(Icons.check, size: nodeSize * 0.55, color: Colors.white),
      );
    }

    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.card,
        border: Border.all(color: colors.border, width: 2),
      ),
    );
  }
}
