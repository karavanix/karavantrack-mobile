import 'package:flutter/material.dart';

const double kDockHeight = 64.0;
const double kDockBottomMargin = 16.0;
const double kDockBreathingRoom = 20.0;

/// Bottom inset a screen hosted under the floating dock should reserve
/// so its last content is fully visible above the dock.
double dockClearance(BuildContext context) =>
    kDockHeight +
    kDockBottomMargin +
    kDockBreathingRoom +
    MediaQuery.of(context).padding.bottom;

class FloatingDockItem {
  const FloatingDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class FloatingDock extends StatelessWidget {
  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingDockItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        bottom: bottomPadding + kDockBottomMargin,
      ),
      child: Container(
        height: kDockHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? theme.colorScheme.outline : theme.colorScheme.outline.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            return _DockTab(
              item: items[i],
              isActive: i == currentIndex,
              activeColor: theme.colorScheme.primary,
              inactiveColor: theme.colorScheme.onSurface.withOpacity(0.45),
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final FloatingDockItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isActive 
                ? activeColor.withOpacity(isDark ? 0.25 : 0.12) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  key: ValueKey(isActive),
                  color: isActive ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? activeColor : inactiveColor,
                  fontFamily: 'Inter',
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
