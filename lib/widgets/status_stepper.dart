import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Horizontal 6-step status stepper.
///
/// [currentStepIndex] — 0–5 for the active step, -1 for no highlight.
/// [compact] — true = small nodes without labels (home card), false = with labels (details).
class StatusStepper extends StatefulWidget {
  const StatusStepper({
    super.key,
    required this.currentStepIndex,
    this.compact = false,
  });

  final int currentStepIndex;
  final bool compact;

  @override
  State<StatusStepper> createState() => _StatusStepperState();
}

class _StatusStepperState extends State<StatusStepper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  static const _labels = [
    'Accepted',
    'Pickup',
    'Loaded',
    'Transit',
    'Dropoff',
    'Delivered',
  ];

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
    final nodeSize = widget.compact ? 20.0 : 26.0;
    const stepCount = 6;

    return SizedBox(
      height: widget.compact ? nodeSize : nodeSize + 22,
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
                  left: nodeSize * i + spacing * i + nodeSize,
                  top: nodeSize / 2 - 1,
                  width: spacing,
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
                  left: (nodeSize + spacing) * i,
                  top: 0,
                  child: _StepNode(
                    index: i,
                    currentIndex: widget.currentStepIndex,
                    nodeSize: nodeSize,
                    pulseAnim: _pulseAnim,
                    label: widget.compact ? null : _labels[i],
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
    this.label,
  });

  final int index;
  final int currentIndex;
  final double nodeSize;
  final Animation<double> pulseAnim;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentIndex;
    final isCurrent = index == currentIndex;
    final isPending = index > currentIndex;

    Widget node;

    if (isCurrent) {
      node = AnimatedBuilder(
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
    } else if (isDone) {
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
