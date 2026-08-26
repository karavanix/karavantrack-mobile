import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_links/app_links.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/gps_service.dart';
import 'services/telegram_auth_service.dart';
import 'services/location_permission_service.dart';
import 'services/notification_service.dart';
import 'widgets/location_disclosure_dialog.dart';
import 'store/app_store.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/language_select_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/accept_invite_screen.dart';
import 'screens/main_shell.dart';

/// Root widget — initializes GPS, store, and routes between auth states.
class DriverTrackingApp extends StatefulWidget {
  const DriverTrackingApp({super.key, this.store});

  final AppStore? store;

  @override
  State<DriverTrackingApp> createState() => _DriverTrackingAppState();
}

class _DriverTrackingAppState extends State<DriverTrackingApp>
    with WidgetsBindingObserver {
  final GpsService _gps = GpsService();
  late final AppStore _store;
  // ValueNotifier so _HomeRouter can listen directly without rebuilding MaterialApp.
  final ValueNotifier<bool> _showSplash = ValueNotifier(true);

  // Navigator key — gives us a context that is INSIDE MaterialApp so that
  // showDialog / Navigator.pop work correctly from timer callbacks.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ─── Driver-invite deep links ───────────────────────────────────────────
  // https://app.yool.live/invite/{token} and yoollive://invite/{token}.
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _inviteLinkSub;

  // ─── GPS polling ───────────────────────────────────────────────────────────
  Timer? _gpsPoller;
  bool _gpsEnabled = false;
  bool _streamActive = false;

  // ─── Always-location permission ────────────────────────────────────────────
  bool _permissionGranted = false;

  void _handlePosition(Position position) => _store.onGpsPosition(position);

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? AppStore();
    TelegramAuthService.init(_store);
    _store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _initializeApp();
  }

  /// Wires up driver-invite deep-link handling once, mirroring the
  /// foreground-FCM-message wiring in [_initializeApp] — a single global
  /// stream subscription set up at app init. Handles both cold start
  /// (`getInitialLink`) and warm-resume (`uriLinkStream`) cases; app_links
  /// normalizes both the custom scheme (`yoollive://invite/{token}`) and the
  /// HTTPS App/Universal Link (`https://app.yool.live/invite/{token}`) into
  /// a plain [Uri], so both are handled the same way in [_handleIncomingLink].
  void _initDeepLinks() {
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingLink(uri);
    }).catchError((_) {});
    _inviteLinkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  /// Extracts `{token}` from an invite URI in either shape:
  ///  - custom scheme `yoollive://invite/{token}` → host == 'invite',
  ///    pathSegments == ['{token}']
  ///  - HTTPS `https://app.yool.live/invite/{token}` → pathSegments ==
  ///    ['invite', '{token}']
  /// Any other URI (e.g. an unrelated link) is ignored.
  void _handleIncomingLink(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String? token;
    if (uri.host == 'invite' && segments.isNotEmpty) {
      token = segments.first;
    } else if (segments.length >= 2 && segments[0] == 'invite') {
      token = segments[1];
    }
    if (token != null && token.isNotEmpty) {
      _store.setPendingInvite(token);
    }
  }

  // Re-evaluate stream whenever store changes (load accepted, completed, logout).
  // Synchronous — no I/O, uses cached _permissionGranted.
  void _onStoreChanged() => _syncGpsStream();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed &&
        (Platform.isAndroid || Platform.isIOS)) {
      // User may have changed permission in Settings — re-read from OS.
      LocationPermissionService.isAlwaysGranted().then((granted) {
        _permissionGranted = granted;
        _store.setLocationPermissionGranted(granted);
        _syncGpsStream();
        _checkAlwaysLocationPermission();
      });
    }
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
    _store.setGpsEnabled(_gpsEnabled);

    await Future.wait([
      _store.init(),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (mounted) _showSplash.value = false;

    // Start polling GPS status every 2 seconds
    _startGpsPolling();

    // Populate permission cache, then sync stream (activeLoad is now known too).
    _permissionGranted = await LocationPermissionService.isAlwaysGranted();
    _store.setLocationPermissionGranted(_permissionGranted);
    _syncGpsStream();

    // Check for "Always" location permission after splash is gone
    // (delayed so the navigator context is available), then re-sync stream.
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkAlwaysLocationPermission();
        _syncGpsStream();
      });
    }
  }

  /// Starts or stops the stream based on cached state — no I/O.
  /// Call _permissionGranted = await isAlwaysGranted() before this whenever
  /// the permission state may have changed (app resume, permission flow).
  void _syncGpsStream() {
    final shouldRun = _gpsEnabled && (_store.activeLoad != null) && _permissionGranted;

    if (shouldRun && !_streamActive) {
      _streamActive = true;
      _gps.startPositionStream(_handlePosition).catchError((_) {
        _streamActive = false;
      });
    } else if (!shouldRun && _streamActive) {
      _streamActive = false;
      _gps.stopPositionStream();
    }
  }

  /// Ensures the "Always" location permission is granted. When the OS prompt
  /// would actually appear, first shows an in-app prominent disclosure
  /// explaining the background location collection and requires the user to
  /// explicitly consent (Google Play's Prominent Disclosure & Consent
  /// Requirement) before triggering the native OS prompt. The result is
  /// mirrored into the store, which drives the Loads-screen blocking overlay.
  /// Returns true once Always is confirmed.
  Future<bool> _checkAlwaysLocationPermission() async {
    final isAlways = await LocationPermissionService.isAlwaysGranted();
    if (isAlways) {
      _permissionGranted = true;
      _store.setLocationPermissionGranted(true);
      return true;
    }

    if (await LocationPermissionService.canPromptForAlways()) {
      final ctx = _navigatorKey.currentContext;
      final consented =
          ctx != null && mounted && await LocationDisclosureDialog.show(ctx);
      if (consented) {
        await LocationPermissionService.enforceAlwaysPermission();
      }
    }

    _permissionGranted = await LocationPermissionService.isAlwaysGranted();
    _store.setLocationPermissionGranted(_permissionGranted);
    return _permissionGranted;
  }

  /// Polls GPS enabled status every 2 seconds, mirroring the state into the
  /// store (which drives the Loads-screen blocking overlay) and re-syncing the
  /// position stream on each on/off transition.
  void _startGpsPolling() {
    _gpsPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (isEnabled == _gpsEnabled) return;

      _gpsEnabled = isEnabled;
      _store.setGpsEnabled(isEnabled);
      _syncGpsStream();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    _gpsPoller?.cancel();
    _inviteLinkSub?.cancel();
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
        if (store.pendingVerificationEmail != null) return VerifyEmailScreen(store: store);
        // An incoming driver-invite link takes priority over the normal
        // language/onboarding/login chain — tapping the link should land
        // straight on the offer (which itself prompts to log in/register
        // when needed), skipping the first-run screens. But if the account
        // is already logged in, let it finish profile setup first (below)
        // before showing the invite, rather than accepting a load with an
        // incomplete profile.
        if (store.pendingInviteToken != null &&
            (!store.isLoggedIn || store.isProfileCompleted)) {
          return AcceptInviteScreen(store: store, token: store.pendingInviteToken!);
        }
        if (!store.isLoggedIn) {
          if (!store.seenLanguage) return LanguageSelectScreen(store: store);
          if (!store.seenOnboarding) return OnboardingScreen(store: store);
          return LoginScreen(store: store);
        }
        if (!store.isProfileCompleted) return ProfileSetupScreen(store: store);
        return MainShell(store: store);
      },
    );
  }
}
