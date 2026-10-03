import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/ui/floating_dock.dart';

/// The signed-in app: the loads and settings tabs under the floating dock,
/// each keeping its own navigation stack.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingDock(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          FloatingDockItem(
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping,
            label: t.loads,
          ),
          FloatingDockItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: t.settings,
          ),
        ],
      ),
    );
  }
}
