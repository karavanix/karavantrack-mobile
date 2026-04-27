import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// Horizontal 6-step status stepper.
///
/// [currentStepIndex] — 0–5 for the active step, -1 for no highlight.
/// [compact] — true = small nodes without labels (home card), false = with labels (details).
/// [isAwaitingConfirmation] — when true, the current node renders as an amber
/// hourglass instead of the blue pulse, signaling "done on driver side, waiting on shipper."
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
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  static const _labelKeys = [
    'stepAccepted',
    'stepPickup',
    'stepLoaded',
    'stepTransit',
    'stepDropoff',
    'stepDelivered',
  ];

  static const _stepCount = 6;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodeSize = widget.compact ? 20.0 : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nodes row with connecting lines painted behind
        SizedBox(
          height: nodeSize + 12, // extra room for pulse glow on current node
          child: CustomPaint(
            painter: _LinePainter(
              stepCount: _stepCount,
              currentStepIndex: widget.currentStepIndex,
              nodeSize: nodeSize,
            ),
            child: Row(
              children: [
                for (int i = 0; i < _stepCount; i++)
                  Expanded(
                    child: Center(
                      child: _StepNode(
                        index: i,
                        currentIndex: widget.currentStepIndex,
                        nodeSize: nodeSize,
                        pulseAnim: _pulseAnim,
                        isAwaitingConfirmation: widget.isAwaitingConfirmation &&
                            i == widget.currentStepIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Labels row — only in non-compact mode
        if (!widget.compact) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              for (int i = 0; i < _stepCount; i++)
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).tr(_labelKeys[i]),
                    style: TextStyle(
                      fontSize: 10,
                      color: i < widget.currentStepIndex
                          ? AppColors.success
                          : i == widget.currentStepIndex
                              ? (widget.isAwaitingConfirmation
                                  ? AppColors.statusDroppedOff
                                  : AppColors.primary)
                              : AppColors.border,
                      fontWeight: i == widget.currentStepIndex
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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
    this.isAwaitingConfirmation = false,
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

    if (isCurrent && isAwaitingConfirmation) {
      // Amber pulsing hourglass — "done on driver's side, waiting on shipper"
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
                  color: AppColors.primary.withValues(
                    alpha: 0.25 - pulseAnim.value * 0.15,
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
                    child: Icon(
                      Icons.circle,
                      size: nodeSize * 0.4,
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

    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }
}
