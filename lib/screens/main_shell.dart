import 'package:flutter/material.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';
import '../widgets/floating_dock.dart';
import 'driver_home_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final AppStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DriverHomeScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: FloatingDock(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: _buildItems(context),
      ),
    );
  }

  List<FloatingDockItem> _buildItems(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      FloatingDockItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: t.tr('loads'),
      ),
      FloatingDockItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: t.tr('settings'),
      ),
    ];
  }
}
