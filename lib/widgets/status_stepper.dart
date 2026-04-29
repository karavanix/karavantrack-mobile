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
  static const _labelGap = 4.0;
  static const _labelHeight = 13.0;

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
    final l10n = AppLocalizations.of(context);
    final labels = _labelKeys.map((k) => l10n.tr(k)).toList();
    final nodeSize = widget.compact ? 20.0 : 26.0;
    final currentIndex = widget.currentStepIndex;
    const stepCount = _stepCount;

    return SizedBox(
      height: widget.compact
          ? nodeSize
          : nodeSize + _labelGap + _labelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final sectionWidth = totalWidth / stepCount;
          // Connector spans from the right edge of circle i to the left edge of circle i+1.
          final connectorWidth = sectionWidth - nodeSize;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Connecting lines ──────────────────────────────────────────
              for (int i = 0; i < stepCount - 1; i++)
                Positioned(
                  // Start at the right edge of circle i.
                  left: sectionWidth * i + (sectionWidth + nodeSize) / 2,
                  top: nodeSize / 2 - 1,
                  width: connectorWidth,
                  height: 2,
                  child: Container(
                    color: i < currentIndex
                        ? AppColors.success
                        : const Color(0xFF2C3546),
                  ),
                ),

              // ── Step circles ─────────────────────────────────────────────
              for (int i = 0; i < stepCount; i++)
                Positioned(
                  left: sectionWidth * i + (sectionWidth - nodeSize) / 2,
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

              // ── Labels (one per section, full section width) ──────────────
              if (!widget.compact)
                for (int i = 0; i < stepCount; i++)
                  Positioned(
                    left: sectionWidth * i,
                    top: nodeSize + _labelGap,
                    width: sectionWidth,
                    height: _labelHeight,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: i > currentIndex
                            ? const Color(0xFF4A5568)
                            : i < currentIndex
                                ? AppColors.success
                                : AppColors.primary,
                        fontWeight: i == currentIndex
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Renders only the circular step indicator. Labels are handled by the parent.
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
    final isDone = index < currentIndex;
    final isCurrent = index == currentIndex;

    // ── Awaiting confirmation: amber pulsing hourglass ────────────────────
    if (isCurrent && isAwaitingConfirmation) {
      return OverflowBox(
        maxWidth: nodeSize + 12,
        maxHeight: nodeSize + 12,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (context, _) {
            final glowSize = nodeSize + 4 + pulseAnim.value * 8;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: glowSize,
                  height: glowSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF34D399).withValues(
                      alpha: 0.30 - pulseAnim.value * 0.20,
                    ),
                  ),
                ),
                Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF34D399),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: nodeSize * 0.50,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // ── Active step: blue pulsing glow ─────────────────────────────────────
    if (isCurrent) {
      return OverflowBox(
        maxWidth: nodeSize + 12,
        maxHeight: nodeSize + 12,
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (context, _) {
            final glowSize = nodeSize + 4 + pulseAnim.value * 8;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: glowSize,
                  height: glowSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(
                      alpha: 0.30 - pulseAnim.value * 0.20,
                    ),
                  ),
                ),
                Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // ── Completed step ─────────────────────────────────────────────────────
    if (isDone) {
      return Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
        child: Icon(Icons.check, size: nodeSize * 0.55, color: Colors.white),
      );
    }

    // ── Pending step ───────────────────────────────────────────────────────
    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: const Color(0xFF2C3546), width: 2),
      ),
    );
  }
}
