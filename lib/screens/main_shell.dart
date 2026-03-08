import 'package:flutter/material.dart';
import '../store/app_store.dart';
import 'driver_home_screen.dart';
import 'settings_screen.dart';

/// Main app shell with 2-tab bottom navigation: Home + Settings.
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
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
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
            child: BottomNavigationBar(
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping_outlined),
                  activeIcon: Icon(Icons.local_shipping),
                  label: 'Loads',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
