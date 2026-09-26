import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/load.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/debug_service.dart';
import '../services/first_run_service.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../tracking/tracker_core.dart';
import '../tracking/tracker_runner.dart';

/// Central state management for the app.
class AppStore extends ChangeNotifier {
  AppStore() {
    _nowUtc = DateTime.now().toUtc();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _nowUtc = DateTime.now().toUtc();
      if (t.tick % 5 == 0) _refreshPendingCounts();
      notifyListeners();
    });
    _loadSavedLocale();
    _loadSavedTheme();
    _firstRunLoaded = _loadFirstRunFlags();
  }

  late final Future<void> _firstRunLoaded;

  final ApiService _api = ApiService.instance;

  Timer? _clockTimer;
  DateTime _nowUtc = DateTime.now().toUtc();

  Future<void> init() async {
    await Future.wait([
      _api.init(),
      _firstRunLoaded,
    ]);
    if (_api.hasToken) {
      isLoggedIn = true;
      notifyListeners();
      await _loadProfile();
      await fetchLoads();
      NotificationService.instance.initialize().catchError((_) {});
    }
  }

  // ─── Auth state ─────────────────────────────────────────────────────────

  bool isLoggedIn = false;
  bool isLoading = false;
  String? pendingVerificationEmail;

  // ─── Driver-invite-by-link ──────────────────────────────────────────────
  // Set when the app is opened via an `https://app.yool.live/invite/{token}`
  // or `yoollive://invite/{token}` deep link (see app.dart). Mirrors the
  // pendingVerificationEmail pattern: a nullable field gating what
  // _HomeRouter shows, cleared once the invite flow is resolved.
  String? pendingInviteToken;

  void setPendingInvite(String token) {
    pendingInviteToken = token;
    notifyListeners();
  }

  void clearPendingInvite() {
    if (pendingInviteToken == null) return;
    pendingInviteToken = null;
    notifyListeners();
  }

  // Per-load loading state — keyed by load id.
  final Set<String> _loadingIds = {};

  bool isLoadingId(String id) => _loadingIds.contains(id);

  // ─── Locale ──────────────────────────────────────────────────────────

  static const String _profileKey = 'cached_profile';

  String _locale = 'en';

  String get locale => _locale;

  Future<void> _loadSavedLocale() async {
    _locale = await LocaleService.loadLocale();
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (_locale == code) return;
    _locale = code;
    await LocaleService.saveLocale(code);
    notifyListeners();
  }

  // ─── Theme ───────────────────────────────────────────────────────────

  bool _isDarkTheme = true;

  bool get isDarkTheme => _isDarkTheme;

  Future<void> _loadSavedTheme() async {
    _isDarkTheme = await ThemeService.loadIsDark();
    notifyListeners();
  }

  Future<void> setDarkTheme(bool isDark) async {
    if (_isDarkTheme == isDark) return;
    _isDarkTheme = isDark;
    await ThemeService.saveIsDark(isDark);
    notifyListeners();
  }

  // ─── First-run flags ─────────────────────────────────────────────────

  bool _seenLanguage = false;
  bool _seenOnboarding = false;

  bool get seenLanguage => _seenLanguage;
  bool get seenOnboarding => _seenOnboarding;

  Future<void> _loadFirstRunFlags() async {
    _seenLanguage = await FirstRunService.hasSeenLanguage();
    _seenOnboarding = await FirstRunService.hasSeenOnboarding();
    notifyListeners();
  }

  Future<void> markLanguageSeen() async {
    if (_seenLanguage) return;
    _seenLanguage = true;
    await FirstRunService.markLanguageSeen();
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    if (_seenOnboarding) return;
    _seenOnboarding = true;
    await FirstRunService.markOnboardingSeen();
    notifyListeners();
  }

  // ─── Profile ────────────────────────────────────────────────────────────

  UserProfile? profile;

  bool get isProfileCompleted => profile != null && profile!.isProfileComplete;

  // ─── Loads ──────────────────────────────────────────────────────────────

  final List<LoadItem> _pendingLoads = [];
  LoadItem? _activeLoad;
  final List<LoadItem> _allLoads = [];
  final List<LoadItem> _historyLoads = [];

  // ─── Pagination ─────────────────────────────────────────────────────────
  int _pendingOffset = 0;
  bool _hasMorePending = true;
  bool _isFetchingPending = false;
  int _historyOffset = 0;
  bool _hasMoreHistory = true;
  bool _isFetchingHistory = false;
  bool _isInitialFetching = false;

  // ─── Tracking ───────────────────────────────────────────────────────────

  bool networkOnline = true;
  Position? _lastGpsPosition;

  // ─── GPS / location-permission blocking state ─────────────────────────────
  // Mirrored from the root widget (app.dart) so the Loads screen can react and
  // show its frosted blocking overlay. Default true → no overlay flash before
  // the first GPS/permission check completes.
  bool _gpsEnabled = true;
  bool _locationPermissionGranted = true;
  bool _preciseLocationGranted = true;

  bool get gpsEnabled => _gpsEnabled;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get preciseLocationGranted => _preciseLocationGranted;

  /// True when the Loads content should be obscured by the blocking overlay.
  bool get loadsBlocked =>
      !_gpsEnabled || !_locationPermissionGranted || !_preciseLocationGranted;

  void setGpsEnabled(bool value) {
    if (_gpsEnabled == value) return;
    _gpsEnabled = value;
    notifyListeners();
  }

  void setPreciseLocationGranted(bool value) {
    if (_preciseLocationGranted == value) return;
    _preciseLocationGranted = value;
    notifyListeners();
  }

  void setLocationPermissionGranted(bool value) {
    if (_locationPermissionGranted == value) return;
    _locationPermissionGranted = value;
    notifyListeners();
  }

  // Points the tracker has queued but not delivered yet, per load id —
  // polled from the tracker's persisted queue (see _refreshPendingCounts).
  Map<String, int> _pendingCounts = const {};

  // ─── Getters ────────────────────────────────────────────────────────────

  DateTime get nowUtc => _nowUtc;

  List<LoadItem> get pendingLoads => List.unmodifiable(_pendingLoads);

  LoadItem? get activeLoad => _activeLoad;

  List<LoadItem> get allLoads => List.unmodifiable(_allLoads);

  List<LoadItem> get finishedLoads => List.unmodifiable(_historyLoads);

  bool get hasMorePending    => _hasMorePending;
  bool get isFetchingPending => _isFetchingPending;
  bool get hasMoreHistory    => _hasMoreHistory;
  bool get isFetchingHistory => _isFetchingHistory;
  bool get isInitialFetching => _isInitialFetching;

  Position? get lastGpsPosition => _lastGpsPosition;

  int offlineBufferCount(String loadId) => _pendingCounts[loadId] ?? 0;

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ─── GPS callback ───────────────────────────────────────────────────────

  // Only feeds the UI's "GPS" indicator. Recording and sending points is
  // entirely the tracker's job (tracking/tracker_core.dart).
  void onGpsPosition(Position position) {
    _lastGpsPosition = position;
  }

  // ─── Auth ───────────────────────────────────────────────────────────────

  Future<String?> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.login(
        email: email,
        phone: phone,
        password: password,
      );
      if (result['success'] == true) {
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Login error';
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    required String password,
    required String role,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.register(
        email: email,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        password: password,
        role: role,
      );
      if (result['success'] == true) {
        pendingVerificationEmail = result['email'] as String? ?? email;
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Registration error';
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> verifyEmail(String email, String code) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.verifyEmail(email: email, code: code);
      if (result['success'] == true) {
        pendingVerificationEmail = null;
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Verification error';
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> appleSignIn() async {
    if (!Platform.isIOS) return 'Apple Sign In is only available on iOS';
    isLoading = true;
    notifyListeners();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) return 'Apple Sign In failed: no identity token';

      final result = await _api.appleSignIn(
        idToken: idToken,
        firstName: credential.givenName,
        lastName: credential.familyName,
        role: 'carrier',
      );
      if (result['success'] == true) {
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Apple Sign In error';
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      return 'Apple Sign In error: ${e.message}';
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> telegramSignIn({required String idToken, String role = 'carrier'}) async {
    final log = DebugService.talker;
    log.info(
      '[TG][store] telegramSignIn() start · idToken=${idToken.length} chars role=$role',
    );
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.telegramSignIn(
        idToken: idToken,
        role: role,
      );
      if (result['success'] == true) {
        log.info('[TG][store] backend accepted token — loading profile & loads');
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
        notifyListeners();
        log.info('[TG][store] telegramSignIn() success · isLoggedIn=true');
        return null;
      }
      final message = result['message'] as String? ?? 'Telegram Sign In error';
      log.warning('[TG][store] backend rejected token: $message');
      return message;
    } catch (e, st) {
      log.error('[TG][store] telegramSignIn() threw', e, st);
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Called by TelegramAuthService when the native redirect delivers code+state.
  /// Works for both warm-resume and cold-start (process-death) scenarios.
  Future<void> telegramSignInWithCode({
    required String code,
    required String state,
    required String redirectUri,
  }) async {
    final log = DebugService.talker;
    log.info('[TG][store] telegramSignInWithCode() start · state=$state');
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.telegramCallback(
        code: code,
        state: state,
        redirectUri: redirectUri,
      );
      if (result['success'] == true) {
        log.info('[TG][store] backend accepted code — loading profile & loads');
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
        notifyListeners();
        log.info('[TG][store] telegramSignInWithCode() success');
      } else {
        log.warning('[TG][store] backend rejected code: ${result['message']}');
      }
    } catch (e, st) {
      log.error('[TG][store] telegramSignInWithCode() threw', e, st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteAccount() async {
    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.deleteAccount();
      if (!success) return 'Failed to delete account';
      await logout();
      return null;
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await TrackerRunner.stop();
    await clearBgActiveLoad();
    await clearBgPendingPoints();
    await NotificationService.instance.deactivate();
    await _api.logout();
    // Clear cached profile
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    isLoggedIn = false;
    profile = null;
    _pendingLoads.clear();
    _activeLoad = null;
    _allLoads.clear();
    _historyLoads.clear();
    _pendingOffset = 0;
    _historyOffset = 0;
    _hasMorePending = true;
    _hasMoreHistory = true;
    _isInitialFetching = false;
    _isFetchingPending = false;
    _isFetchingHistory = false;
    _pendingCounts = const {};
    notifyListeners();
  }

  // ─── Profile ────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final me = await _api.getMe();
      if (me != null) {
        profile = UserProfile.fromJson(me);
        // Cache profile locally for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_profileKey, jsonEncode(profile!.toJson()));
        notifyListeners();
        return;
      }
    } catch (_) {
      // Network error — fall through to cached profile
    }
    // Fallback: load cached profile if network failed
    await _loadCachedProfile();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileKey);
    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        profile = UserProfile.fromJson(json);
        notifyListeners();
      } catch (_) {
        // Corrupted cache — ignore
      }
    }
  }

  Future<String?> saveProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (firstName.trim().isEmpty) return 'First name is required';

    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.updateMe(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
      );
      if (!success) return 'Failed to save profile';

      await _loadProfile();
      await fetchLoads();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─── Loads ──────────────────────────────────────────────────────────────

  Future<void> refreshAll() async {
    _isInitialFetching = true;
    _pendingOffset = 0;
    _hasMorePending = true;
    _isFetchingPending = true; // block scroll-triggered loadMorePending() race
    notifyListeners();
    await Future.wait([
      _fetchActive(),
      _fetchPendingPage(reset: true),
    ]);
    _isInitialFetching = false;
    _rebuildAllLoads();
    notifyListeners();
    await _resumeTrackingIfActive();
  }

  Future<void> refreshHistory() async {
    _historyOffset = 0;
    _hasMoreHistory = true;
    await _fetchHistoryPage(reset: true);
    _rebuildAllLoads();
  }

  // Backwards-compatible alias so all existing call sites continue working.
  Future<void> fetchLoads() => refreshAll();

  Future<void> loadMorePending() => _fetchPendingPage();

  Future<void> loadMoreHistory() => _fetchHistoryPage();

  Future<void> _fetchActive() async {
    try {
      final activeResult = await _api.getActiveLoad();
      _activeLoad = activeResult != null
          ? LoadItem.fromJson(activeResult)
          : null;
    } catch (_) {}
  }

  Future<void> _fetchPendingPage({bool reset = false}) async {
    if (!reset && _isFetchingPending) return;
    if (!_hasMorePending && !reset) return;
    _isFetchingPending = true;
    notifyListeners();
    try {
      const limit = 15;
      final offset = reset ? 0 : _pendingOffset;
      final result = await _api.getPendingLoads(limit: limit, offset: offset);
      final raw = result['result'] as List<dynamic>? ?? [];
      if (reset) _pendingLoads.clear();
      for (final item in raw) {
        _pendingLoads.add(LoadItem.fromJson(item as Map<String, dynamic>));
      }
      _pendingOffset = offset + raw.length;
      _hasMorePending = raw.length >= limit;
    } catch (_) {}
    _isFetchingPending = false;
    _rebuildAllLoads();
    notifyListeners();
  }

  Future<void> _fetchHistoryPage({bool reset = false}) async {
    if (_isFetchingHistory) return;
    if (!_hasMoreHistory && !reset) return;
    _isFetchingHistory = true;
    notifyListeners();
    try {
      const limit = 15;
      final offset = reset ? 0 : _historyOffset;
      final result = await _api.getHistoryLoads(limit: limit, offset: offset);
      final raw = result['result'] as List<dynamic>? ?? [];
      if (reset) _historyLoads.clear();
      for (final item in raw) {
        _historyLoads.add(LoadItem.fromJson(item as Map<String, dynamic>));
      }
      _historyOffset = offset + raw.length;
      _hasMoreHistory = raw.length >= limit;
    } catch (_) {}
    _isFetchingHistory = false;
    _rebuildAllLoads();
    notifyListeners();
  }

  void _rebuildAllLoads() {
    _allLoads.clear();
    if (_activeLoad != null) _allLoads.add(_activeLoad!);
    _allLoads.addAll(_pendingLoads);
    _allLoads.addAll(_historyLoads);
  }

  Future<void> acceptLoad(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.acceptLoad(loadId, attachmentIds: attachmentIds);
      if (success) {
        await fetchLoads();
        await _startTracking(_activeLoad?.id ?? loadId);
      }
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  /// Accepts a load offered via a driver-invite link (see AcceptInviteScreen).
  /// The backend performs the same load-assignment side effects as a normal
  /// `POST /loads/{id}/accept`, so this mirrors [acceptLoad]'s post-success
  /// client-side bookkeeping (refresh loads, background tracking) rather than
  /// duplicating it inside the screen, since those are private timers/state.
  ///
  /// Returns the raw API result map — `{'success': true, 'loadId': ...}` or
  /// `{'success': false, 'message': ..., 'statusCode': ...}` — so the caller
  /// can surface the backend's 409 message for already accepted/expired/
  /// revoked invites.
  Future<Map<String, dynamic>> acceptInvite(String token) async {
    isLoading = true;
    notifyListeners();
    try {
      final result = await _api.acceptInvite(token);
      if (result['success'] == true) {
        clearPendingInvite();
        await fetchLoads();
        final loadId = result['loadId'] as String?;
        final trackedId = _activeLoad?.id ?? loadId;
        if (trackedId != null) await _startTracking(trackedId);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> beginPickup(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.beginPickup(loadId, attachmentIds: attachmentIds);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> confirmPickup(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.confirmPickup(loadId, attachmentIds: attachmentIds);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> startLoad(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.startLoad(loadId, attachmentIds: attachmentIds);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> beginDropoff(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.beginDropoff(loadId, attachmentIds: attachmentIds);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> confirmDropoff(String loadId, {List<String>? attachmentIds}) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      // Get the tail of the trip out while the tracker is still running —
      // anything left over still flushes later, tagged with its own load_id,
      // so a slow network must not hold up the driver's button for long.
      await TrackerRunner.flushNow()
          .timeout(const Duration(seconds: 10), onTimeout: () {});
      final success = await _api.confirmDropoff(loadId, attachmentIds: attachmentIds);
      if (success) {
        await TrackerRunner.stop();
        await clearBgActiveLoad();
        await fetchLoads();
      }
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  // ─── Tracking ───────────────────────────────────────────────────────────

  /// Hands the load to the tracker and starts it (idempotent — a running
  /// tracker is left alone).
  Future<void> _startTracking(String loadId) async {
    if (profile == null || _api.accessToken == null) return;
    await setBgActiveLoad(
      loadId: loadId,
      carrierId: profile!.id,
      token: _api.accessToken!,
    );
    await TrackerRunner.start();
  }

  /// Resumes tracking for a load that is already active — after an app
  /// restart, a phone reboot, or logging back in — instead of only ever
  /// starting it at the moment a load is accepted.
  ///
  /// Deliberately never STOPS tracking: getActiveLoad() returns null on any
  /// failed request too, so "no active load" here can't be told apart from
  /// a network blip. Stopping stays tied to confirmDropoff/logout.
  Future<void> _resumeTrackingIfActive() async {
    final load = _activeLoad;
    if (load == null || !_isTrackedStatus(load.status)) return;
    await _startTracking(load.id);
  }

  /// Statuses during which the truck is on the road and gets tracked. Not
  /// the same as LoadStatus.isActive: that one also covers droppedOff (the
  /// load still shows as active while the shipper hasn't confirmed), but
  /// the driver's job is done by then — resuming there would restart the
  /// tracker the moment confirmDropoff stopped it.
  static bool _isTrackedStatus(LoadStatus status) {
    switch (status) {
      case LoadStatus.accepted:
      case LoadStatus.pickingUp:
      case LoadStatus.pickedUp:
      case LoadStatus.inTransit:
      case LoadStatus.droppingOff:
        return true;
      default:
        return false;
    }
  }

  Future<void> _refreshPendingCounts() async {
    try {
      final counts = await TrackerRunner.pendingCounts();
      if (mapEquals(counts, _pendingCounts)) return;
      _pendingCounts = counts;
      notifyListeners();
    } catch (_) {}
  }

  void setNetworkOnline(bool value) {
    if (networkOnline == value) return;
    networkOnline = value;
    // Don't make a backlog built up offline wait for the next tick.
    if (value) TrackerRunner.flushNow();
    notifyListeners();
  }
}
