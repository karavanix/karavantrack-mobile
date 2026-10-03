import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/ui/floating_dock.dart';
import '../view_models/main_shell_view_model.dart';
import '../widgets/location_disclosure_dialog.dart';

/// The signed-in app: the loads and settings tabs under the floating dock,
/// each keeping its own navigation stack.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.viewModel,
    required this.navigationShell,
  });

  final MainShellViewModel viewModel;
  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the disclosure is a dialog over the shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.viewModel.start(() async {
        if (!mounted) return false;
        return LocationDisclosureDialog.show(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final navigationShell = widget.navigationShell;
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
