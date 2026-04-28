import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/gps_service.dart';
import 'services/notification_service.dart';
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
  // ValueNotifier so _HomeRouter can listen directly without rebuilding MaterialApp.
  final ValueNotifier<bool> _showSplash = ValueNotifier(true);

  // Navigator key — gives us a context that is INSIDE MaterialApp so that
  // showDialog / Navigator.pop work correctly from timer callbacks.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ─── GPS polling ───────────────────────────────────────────────────────────
  Timer? _gpsPoller;
  bool _gpsEnabled = false;
  bool _gpsDialogShown = false;

  void _handlePosition(Position position) => _store.onGpsPosition(position);

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? AppStore();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wire foreground FCM message display before store.init() fires initialize()
    NotificationService.instance.onForegroundMessage = (message) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      final n = message.notification;
      if (n == null) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(n.title ?? n.body ?? '')),
      );
    };

    // Initial GPS check
    _gpsEnabled = await Geolocator.isLocationServiceEnabled();

    if (_gpsEnabled) {
      _gps.startPositionStream(_handlePosition).catchError((_) {});
    }

    await Future.wait([
      _store.init(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (mounted) _showSplash.value = false;

    // Start polling GPS status every 2 seconds
    _startGpsPolling();
  }

  /// Polls GPS enabled status every 2 seconds.
  /// Shows dialog when GPS is off, auto-dismisses and restarts stream when on.
  void _startGpsPolling() {
    _gpsPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final isEnabled = await Geolocator.isLocationServiceEnabled();

      if (!isEnabled && _gpsEnabled) {
        // GPS just turned OFF
        _gpsEnabled = false;
        await _gps.stopPositionStream();
        if (mounted && !_gpsDialogShown) _showGpsDialog();
      } else if (isEnabled && !_gpsEnabled) {
        // GPS just turned ON (or was on at first check)
        _gpsEnabled = true;
        _gps.startPositionStream(_handlePosition).catchError((_) {});
        // Auto-dismiss any open dialog
        if (_gpsDialogShown) _navigatorKey.currentState?.pop();
      } else if (!isEnabled && !_gpsDialogShown) {
        // GPS still off and dialog was dismissed — re-show it
        if (mounted) _showGpsDialog();
      }
    });
  }

  /// Shows a non-dismissible dialog prompting the user to enable GPS.
  /// Sets [_gpsDialogShown] = true while open so we don't stack duplicates.
  void _showGpsDialog() {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;
    _gpsDialogShown = true;

    showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx);
        return PopScope(
          // Prevent back-button dismissal
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.gps_off_rounded, size: 48),
            iconColor: Colors.orange,
            title: Text(t.tr('gpsOffTitle')),
            content: Text(t.tr('gpsOffMessage')),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.location_on),
                  label: Text(t.tr('turnOnGps')),
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // Track that dialog closed (user navigated away via settings or back)
      _gpsDialogShown = false;
    });
  }

  @override
  void dispose() {
    _gpsPoller?.cancel();
    _store.dispose();
    _showSplash.dispose();
    _gps.stopPositionStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build MaterialApp ONCE — do NOT wrap in ListenableBuilder.
    // Rebuilding MaterialApp resets its internal Navigator, which wipes the
    // navigation stack.  Theme/locale/auth changes are handled by
    // AnimatedBuilder widgets inside the widget tree below MaterialApp.
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'YoolLive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Wrap with localizations via builder so locale/theme changes propagate
      // without rebuilding MaterialApp itself.
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _store,
          builder: (context, _) {
            return AppLocalizations(
              locale: _store.locale,
              child: Theme(
                data: _store.isDarkTheme ? AppTheme.dark : AppTheme.light,
                child: child!,
              ),
            );
          },
        );
      },
      home: _HomeRouter(
        store: _store,
        showSplash: _showSplash,
      ),
    );
  }
}

/// Lightweight widget that routes between Splash / Login / ProfileSetup / Main.
/// Listens to both [store] (auth/profile state) and [showSplash] (splash timer)
/// so it rebuilds only when routing actually needs to change.
class _HomeRouter extends StatelessWidget {
  const _HomeRouter({required this.store, required this.showSplash});

  final AppStore store;
  final ValueNotifier<bool> showSplash;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Merge both listenables so we react to either changing.
      animation: Listenable.merge([store, showSplash]),
      builder: (context, _) {
        if (showSplash.value) return const SplashScreen();
        if (!store.isLoggedIn) return LoginScreen(store: store);
        if (!store.isProfileCompleted) return ProfileSetupScreen(store: store);
        return MainShell(store: store);
      },
    );
  }
}
