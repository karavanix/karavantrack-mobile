import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  Timer? _splashTimer;

  void _handlePosition(Position position) {
    _store.onGpsPosition(position);
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? AppStore();
    _gps.startPositionStream(_handlePosition);
    _splashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _store.dispose();
    _gps.stopPositionStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YoolLive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _showSplash
          ? const SplashScreen()
          : ListenableBuilder(
              listenable: _store,
              builder: (context, child) {
                if (!_store.isLoggedIn) {
                  return LoginScreen(store: _store);
                }
                if (!_store.isProfileCompleted) {
                  return ProfileSetupScreen(store: _store);
                }
                return MainShell(store: _store);
              },
            ),
    );
  }
}
