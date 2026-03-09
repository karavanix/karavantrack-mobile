import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/load.dart';
import '../models/tracking_point.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// Central state management for the app.
class AppStore extends ChangeNotifier {
  AppStore() {
    _nowUtc = DateTime.now().toUtc();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowUtc = DateTime.now().toUtc();
      _checkSilenceAlerts();
      notifyListeners();
    });
  }

  final ApiService _api = ApiService.instance;

  Timer? _clockTimer;
  DateTime _nowUtc = DateTime.now().toUtc();

  // ─── Auth state ─────────────────────────────────────────────────────────

  bool isLoggedIn = false;
  bool isLoading = false;

  // ─── Profile ────────────────────────────────────────────────────────────

  UserProfile? profile;

  bool get isProfileCompleted => profile != null && profile!.isProfileComplete;

  // ─── Loads ──────────────────────────────────────────────────────────────

  final List<LoadItem> _pendingLoads = [];
  LoadItem? _activeLoad;
  final List<LoadItem> _allLoads = [];

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

  List<LoadItem> get finishedLoads =>
      _allLoads.where((l) => l.status.isFinal).toList();

  Position? get lastGpsPosition => _lastGpsPosition;

  TrackingPoint? lastLocalPoint(String loadId) => _lastLocalPoints[loadId];
  TrackingPoint? lastDeliveredPoint(String loadId) =>
      _lastDeliveredPoints[loadId];
  int offlineBufferCount(String loadId) =>
      _offlineBuffers[loadId]?.length ?? 0;
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
    await _api.logout();
    isLoggedIn = false;
    profile = null;
    _pendingLoads.clear();
    _activeLoad = null;
    _allLoads.clear();
    _lastLocalPoints.clear();
    _lastDeliveredPoints.clear();
    _offlineBuffers.clear();
    _silenceAlertSent.clear();
    _silenceAlertAt.clear();
    notifyListeners();
  }

  // ─── Profile ────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final me = await _api.getMe();
    if (me == null) return;
    profile = UserProfile.fromJson(me);
    notifyListeners();
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

  Future<void> fetchLoads() async {
    try {
      // Fetch pending loads
      final pendingResult = await _api.getPendingLoads(limit: 50);
      final rawList = pendingResult['result'] as List<dynamic>? ?? [];
      _pendingLoads.clear();
      for (final item in rawList) {
        _pendingLoads.add(LoadItem.fromJson(item as Map<String, dynamic>));
      }

      // Fetch active load
      final activeResult = await _api.getActiveLoad();
      if (activeResult != null) {
        _activeLoad = LoadItem.fromJson(activeResult);
      } else {
        _activeLoad = null;
      }

      // Build combined list
      _allLoads.clear();
      if (_activeLoad != null) _allLoads.add(_activeLoad!);
      _allLoads.addAll(_pendingLoads);

      notifyListeners();
    } catch (_) {}
  }

  Future<void> acceptLoad(String loadId) async {
    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.acceptLoad(loadId);
      if (success) {
        await fetchLoads();
        // Send initial GPS point if available
        if (_activeLoad != null && _lastGpsPosition != null) {
          _sendGpsPointToApi(_activeLoad!, _lastGpsPosition!);
        }
      }
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  Future<void> startLoad(String loadId) async {
    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.startLoad(loadId);
      if (success) await fetchLoads();
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  Future<void> completeLoad(String loadId) async {
    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.completeLoad(loadId);
      if (success) {
        _offlineBuffers.remove(loadId);
        _lastLocalPoints.remove(loadId);
        _lastDeliveredPoints.remove(loadId);
        _silenceAlertSent.remove(loadId);
        _silenceAlertAt.remove(loadId);
        await fetchLoads();
      }
    } catch (_) {}
    isLoading = false;
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

        // Auto-transition: accepted → in_transit when moving
        if (load.status == LoadStatus.accepted && point.speedKmh > 1) {
          await _api.startLoad(load.id);
          load.status = LoadStatus.inTransit;
        }
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
    if (silence >= const Duration(minutes: 10) &&
        _silenceAlertSent[loadId] != true) {
      _silenceAlertSent[loadId] = true;
      _silenceAlertAt[loadId] = _nowUtc;
      // In a full implementation, this would trigger a push notification
    }
  }
}
