import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/gps_service.dart';
import 'store/app_store.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/main_shell.dart';

/// Root widget — initializes GPS, store, and routes between auth states.
class DriverTrackingApp extends StatefulWidget {
  const DriverTrackingApp({super.key, this.store});

  final AppStore? store;

  @override
  State<DriverTrackingApp> createState() => _DriverTrackingAppState();
}

class _DriverTrackingAppState extends State<DriverTrackingApp> {
  final GpsService _gps = GpsService();
  late final AppStore _store;
  bool _showSplash = true;

  void _handlePosition(Position position) {
    _store.onGpsPosition(position);
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? AppStore();
    _gps.startPositionStream(_handlePosition);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _store.init(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  void dispose() {
    _store.dispose();
    _gps.stopPositionStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, child) {
        return AppLocalizations(
          locale: _store.locale,
          child: MaterialApp(
            title: 'YoolLive',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: _showSplash
                ? const SplashScreen()
                : !_store.isLoggedIn
                ? LoginScreen(store: _store)
                : !_store.isProfileCompleted
                ? ProfileSetupScreen(store: _store)
                : MainShell(store: _store),
          ),
        );
      },
    );
  }
}
