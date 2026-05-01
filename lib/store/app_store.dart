import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../models/load.dart';
import '../models/tracking_point.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/locale_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';

/// Central state management for the app.
class AppStore extends ChangeNotifier {
  AppStore() {
    _nowUtc = DateTime.now().toUtc();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowUtc = DateTime.now().toUtc();
      _checkSilenceAlerts();
      notifyListeners();
    });
    _loadSavedLocale();
    _loadSavedTheme();
  }

  final ApiService _api = ApiService.instance;

  Timer? _clockTimer;
  Timer? _locationTimer;
  DateTime _nowUtc = DateTime.now().toUtc();

  Future<void> init() async {
    await _api.init();
    if (_api.hasToken) {
      isLoggedIn = true;
      notifyListeners();
      await _loadProfile();
      await fetchLoads();
      _startLocationTimer();
      NotificationService.instance.initialize().catchError((_) {});
    }
  }

  // ─── Auth state ─────────────────────────────────────────────────────────

  bool isLoggedIn = false;
  bool isLoading = false;

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

  // Per-load tracking state (keyed by load id)
  final Map<String, TrackingPoint?> _lastLocalPoints = {};
  final Map<String, TrackingPoint?> _lastDeliveredPoints = {};
  final Map<String, List<TrackingPoint>> _offlineBuffers = {};
  final Map<String, bool> _silenceAlertSent = {};
  final Map<String, DateTime?> _silenceAlertAt = {};

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

  TrackingPoint? lastLocalPoint(String loadId) => _lastLocalPoints[loadId];
  TrackingPoint? lastDeliveredPoint(String loadId) =>
      _lastDeliveredPoints[loadId];
  int offlineBufferCount(String loadId) => _offlineBuffers[loadId]?.length ?? 0;
  int get totalOfflineBufferCount {
    int total = 0;
    for (final buf in _offlineBuffers.values) {
      total += buf.length;
    }
    return total;
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _clockTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  // ─── GPS callback ───────────────────────────────────────────────────────

  void onGpsPosition(Position position) {
    _lastGpsPosition = position;
    if (!networkOnline) return;
    if (_activeLoad != null && _activeLoad!.status.isActive) {
      _sendGpsPointToApi(_activeLoad!, position);
    }
  }

  // ─── Periodic location reporting ────────────────────────────────────────

  /// Starts (or restarts) a timer that sends the current GPS position to the
  /// backend every 10 minutes, even when the device is stationary.
  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _sendCurrentLocation();
    });
  }

  /// Sends the most recent GPS fix for the active load, if one exists.
  void _sendCurrentLocation() {
    if (_activeLoad == null || !_activeLoad!.status.isActive) return;
    if (_lastGpsPosition == null) return;
    _sendGpsPointToApi(_activeLoad!, _lastGpsPosition!);
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
        isLoggedIn = true;
        await _loadProfile();
        await fetchLoads();
        NotificationService.instance.initialize().catchError((_) {});
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

  Future<void> logout() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    await stopBackgroundService();
    await clearBgActiveLoad();
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
    _lastLocalPoints.clear();
    _lastDeliveredPoints.clear();
    _offlineBuffers.clear();
    _silenceAlertSent.clear();
    _silenceAlertAt.clear();
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

  Future<void> acceptLoad(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.acceptLoad(loadId);
      if (success) {
        await fetchLoads();
        if (profile != null && _api.accessToken != null) {
          await setBgActiveLoad(
            loadId: _activeLoad?.id ?? loadId,
            carrierId: profile!.id,
            token: _api.accessToken!,
          );
          await startBackgroundService();
        }
        _sendCurrentLocation();
        _startLocationTimer();
      }
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> beginPickup(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.beginPickup(loadId);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> confirmPickup(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.confirmPickup(loadId);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> startLoad(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.startLoad(loadId);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> beginDropoff(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      final success = await _api.beginDropoff(loadId);
      if (success) await fetchLoads();
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  Future<void> confirmDropoff(String loadId) async {
    _loadingIds.add(loadId);
    notifyListeners();
    try {
      _sendCurrentLocation();
      final success = await _api.confirmDropoff(loadId);
      if (success) {
        _locationTimer?.cancel();
        _locationTimer = null;
        await stopBackgroundService();
        await clearBgActiveLoad();
        _offlineBuffers.remove(loadId);
        _lastLocalPoints.remove(loadId);
        _lastDeliveredPoints.remove(loadId);
        _silenceAlertSent.remove(loadId);
        _silenceAlertAt.remove(loadId);
        await fetchLoads();
      }
    } catch (_) {}
    _loadingIds.remove(loadId);
    notifyListeners();
  }

  // ─── Tracking ───────────────────────────────────────────────────────────

  Future<void> _sendGpsPointToApi(LoadItem load, Position pos) async {
    final point = TrackingPoint(
      timestampUtc: DateTime.now().toUtc(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedKmh: pos.speed * 3.6,
      accuracyM: pos.accuracy,
      headingDeg: pos.heading,
    );
    _lastLocalPoints[load.id] = point;

    if (networkOnline) {
      final buffer = _offlineBuffers[load.id];
      if (buffer != null && buffer.isNotEmpty) {
        await _flushBuffer(load.id);
      }
      await _deliverPoint(load, point);
    } else {
      _offlineBuffers.putIfAbsent(load.id, () => []).add(point);
    }
    notifyListeners();
  }

  Future<void> _deliverPoint(LoadItem load, TrackingPoint point) async {
    try {
      final ok = await _api.registerLocation(
        loadId: load.id,
        carrierId: profile?.id ?? '',
        lat: point.latitude,
        lng: point.longitude,
        speedMps: point.speedMps,
        accuracyM: point.accuracyM,
        headingDeg: point.headingDeg,
        recordedAt: point.timestampUtc,
      );
      if (ok) {
        _lastDeliveredPoints[load.id] = point;
        _silenceAlertSent[load.id] = false;
        _silenceAlertAt[load.id] = null;
      }
    } catch (_) {
      _offlineBuffers.putIfAbsent(load.id, () => []).add(point);
    }
  }

  Future<void> _flushBuffer(String loadId) async {
    final buffer = _offlineBuffers[loadId];
    if (buffer == null || buffer.isEmpty) return;
    final points = List<TrackingPoint>.from(buffer);
    points.sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
    buffer.clear();

    // Find the load for delivering
    LoadItem? load = _activeLoad?.id == loadId ? _activeLoad : null;
    if (load == null) {
      for (final l in _allLoads) {
        if (l.id == loadId) {
          load = l;
          break;
        }
      }
    }
    if (load == null) return;

    for (final point in points) {
      await _deliverPoint(load, point);
    }
  }

  void setNetworkOnline(bool value) {
    if (networkOnline == value) return;
    networkOnline = value;
    if (value) {
      // Flush all offline buffers
      for (final loadId in _offlineBuffers.keys.toList()) {
        _flushBuffer(loadId);
      }
    }
    notifyListeners();
  }

  void _checkSilenceAlerts() {
    if (_activeLoad == null || !_activeLoad!.status.isActive) return;
    final loadId = _activeLoad!.id;

    DateTime? lastSeen;
    final delivered = _lastDeliveredPoints[loadId];
    if (delivered != null) {
      lastSeen = delivered.timestampUtc;
    }
    if (lastSeen == null) return;

    final silence = _nowUtc.difference(lastSeen);
    if (silence >= const Duration(seconds: 10) &&
        _silenceAlertSent[loadId] != true) {
      _silenceAlertSent[loadId] = true;
      _silenceAlertAt[loadId] = _nowUtc;
      // In a full implementation, this would trigger a push notification
    }
  }
}
