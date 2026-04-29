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
  static const _labelTopSpacing = 4.0;
  static const _labelHeight = 14.0;

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
          : nodeSize + _labelTopSpacing + _labelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final sectionWidth = totalWidth / stepCount;
          final connectorWidth = sectionWidth - nodeSize;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Connecting lines
              for (int i = 0; i < stepCount - 1; i++)
                Positioned(
                  left: sectionWidth * i + (sectionWidth / 2),
                  top: nodeSize / 2 - 1,
                  width: connectorWidth,
                  height: 2,
                  child: Container(
                    color: i < currentIndex
                        ? AppColors.success
                        : const Color(0xFF2C3546),
                  ),
                ),

              // Step nodes
              for (int i = 0; i < stepCount; i++)
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
                    label: widget.compact ? null : labels[i],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.currentIndex,
    required this.nodeSize,
    required this.pulseAnim,
    required this.isAwaitingConfirmation,
    this.label,
  });

  final int index;
  final int currentIndex;
  final double nodeSize;
  final Animation<double> pulseAnim;
  final bool isAwaitingConfirmation;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentIndex;
    final isCurrent = index == currentIndex;
    final isPending = !isCurrent && !isDone;

    if (isCurrent && isAwaitingConfirmation) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          final glowSize = nodeSize + 6 + pulseAnim.value * 6;
          return SizedBox(
            width: nodeSize + 12,
            height: nodeSize + 12,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusDroppedOff.withValues(
                        alpha: 0.25 - pulseAnim.value * 0.15,
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
                      size: nodeSize * 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (isCurrent) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          final glowSize = nodeSize + 6 + pulseAnim.value * 6;
          return SizedBox(
            width: nodeSize + 12,
            height: nodeSize + 12,
            child: Center(
              child: Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: 0.25 + pulseAnim.value * 0.15,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget node;
    if (isDone) {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
        ),
        child: Icon(Icons.check, size: nodeSize * 0.55, color: Colors.white),
      );
    } else {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFF2C3546), width: 2),
        ),
      );
    }

    final Widget centered = SizedBox(
      width: nodeSize,
      child: Center(child: node),
    );

    if (label == null) return centered;

    return SizedBox(
      width: nodeSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          centered,
          const SizedBox(height: 4),
          Text(
            label!,
            style: TextStyle(
              fontSize: 9,
              color: isPending
                  ? const Color(0xFF2C3546)
                  : isDone
                      ? AppColors.success
                      : AppColors.primary,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
