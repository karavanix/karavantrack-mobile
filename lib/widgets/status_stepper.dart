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
    final nodeSize = widget.compact ? 20.0 : 26.0;
    const stepCount = 6;

    return SizedBox(
      height: widget.compact
          ? nodeSize
          : nodeSize + labelTopSpacing + labelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final spacing = (totalWidth - nodeSize * stepCount) / (stepCount - 1);

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
                    color: i < widget.currentStepIndex
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
                    label: widget.compact ? null : _labels[i],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// Draws the horizontal connecting lines between node centers
class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.stepCount,
    required this.currentStepIndex,
    required this.nodeSize,
  });

  final int stepCount;
  final int currentStepIndex;
  final double nodeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final slotWidth = size.width / stepCount;
    final centerY = size.height / 2;
    final lineY = centerY;

    for (int i = 0; i < stepCount - 1; i++) {
      final startX = slotWidth * i + slotWidth / 2 + nodeSize / 2;
      final endX = slotWidth * (i + 1) + slotWidth / 2 - nodeSize / 2;

      final paint = Paint()
        ..color = i < currentStepIndex ? AppColors.success : AppColors.border
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, lineY), Offset(endX, lineY), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.currentStepIndex != currentStepIndex || old.nodeSize != nodeSize;
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.currentIndex,
    required this.nodeSize,
    required this.pulseAnim,
    this.label,
  });

  final int index;
  final int currentIndex;
  final double nodeSize;
  final Animation<double> pulseAnim;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDone = index < currentIndex;
    final isCurrent = index == currentIndex;

    if (isCurrent && isAwaitingConfirmation) {
      // Amber pulsing hourglass — "done on driver's side, waiting on shipper"
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
                  color: AppColors.statusDroppedOff.withValues(
                    alpha: 0.25 - pulseAnim.value * 0.15,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusDroppedOff,
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: nodeSize * 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
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
    } else if (isDone) {
      node = Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
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

    // Wrap current node to align center with the node-size baseline
    final centered = isCurrent
        ? SizedBox(width: nodeSize, child: Center(child: node))
        : node;

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
              fontWeight:
                  isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
