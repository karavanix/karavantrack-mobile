import 'package:flutter/material.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';
import 'driver_home_screen.dart';
import 'settings_screen.dart';

/// Main app shell with 2-tab bottom navigation: Loads / Settings.
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
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    final screens = <Widget>[
      DriverHomeScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline, width: 1),
          ),
        ),
        child: SizedBox(
          height: 56,
          child: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            selectedFontSize: 10,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.local_shipping_outlined),
                activeIcon: const Icon(Icons.local_shipping),
                label: t.tr('loads'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings),
                label: t.tr('settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
