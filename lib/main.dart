import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'gps.dart';

// ---------------------------------------------------------------------------
// API Configuration
// ---------------------------------------------------------------------------
const String _kBaseUrl = 'https://api.yool.live/'; // <-- set your host
const String _kBasePath = '/api/v1';

String _url(String path) => '$_kBaseUrl$_kBasePath$path';

// ---------------------------------------------------------------------------
// API Service
// ---------------------------------------------------------------------------
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _accessToken;
  String? _refreshToken;

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  void setTokens({required String access, required String refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  bool get hasToken => _accessToken != null;

  // Refresh access token using refresh token
  Future<bool> refreshTokens() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(_url('/auth/refresh')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        _refreshToken = data['refresh_token'] as String?;
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Perform authenticated request, auto-refresh on 401
  Future<http.Response> _authedRequest(
    Future<http.Response> Function() fn,
  ) async {
    final resp = await fn();
    if (resp.statusCode == 401 && _refreshToken != null) {
      final refreshed = await refreshTokens();
      if (refreshed) {
        return fn();
      }
    }
    return resp;
  }

  // POST /auth/login
  Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    final response = await http.post(
      Uri.parse(_url('/auth/login')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return {'success': true, 'data': data};
    }
    final err = _parseError(response);
    return {'success': false, 'message': err};
  }

  // POST /auth/register
  Future<Map<String, dynamic>> register({
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    required String password,
    required String role, // 'shipper' | 'carrier'
  }) async {
    final body = <String, dynamic>{'password': password, 'role': role};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (firstName != null && firstName.isNotEmpty)
      body['first_name'] = firstName;
    if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;

    final response = await http.post(
      Uri.parse(_url('/auth/register')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['access_token'] != null) {
        setTokens(
          access: data['access_token'] as String,
          refresh: data['refresh_token'] as String,
        );
      }
      return {'success': true, 'data': data};
    }
    final err = _parseError(response);
    return {'success': false, 'message': err};
  }

  // POST /auth/logout
  Future<void> logout() async {
    try {
      await _authedRequest(
        () => http.post(Uri.parse(_url('/auth/logout')), headers: _authHeaders),
      );
    } catch (_) {}
    clearTokens();
  }

  // GET /users/me
  Future<Map<String, dynamic>?> getMe() async {
    final response = await _authedRequest(
      () => http.get(Uri.parse(_url('/users/me')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // PUT /users/me
  Future<bool> updateMe({String? firstName, String? lastName}) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;

    final response = await _authedRequest(
      () => http.put(
        Uri.parse(_url('/users/me')),
        headers: _authHeaders,
        body: jsonEncode(body),
      ),
    );
    return response.statusCode == 200;
  }

  // POST /users/me/devices
  Future<void> registerDevice({
    required String deviceId,
    required String deviceToken,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      final body = <String, dynamic>{
        'device_id': deviceId,
        'device_token': deviceToken,
        if (deviceName != null) 'device_name': deviceName,
        if (deviceType != null) 'device_type': deviceType,
      };
      await _authedRequest(
        () => http.post(
          Uri.parse(_url('/users/me/devices')),
          headers: _authHeaders,
          body: jsonEncode(body),
        ),
      );
    } catch (_) {}
  }

  // GET /loads
  Future<List<Map<String, dynamic>>> getLoads({
    String? companyId,
    String? carrierId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{};
    if (companyId != null) params['company_id'] = companyId;
    if (carrierId != null) params['carrier_id'] = carrierId;
    if (status != null) params['status'] = status;
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final uri = Uri.parse(
      _url('/loads'),
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await _authedRequest(
      () => http.get(uri, headers: _authHeaders),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // GET /loads/{id}
  Future<Map<String, dynamic>?> getLoad(String id) async {
    final response = await _authedRequest(
      () => http.get(Uri.parse(_url('/loads/$id')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // POST /loads/{id}/accept
  Future<bool> acceptLoad(String id) async {
    final response = await _authedRequest(
      () => http.post(
        Uri.parse(_url('/loads/$id/accept')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  // POST /loads/{id}/start
  Future<bool> startLoad(String id) async {
    final response = await _authedRequest(
      () =>
          http.post(Uri.parse(_url('/loads/$id/start')), headers: _authHeaders),
    );
    return response.statusCode == 200;
  }

  // POST /loads/{id}/complete
  Future<bool> completeLoad(String id) async {
    final response = await _authedRequest(
      () => http.post(
        Uri.parse(_url('/loads/$id/complete')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  // POST /loads/{id}/location
  Future<bool> registerLocation({
    required String loadId,
    required String carrierId,
    required double lat,
    required double lng,
    required double speedMps,
    required double accuracyM,
    double? headingDeg,
    required DateTime recordedAt,
  }) async {
    final body = <String, dynamic>{
      'load_id': loadId,
      'carrier_id': carrierId,
      'lat': lat,
      'lng': lng,
      'speed_mps': speedMps,
      'accuracy_m': accuracyM,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      if (headingDeg != null) 'heading_deg': headingDeg,
    };
    final response = await _authedRequest(
      () => http.post(
        Uri.parse(_url('/loads/$loadId/location')),
        headers: _authHeaders,
        body: jsonEncode(body),
      ),
    );
    return response.statusCode == 200;
  }

  // GET /users/shippers/search
  Future<List<Map<String, dynamic>>> searchShippers(String query) async {
    final uri = Uri.parse(
      _url('/users/shippers/search'),
    ).replace(queryParameters: {'q': query});
    final response = await _authedRequest(
      () => http.get(uri, headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // GET /companies/{id}
  Future<Map<String, dynamic>?> getCompany(String id) async {
    final response = await _authedRequest(
      () => http.get(Uri.parse(_url('/companies/$id')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['message'] as String?) ?? 'Ошибка ${response.statusCode}';
    } catch (_) {
      return 'Ошибка ${response.statusCode}';
    }
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
void main() {
  runApp(const DriverTrackingApp());
}

class DriverTrackingApp extends StatefulWidget {
  const DriverTrackingApp({Key? key, this.store}) : super(key: key);

  final AppStore? store;

  @override
  State<DriverTrackingApp> createState() => _DriverTrackingAppState();
}

class _DriverTrackingAppState extends State<DriverTrackingApp> {
  final GPS _gps = GPS();
  late final AppStore _store;
  bool _showSplash = true;
  Timer? _splashTimer;

  void _handlePositionStream(Position position) {
    setState(() {});
    _store.onGpsPosition(position);
  }

  @override
  void initState() {
    super.initState();
    _gps.startPositionStream(_handlePositionStream);
    _store = widget.store ?? AppStore();
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
      title: 'Yool Driver Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
      ),
      home: _showSplash ? const SplashScreen() : RootFlow(store: _store),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF0F172A), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(Icons.local_shipping_rounded, color: Colors.white, size: 72),
              SizedBox(height: 16),
              Text(
                'Yool Driver Tracking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RootFlow extends StatelessWidget {
  const RootFlow({Key? key, required this.store}) : super(key: key);

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (BuildContext context, Widget? child) {
        if (!store.isLoggedIn) return LoginScreen(store: store);
        if (!store.isProfileCompleted) return ProfileSetupScreen(store: store);
        return MainShell(store: store);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Enums & Models
// ---------------------------------------------------------------------------
enum LoadStatus {
  assigned,
  accepted,
  inTransit,
  completed,
  cancelled,
  rejected,
}

enum AssignmentMethod { inviteLink, contact }

enum RejectReason { busy, routeMismatch, badPrice, other }

enum NoticeAudience { driver, shipper }

class DriverProfile {
  DriverProfile({
    required this.fullName,
    required this.phone,
    this.email,
    this.vehicleNumber,
    this.vehicleType,
    required this.consentAccepted,
    this.userId,
  });

  String fullName;
  String phone;
  String? email;
  String? vehicleNumber;
  String? vehicleType;
  bool consentAccepted;
  String? userId; // from API /users/me response
}

class TrackingPoint {
  TrackingPoint({
    required this.timestampUtc,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.accuracyM,
    required this.deviceId,
    required this.driverId,
    required this.loadId,
  });

  final DateTime timestampUtc;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double accuracyM;
  final String deviceId;
  final String driverId;
  final String loadId;
}

class AppNotice {
  AppNotice({
    required this.timestampUtc,
    required this.audience,
    required this.message,
    required this.title,
  });

  final DateTime timestampUtc;
  final NoticeAudience audience;
  final String message;
  final String title;
}

class AuditEvent {
  AuditEvent({
    required this.timestampUtc,
    required this.type,
    required this.message,
  });

  final DateTime timestampUtc;
  final String type;
  final String message;
}

class LoadItem {
  LoadItem({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.description,
    required this.shipperContact,
    required this.createdAtUtc,
    this.plannedAtUtc,
    required this.assignmentMethod,
    this.assignedPhone,
    this.assignedEmail,
    this.inviteToken,
    this.inviteExpiresAtUtc,
    required this.pickupLat,
    required this.pickupLon,
    required this.dropoffLat,
    required this.dropoffLon,
    this.isVisibleToCurrentDriver = false,
    this.pendingDriverRegistration = false,
  });

  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final String description;
  final String shipperContact;
  final DateTime createdAtUtc;
  final DateTime? plannedAtUtc;
  final AssignmentMethod assignmentMethod;
  final String? assignedPhone;
  final String? assignedEmail;
  final String? inviteToken;
  final DateTime? inviteExpiresAtUtc;

  final double pickupLat;
  final double pickupLon;
  final double dropoffLat;
  final double dropoffLon;

  LoadStatus status = LoadStatus.assigned;
  bool isVisibleToCurrentDriver;
  bool pendingDriverRegistration;
  bool inviteConsumed = false;
  bool inviteOpenedByDriver = false;

  DateTime? acceptedAtUtc;
  DateTime? completedAtUtc;
  DateTime? cancelledAtUtc;
  DateTime? rejectedAtUtc;
  String? rejectReasonLabel;

  double routeProgress = 0.0;
  bool moving = true;
  DateTime? nextTrackingDueUtc;

  TrackingPoint? lastLocalPoint;
  TrackingPoint? lastDeliveredPoint;
  final List<TrackingPoint> offlineBuffer = <TrackingPoint>[];

  bool silenceAlertSent = false;
  DateTime? silenceAlertAtUtc;

  bool get isActive =>
      status == LoadStatus.accepted || status == LoadStatus.inTransit;

  bool get isFinal =>
      status == LoadStatus.completed ||
      status == LoadStatus.cancelled ||
      status == LoadStatus.rejected;

  // Parse from API response (query.LoadResponse)
  static LoadItem fromApiJson(Map<String, dynamic> json) {
    LoadStatus status = LoadStatus.assigned;
    final String rawStatus = (json['status'] as String? ?? '').toLowerCase();
    switch (rawStatus) {
      case 'accepted':
        status = LoadStatus.accepted;
        break;
      case 'in_transit':
      case 'intransit':
        status = LoadStatus.inTransit;
        break;
      case 'completed':
        status = LoadStatus.completed;
        break;
      case 'cancelled':
        status = LoadStatus.cancelled;
        break;
      case 'rejected':
        status = LoadStatus.rejected;
        break;
    }

    final item = LoadItem(
      id: json['id'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffAddress: json['dropoff_address'] as String? ?? '',
      description:
          json['description'] as String? ?? json['title'] as String? ?? '',
      shipperContact: json['member_id'] as String? ?? '',
      createdAtUtc:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      plannedAtUtc: json['pickup_at'] != null
          ? DateTime.tryParse(json['pickup_at'] as String)
          : null,
      assignmentMethod: AssignmentMethod.contact,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLon: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
      dropoffLon: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      isVisibleToCurrentDriver: true,
    );
    item.status = status;
    return item;
  }
}

// ---------------------------------------------------------------------------
// AppStore — replaces DemoStore, wires to real API
// ---------------------------------------------------------------------------
class AppStore extends ChangeNotifier {
  AppStore() {
    _nowUtc = DateTime.now().toUtc();
    // Update clock every second for UI timestamps
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _nowUtc = DateTime.now().toUtc();
      _checkSilenceAlerts();
      notifyListeners();
    });
  }

  final ApiService _api = ApiService.instance;
  final String deviceId = 'app-device-001';

  Timer? _clockTimer;
  DateTime _nowUtc = DateTime.now().toUtc();
  bool _permissionIncidentOpen = false;

  bool isLoggedIn = false;
  bool isLoading = false;
  String loggedInPhone = '';
  String loggedInEmail = '';

  DriverProfile? profile;

  bool locationServicesEnabled = true;
  bool locationAlwaysEnabled = true;
  bool backgroundUpdatesEnabled = true;
  bool networkOnline = true;

  final List<LoadItem> _loads = <LoadItem>[];
  final List<AppNotice> _notices = <AppNotice>[];
  final List<AuditEvent> _events = <AuditEvent>[];

  String? selectedShipperLoadId;

  Position? _lastGpsPosition;

  DateTime get nowUtc => _nowUtc;

  bool get isProfileCompleted => profile != null;

  bool get driverPermissionsReady =>
      locationServicesEnabled &&
      locationAlwaysEnabled &&
      backgroundUpdatesEnabled;

  bool get shouldBlockDriverApp =>
      isLoggedIn && isProfileCompleted && !driverPermissionsReady;

  bool get hasActiveLoads => activeLoads.isNotEmpty;

  List<LoadItem> get loads => List<LoadItem>.unmodifiable(_sortedLoads(_loads));

  List<LoadItem> get driverVisibleLoads {
    return _sortedLoads(
      _loads.where((l) => l.isVisibleToCurrentDriver).toList(),
    );
  }

  List<LoadItem> get assignedLoads =>
      driverVisibleLoads.where((l) => l.status == LoadStatus.assigned).toList();

  List<LoadItem> get activeLoads =>
      driverVisibleLoads.where((l) => l.isActive).toList();

  List<LoadItem> get finishedLoads =>
      driverVisibleLoads.where((l) => l.isFinal).toList();

  List<LoadItem> get shipperLoads => _sortedLoads(List<LoadItem>.from(_loads));

  List<LoadItem> get availableInviteLoads {
    return _sortedLoads(
      _loads
          .where(
            (l) =>
                l.assignmentMethod == AssignmentMethod.inviteLink &&
                l.status == LoadStatus.assigned &&
                !l.inviteConsumed &&
                !l.isVisibleToCurrentDriver &&
                !_isInviteExpired(l),
          )
          .toList(),
    );
  }

  List<AppNotice> get notices {
    final list = List<AppNotice>.from(_notices);
    list.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    return list;
  }

  List<AuditEvent> get events {
    final list = List<AuditEvent>.from(_events);
    list.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    return list;
  }

  int get pendingOfflinePointCount {
    int total = 0;
    for (final load in _loads) total += load.offlineBuffer.length;
    return total;
  }

  LoadItem? get selectedShipperLoad {
    if (shipperLoads.isEmpty) return null;
    if (selectedShipperLoadId != null) {
      for (final load in shipperLoads) {
        if (load.id == selectedShipperLoadId) return load;
      }
    }
    for (final load in shipperLoads) {
      if (load.isActive) return load;
    }
    return shipperLoads.first;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // Called by GPS layer with real device position
  void onGpsPosition(Position position) {
    _lastGpsPosition = position;
    if (!networkOnline || !driverPermissionsReady) return;
    // Send location for all active loads
    for (final load in _loads) {
      if (load.isActive) {
        _sendGpsPointToApi(load, position);
      }
    }
  }

  // -------------------------------------------------------------------------
  // AUTH
  // -------------------------------------------------------------------------
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
        loggedInEmail = email ?? '';
        loggedInPhone = phone ?? '';
        _log('auth.login', 'Вход выполнен: ${email ?? phone}');
        await _loadProfile();
        await fetchLoads();
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Ошибка входа';
    } catch (e) {
      return 'Ошибка сети: $e';
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
        loggedInEmail = email ?? '';
        loggedInPhone = phone ?? '';
        _log('auth.register', 'Регистрация: ${email ?? phone}');
        await _loadProfile();
        await fetchLoads();
        notifyListeners();
        return null;
      }
      return result['message'] as String? ?? 'Ошибка регистрации';
    } catch (e) {
      return 'Ошибка сети: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutToLogin() async {
    await _api.logout();
    isLoggedIn = false;
    loggedInEmail = '';
    loggedInPhone = '';
    profile = null;
    _loads.clear();
    _notices.clear();
    _events.clear();
    selectedShipperLoadId = null;
    _log('auth.logout', 'Сессия завершена');
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // PROFILE
  // -------------------------------------------------------------------------
  Future<void> _loadProfile() async {
    final me = await _api.getMe();
    if (me == null) return;
    final firstName = (me['first_name'] as String? ?? '').trim();
    final lastName = (me['last_name'] as String? ?? '').trim();
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    if (fullName.isEmpty) return; // profile not completed yet
    profile = DriverProfile(
      fullName: fullName,
      phone: me['phone'] as String? ?? loggedInPhone,
      email: me['email'] as String?,
      consentAccepted: true,
      userId: me['id'] as String?,
    );
    notifyListeners();
  }

  Future<String?> saveProfile({
    required String fullName,
    required String phone,
    required String email,
    required String vehicleNumber,
    required String vehicleType,
    required bool consentAccepted,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();
    final trimmedEmail = email.trim();
    final trimmedVehicleNumber = vehicleNumber.trim();
    final trimmedVehicleType = vehicleType.trim();

    if (trimmedName.isEmpty) return 'ФИО обязательно';
    if (!_isValidPhone(trimmedPhone)) return 'Некорректный телефон';
    if (trimmedEmail.isNotEmpty && !_isValidEmail(trimmedEmail)) {
      return 'Некорректный email';
    }
    if (!consentAccepted) {
      return 'Нужно подтвердить согласие на обработку данных и геотрекинг';
    }

    isLoading = true;
    notifyListeners();
    try {
      final parts = trimmedName.split(' ');
      final firstName = parts.isNotEmpty ? parts.first : trimmedName;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final success = await _api.updateMe(
        firstName: firstName,
        lastName: lastName,
      );
      if (!success) {
        return 'Не удалось сохранить профиль на сервере';
      }

      profile = DriverProfile(
        fullName: trimmedName,
        phone: trimmedPhone,
        email: trimmedEmail.isEmpty ? null : trimmedEmail,
        vehicleNumber: trimmedVehicleNumber.isEmpty
            ? null
            : trimmedVehicleNumber,
        vehicleType: trimmedVehicleType.isEmpty ? null : trimmedVehicleType,
        consentAccepted: consentAccepted,
      );
      loggedInPhone = trimmedPhone;
      _log(
        'driver.profile.saved',
        'Профиль обновлен: $trimmedName / $trimmedPhone',
      );
      await fetchLoads();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Ошибка сети: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // LOADS
  // -------------------------------------------------------------------------
  Future<void> fetchLoads() async {
    try {
      final rawLoads = await _api.getLoads();
      final parsed = rawLoads.map(LoadItem.fromApiJson).toList();
      _loads.clear();
      _loads.addAll(parsed);
      if (_loads.isNotEmpty && selectedShipperLoadId == null) {
        selectedShipperLoadId = _loads.first.id;
      }
      _log('loads.fetched', 'Загружено грузов: ${_loads.length}');
      notifyListeners();
    } catch (e) {
      _log('loads.fetch.error', 'Ошибка загрузки грузов: $e');
    }
  }

  Future<void> acceptLoad(String loadId) async {
    final load = _findLoad(loadId);
    if (load == null || load.status != LoadStatus.assigned) return;

    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.acceptLoad(loadId);
      if (success) {
        load.status = LoadStatus.accepted;
        load.acceptedAtUtc = nowUtc;
        load.moving = true;
        load.nextTrackingDueUtc = nowUtc;
        if (load.assignmentMethod == AssignmentMethod.inviteLink) {
          load.inviteConsumed = true;
        }
        _log('load.accepted', 'Водитель принял груз ${load.id}');
        _notify(
          audience: NoticeAudience.shipper,
          title: 'Груз принят',
          message: 'Водитель принял груз #${load.id}. Трекинг запускается.',
        );
        if (!driverPermissionsReady) {
          _notifyPermissionProblemToDriver();
          _handlePermissionIncidentState();
        } else if (_lastGpsPosition != null) {
          _sendGpsPointToApi(load, _lastGpsPosition!);
        }
      } else {
        _log('load.accept.error', 'Сервер отклонил принятие груза $loadId');
      }
    } catch (e) {
      _log('load.accept.error', 'Ошибка: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void rejectLoad(String loadId, RejectReason reason, {String? otherText}) {
    final load = _findLoad(loadId);
    if (load == null || load.status != LoadStatus.assigned) return;
    // No reject endpoint in API — local only
    load.status = LoadStatus.rejected;
    load.rejectedAtUtc = nowUtc;
    load.rejectReasonLabel = _rejectReasonLabel(reason, otherText: otherText);
    _log(
      'load.rejected',
      'Груз ${load.id} отклонен: ${load.rejectReasonLabel}',
    );
    _notify(
      audience: NoticeAudience.shipper,
      title: 'Груз отклонен',
      message: 'Водитель отклонил груз #${load.id}: ${load.rejectReasonLabel}',
    );
    notifyListeners();
  }

  Future<void> completeLoad(String loadId) async {
    final load = _findLoad(loadId);
    if (load == null || !load.isActive) return;

    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.completeLoad(loadId);
      if (success) {
        load.status = LoadStatus.completed;
        load.completedAtUtc = nowUtc;
        load.nextTrackingDueUtc = null;
        _log('load.completed', 'Груз ${load.id} завершен. Трекинг остановлен.');
        _notify(
          audience: NoticeAudience.shipper,
          title: 'Груз завершен',
          message:
              'Груз #${load.id} переведен в Completed. Трекинг остановлен.',
        );
      }
    } catch (e) {
      _log('load.complete.error', 'Ошибка: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void cancelLoad(String loadId) {
    // No cancel endpoint in API — local only
    final load = _findLoad(loadId);
    if (load == null || !load.isActive) return;
    load.status = LoadStatus.cancelled;
    load.cancelledAtUtc = nowUtc;
    load.nextTrackingDueUtc = null;
    _log('load.cancelled', 'Груз ${load.id} отменен.');
    _notify(
      audience: NoticeAudience.shipper,
      title: 'Груз отменен',
      message: 'Груз #${load.id} переведен в Cancelled.',
    );
    notifyListeners();
  }

  Future<void> markLoadInTransit(String loadId) async {
    final load = _findLoad(loadId);
    if (load == null || load.status != LoadStatus.accepted) return;

    isLoading = true;
    notifyListeners();
    try {
      final success = await _api.startLoad(loadId);
      if (success) {
        load.status = LoadStatus.inTransit;
        _log('load.status.change', 'Груз ${load.id}: статус In Transit');
      }
    } catch (e) {
      _log('load.start.error', 'Ошибка: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String? claimInvite(String loadId) {
    final load = _findLoad(loadId);
    if (load == null) return 'Приглашение не найдено';
    if (load.assignmentMethod != AssignmentMethod.inviteLink)
      return 'Это не приглашение по ссылке';
    if (_isInviteExpired(load)) return 'Срок действия ссылки истек';
    if (load.inviteConsumed || load.status != LoadStatus.assigned)
      return 'Ссылка уже недействительна';
    load.isVisibleToCurrentDriver = true;
    load.inviteOpenedByDriver = true;
    load.pendingDriverRegistration = false;
    _log(
      'load.invite.opened',
      'Водитель открыл приглашение для груза ${load.id}',
    );
    notifyListeners();
    return null;
  }

  // Local-only load creation (no POST /loads endpoint in API)
  String? createLoad({
    required String pickupAddress,
    required String dropoffAddress,
    required String description,
    DateTime? plannedAtUtc,
    required AssignmentMethod assignmentMethod,
    required String shipperContact,
    String? driverPhone,
    String? driverEmail,
  }) {
    final pickup = pickupAddress.trim();
    final dropoff = dropoffAddress.trim();
    final note = description.trim();
    final shipper = shipperContact.trim();
    final phone = (driverPhone ?? '').trim();
    final email = (driverEmail ?? '').trim();

    if (pickup.isEmpty || dropoff.isEmpty)
      return 'Укажите точки погрузки и разгрузки';
    if (shipper.isEmpty) return 'Укажите контакт грузовладельца';

    if (assignmentMethod == AssignmentMethod.contact) {
      if (phone.isEmpty && email.isEmpty)
        return 'Для назначения по телефону/email заполните хотя бы одно поле';
      if (phone.isNotEmpty && !_isValidPhone(phone))
        return 'Некорректный телефон водителя';
      if (email.isNotEmpty && !_isValidEmail(email))
        return 'Некорректный email водителя';
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final load = LoadItem(
      id: id,
      pickupAddress: pickup,
      dropoffAddress: dropoff,
      description: note.isEmpty ? 'Без комментария' : note,
      shipperContact: shipper,
      createdAtUtc: nowUtc,
      plannedAtUtc: plannedAtUtc,
      assignmentMethod: assignmentMethod,
      assignedPhone: phone.isEmpty ? null : phone,
      assignedEmail: email.isEmpty ? null : email,
      inviteToken: assignmentMethod == AssignmentMethod.inviteLink
          ? _generateToken(28)
          : null,
      inviteExpiresAtUtc: assignmentMethod == AssignmentMethod.inviteLink
          ? nowUtc.add(const Duration(hours: 72))
          : null,
      pickupLat: 41.2995,
      pickupLon: 69.2401,
      dropoffLat: 39.6542,
      dropoffLon: 66.9597,
    );

    if (assignmentMethod == AssignmentMethod.contact) {
      load.pendingDriverRegistration = true;
    }

    _loads.add(load);
    selectedShipperLoadId = load.id;
    _log('load.created', 'Создан груз ${load.id} ($pickup -> $dropoff)');
    notifyListeners();
    return null;
  }

  void selectShipperLoad(String? id) {
    selectedShipperLoadId = id;
    notifyListeners();
  }

  void toggleLoadMovement(String loadId) {
    final load = _findLoad(loadId);
    if (load == null || !load.isActive) return;
    load.moving = !load.moving;
    _log(
      'tracking.motion',
      'Груз ${load.id}: режим ${load.moving ? 'движение' : 'стоянка'}',
    );
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // PERMISSIONS
  // -------------------------------------------------------------------------
  void recheckPermissions() {
    locationServicesEnabled = true;
    locationAlwaysEnabled = true;
    backgroundUpdatesEnabled = true;
    _handlePermissionIncidentState();
    notifyListeners();
  }

  void setLocationServicesEnabled(bool value) {
    if (locationServicesEnabled == value) return;
    locationServicesEnabled = value;
    _log(
      'permissions.location_services',
      'Location Services ${value ? 'ON' : 'OFF'}',
    );
    _handlePermissionIncidentState();
    notifyListeners();
  }

  void setLocationAlwaysEnabled(bool value) {
    if (locationAlwaysEnabled == value) return;
    locationAlwaysEnabled = value;
    _log(
      'permissions.location_always',
      'Location Always ${value ? 'ON' : 'OFF'}',
    );
    _handlePermissionIncidentState();
    notifyListeners();
  }

  void setBackgroundUpdatesEnabled(bool value) {
    if (backgroundUpdatesEnabled == value) return;
    backgroundUpdatesEnabled = value;
    _log(
      'permissions.background_updates',
      'Background updates ${value ? 'ON' : 'OFF'}',
    );
    _handlePermissionIncidentState();
    notifyListeners();
  }

  void setNetworkOnline(bool value) {
    if (networkOnline == value) return;
    networkOnline = value;
    _log('network.state', 'Сеть ${value ? 'доступна' : 'недоступна'}');
    if (!value) {
      _notify(
        audience: NoticeAudience.driver,
        title: 'Нет интернета',
        message:
            'Точки трекинга будут буферизоваться локально и отправятся позже.',
      );
    } else {
      _flushAllOfflineBuffers();
    }
    notifyListeners();
  }

  String getDriverInviteLink(LoadItem load) {
    final String token = load.inviteToken ?? '';
    return 'https://driver-tracking.example/invite/$token';
  }

  // -------------------------------------------------------------------------
  // TRACKING — real GPS → API
  // -------------------------------------------------------------------------
  Future<void> _sendGpsPointToApi(LoadItem load, Position pos) async {
    final speedKmh = pos.speed * 3.6;
    final point = TrackingPoint(
      timestampUtc: DateTime.now().toUtc(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedKmh: speedKmh,
      accuracyM: pos.accuracy,
      deviceId: deviceId,
      driverId: profile?.userId ?? deviceId,
      loadId: load.id,
    );
    load.lastLocalPoint = point;

    if (networkOnline) {
      if (load.offlineBuffer.isNotEmpty) {
        await _flushLoadBuffer(load);
      }
      await _deliverTrackingPoint(load, point);
    } else {
      load.offlineBuffer.add(point);
      _log(
        'tracking.buffered',
        'Нет сети: точка для груза ${load.id} сохранена локально (buffer=${load.offlineBuffer.length})',
      );
    }
    notifyListeners();
  }

   Future<void> _deliverTrackingPoint(LoadItem load, TrackingPoint point) async {
    try {
      final ok = await _api.registerLocation(
        loadId: load.id,
        carrierId: profile?.userId ?? deviceId,
        lat: point.latitude,
        lng: point.longitude,
        speedMps: point.speedKmh / 3.6,
        accuracyM: point.accuracyM,
        recordedAt: point.timestampUtc,
      );
      if (ok) {
        load.lastDeliveredPoint = point;
        load.silenceAlertSent = false;
        load.silenceAlertAtUtc = null;
        if (load.status == LoadStatus.accepted && point.speedKmh > 1) {
          // Auto-transition to in_transit
          await _api.startLoad(load.id);
          load.status = LoadStatus.inTransit;
          _log(
            'load.status.change',
            'Груз ${load.id}: статус In Transit (авто)',
          );
        }
        _log(
          'tracking.point.sent',
          'POST /loads/${load.id}/location: speed=${point.speedKmh.toStringAsFixed(1)} км/ч, accuracy=${point.accuracyM.toStringAsFixed(0)}м',
        );
      }
    } catch (e) {
      load.offlineBuffer.add(point);
      _log('tracking.point.error', 'Ошибка отправки точки: $e');
    }
  }

  void _flushAllOfflineBuffers() {
    for (final load in _loads) {
      if (load.offlineBuffer.isNotEmpty) {
        _flushLoadBuffer(load);
      }
    }
  }

  Future<void> _flushLoadBuffer(LoadItem load) async {
    if (load.offlineBuffer.isEmpty) return;
    final batchSize = load.offlineBuffer.length;
    final points = List<TrackingPoint>.from(load.offlineBuffer);
    points.sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
    load.offlineBuffer.clear();
    for (final point in points) {
      await _deliverTrackingPoint(load, point);
    }
    _log(
      'tracking.batch.sent',
      'Batch=$batchSize точек для груза ${load.id} отправлено',
    );
  }

  void _checkSilenceAlerts() {
    for (final load in _loads) {
      if (!load.isActive) {
        load.silenceAlertSent = false;
        load.silenceAlertAtUtc = null;
        continue;
      }

      DateTime? lastSeenUtc;
      if (load.lastDeliveredPoint != null) {
        lastSeenUtc = load.lastDeliveredPoint!.timestampUtc;
      } else if (load.acceptedAtUtc != null) {
        lastSeenUtc = load.acceptedAtUtc;
      }

      if (lastSeenUtc == null) continue;

      final silence = nowUtc.difference(lastSeenUtc);
      if (silence >= const Duration(minutes: 10) && !load.silenceAlertSent) {
        load.silenceAlertSent = true;
        load.silenceAlertAtUtc = nowUtc;
        _notify(
          audience: NoticeAudience.shipper,
          title: 'Трекинг молчит 10 минут',
          message: 'Нет обновлений трекинга 10 минут по грузу #${load.id}',
        );
        _log(
          'tracking.silence',
          'Событие тишины: груз ${load.id}, нет новых точек более 10 минут',
        );
      }
    }
  }

  void _handlePermissionIncidentState() {
    if (hasActiveLoads && !driverPermissionsReady) {
      if (!_permissionIncidentOpen) {
        _permissionIncidentOpen = true;
        _log('permissions.lost', 'Трекинг невозможен: отключены разрешения');
        _notifyPermissionProblemToDriver();
      }
      return;
    }

    if (_permissionIncidentOpen && driverPermissionsReady) {
      _permissionIncidentOpen = false;
      _log(
        'permissions.restored',
        'Разрешения восстановлены. Трекинг может продолжиться.',
      );
      _notify(
        audience: NoticeAudience.driver,
        title: 'Разрешения восстановлены',
        message: 'Геолокация и фоновые обновления включены. Трекинг продолжен.',
      );
    }
  }

  void _notifyPermissionProblemToDriver() {
    _notify(
      audience: NoticeAudience.driver,
      title: 'Трекинг невозможен',
      message:
          'Включите геолокацию "Всегда" и фоновые обновления, иначе трекинг невозможен.',
    );
  }

  void _notify({
    required NoticeAudience audience,
    required String title,
    required String message,
  }) {
    _notices.add(
      AppNotice(
        timestampUtc: nowUtc,
        audience: audience,
        title: title,
        message: message,
      ),
    );
  }

  void _log(String type, String message) {
    _events.add(AuditEvent(timestampUtc: nowUtc, type: type, message: message));
  }

  LoadItem? _findLoad(String id) {
    for (final load in _loads) {
      if (load.id == id) return load;
    }
    return null;
  }

  bool _isInviteExpired(LoadItem load) {
    if (load.inviteExpiresAtUtc == null) return false;
    return nowUtc.isAfter(load.inviteExpiresAtUtc!);
  }

  List<LoadItem> _sortedLoads(List<LoadItem> source) {
    source.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.createdAtUtc.compareTo(a.createdAtUtc);
    });
    return source;
  }

  String _generateToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
  }
}

// ---------------------------------------------------------------------------
// LOGIN SCREEN — email/password (replaces OTP)
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, required this.store}) : super(key: key);

  final AppStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _role = 'carrier';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Введите email и пароль');
      return;
    }

    String? error;
    if (_isRegisterMode) {
      error = await widget.store.register(
        email: email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        password: password,
        role: _role,
      );
    } else {
      error = await widget.store.login(email: email, password: password);
    }

    if (error != null && mounted) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final loading = widget.store.isLoading;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: const <Widget>[
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Color(0xFFDDE7FF),
                                    child: Icon(
                                      Icons.local_shipping_rounded,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Yool Driver Tracking',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRegisterMode ? 'Регистрация' : 'Вход',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 18),
                              if (_isRegisterMode) ...<Widget>[
                                TextField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Имя',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Фамилия',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),                    
                              ],
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Пароль',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: loading ? null : _submit,
                                icon: loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _isRegisterMode
                                            ? Icons.person_add
                                            : Icons.login,
                                      ),
                                label: Text(
                                  _isRegisterMode
                                      ? 'Зарегистрироваться'
                                      : 'Войти',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(
                                  () => _isRegisterMode = !_isRegisterMode,
                                ),
                                child: Text(
                                  _isRegisterMode
                                      ? 'Уже есть аккаунт? Войти'
                                      : 'Нет аккаунта? Зарегистрироваться',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Для работы приложения необходимы разрешения на использование геолокации и фоновых обновлений.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE SETUP SCREEN
// ---------------------------------------------------------------------------
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key, required this.store}) : super(key: key);

  final AppStore store;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  bool _consentAccepted = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.store.loggedInPhone);
    _emailController.text = widget.store.loggedInEmail;
    _vehicleNumberController.text = '';
    _vehicleTypeController.text = '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleNumberController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final loading = widget.store.isLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Профиль водителя')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Заполните профиль',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Обязательные поля: ФИО и телефон.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'ФИО *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Телефон *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (опционально)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vehicleNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Номер авто/фуры',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vehicleTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Тип авто',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _consentAccepted,
                            onChanged: (v) =>
                                setState(() => _consentAccepted = v ?? false),
                            title: const Text(
                              'Согласен на обработку персональных данных и трекинг геолокации',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: loading
                                ? null
                                : () async {
                                    final error = await widget.store
                                        .saveProfile(
                                          fullName: _fullNameController.text,
                                          phone: _phoneController.text,
                                          email: _emailController.text,
                                          vehicleNumber:
                                              _vehicleNumberController.text,
                                          vehicleType:
                                              _vehicleTypeController.text,
                                          consentAccepted: _consentAccepted,
                                        );
                                    if (error != null && mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                    }
                                  },
                            icon: loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Сохранить профиль'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN SHELL
// ---------------------------------------------------------------------------
class MainShell extends StatefulWidget {
  const MainShell({Key? key, required this.store}) : super(key: key);

  final AppStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  void _setTab(int index) => setState(() => _tabIndex = index);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final store = widget.store;
        final List<Widget> screens = <Widget>[
          store.shouldBlockDriverApp
              ? BlockingScreen(store: store, onOpenSettings: () => _setTab(3))
              : DriverHomeScreen(store: store),
          
          
          SettingsSupportScreen(store: store),
        ];

        return Scaffold(
          appBar: AppBar(title: const Text('Yool Driver Tracking')),
          body: IndexedStack(index: _tabIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tabIndex,
            type: BottomNavigationBarType.fixed,
            onTap: _setTab,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.drive_eta_outlined),
                activeIcon: Icon(Icons.drive_eta),
                label: 'Водитель',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person_outlined),
                label: 'Профиль',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// DRIVER HOME SCREEN
// ---------------------------------------------------------------------------
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({Key? key, required this.store}) : super(key: key);

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final profile = store.profile;
        return DefaultTabController(
          length: 3,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    profile?.fullName ?? 'Водитель',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(profile?.phone ?? ''),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      StatusPill(
                                        label: store.driverPermissionsReady
                                            ? 'Location Always: OK'
                                            : 'Location Always: BLOCK',
                                        color: store.driverPermissionsReady
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      StatusPill(
                                        label: store.networkOnline
                                            ? 'Сеть: ON'
                                            : 'Сеть: OFF',
                                        color: store.networkOnline
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                      StatusPill(
                                        label:
                                            'Buffer: ${store.pendingOfflinePointCount}',
                                        color:
                                            store.pendingOfflinePointCount == 0
                                            ? Colors.teal
                                            : Colors.orange,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (store.availableInviteLoads.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Приглашения по ссылке',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Откройте ссылку-приглашение, чтобы груз появился в разделе "Назначенные".',
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                children: store.availableInviteLoads
                                    .map(
                                      (load) => Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFF),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              'Груз #${load.id}: ${load.pickupAddress} -> ${load.dropoffAddress}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Ссылка действует до ${formatDateTime(load.inviteExpiresAtUtc)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(
                                                    store.getDriverInviteLink(
                                                      load,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF1D4ED8),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: () {
                                                    final error = store
                                                        .claimInvite(load.id);
                                                    if (error != null) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(error),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: const Text('Открыть'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const TabBar(
                      tabs: <Widget>[
                        Tab(text: 'Назначенные'),
                        Tab(text: 'Активные'),
                        Tab(text: 'Завершённые'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    DriverLoadsListTab(
                      title: 'Назначенные',
                      subtitle: 'Грузы, ожидающие принятия',
                      loads: store.assignedLoads,
                      store: store,
                    ),
                    DriverLoadsListTab(
                      title: 'Активные',
                      subtitle: 'В работе, трекинг активен',
                      loads: store.activeLoads,
                      store: store,
                    ),
                    DriverLoadsListTab(
                      title: 'Завершённые',
                      subtitle: 'История статусов',
                      loads: store.finishedLoads,
                      store: store,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DriverLoadsListTab extends StatelessWidget {
  const DriverLoadsListTab({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.loads,
    required this.store,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final List<LoadItem> loads;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  const Text('Список пуст.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: store.fetchLoads,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loads.length,
      itemBuilder: (context, index) {
        final load = loads[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (load.isActive) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ActiveLoadScreen(store: store, loadId: load.id),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LoadDetailsScreen(store: store, loadId: load.id),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Груз #${load.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      LoadStatusChip(status: load.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const <Widget>[
                      Icon(Icons.trip_origin, size: 16, color: Colors.green),
                      SizedBox(width: 6),
                      Text('Погрузка', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(load.pickupAddress),
                  const SizedBox(height: 8),
                  Row(
                    children: const <Widget>[
                      Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text(
                        'Разгрузка',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(load.dropoffAddress),
                  if (load.plannedAtUtc != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Дата/время: ${formatDateTime(load.plannedAtUtc)} UTC',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    load.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  if (load.isActive &&
                      load.lastDeliveredPoint != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.my_location, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Скорость ${load.lastDeliveredPoint!.speedKmh.toStringAsFixed(0)} км/ч • обновлено ${formatRelativeTime(store.nowUtc, load.lastDeliveredPoint!.timestampUtc)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// LOAD DETAILS SCREEN
// ---------------------------------------------------------------------------
class LoadDetailsScreen extends StatelessWidget {
  const LoadDetailsScreen({Key? key, required this.store, required this.loadId})
    : super(key: key);

  final AppStore store;
  final String loadId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final load = _findById(store.loads, loadId);
        if (load == null) {
          return const Scaffold(body: Center(child: Text('Груз не найден')));
        }

        final canAccept =
            load.status == LoadStatus.assigned && store.driverPermissionsReady;

        return Scaffold(
          appBar: AppBar(title: Text('Карточка груза #${load.id}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Груз #${load.id}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          LoadStatusChip(status: load.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InfoRow(label: 'Погрузка', value: load.pickupAddress),
                      InfoRow(label: 'Разгрузка', value: load.dropoffAddress),
                      InfoRow(label: 'Комментарий', value: load.description),
                      InfoRow(
                        label: 'Контакты грузовладельца',
                        value: load.shipperContact,
                      ),
                      InfoRow(
                        label: 'Назначение',
                        value:
                            load.assignmentMethod == AssignmentMethod.inviteLink
                            ? 'По ссылке-приглашению'
                            : 'По телефону/email',
                      ),
                      if (load.plannedAtUtc != null)
                        InfoRow(
                          label: 'Дата/время',
                          value: '${formatDateTime(load.plannedAtUtc)} UTC',
                        ),
                      if (load.rejectReasonLabel != null)
                        InfoRow(
                          label: 'Причина отклонения',
                          value: load.rejectReasonLabel!,
                        ),
                    ],
                  ),
                ),
              ),
              if (load.status == LoadStatus.assigned) ...<Widget>[
                if (!store.driverPermissionsReady)
                  const Card(
                    color: Color(0xFFFFF4E5),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Для принятия и трекинга требуется геолокация "Всегда" и фоновые обновления. Включите их в Настройках.',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (store.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canAccept
                              ? () async {
                                  await store.acceptLoad(load.id);
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ActiveLoadScreen(
                                        store: store,
                                        loadId: load.id,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Принять'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<RejectDecision>(
                              context: context,
                              builder: (_) => const RejectReasonDialog(),
                            );
                            if (result != null) {
                              store.rejectLoad(
                                load.id,
                                result.reason,
                                otherText: result.otherText,
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Отклонить'),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ACTIVE LOAD SCREEN
// ---------------------------------------------------------------------------
class ActiveLoadScreen extends StatelessWidget {
  const ActiveLoadScreen({Key? key, required this.store, required this.loadId})
    : super(key: key);

  final AppStore store;
  final String loadId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final load = _findById(store.loads, loadId);
        if (load == null) {
          return const Scaffold(body: Center(child: Text('Груз не найден')));
        }

        return Scaffold(
          appBar: AppBar(title: Text('Активный груз #${load.id}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Статус и трекинг',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          LoadStatusChip(status: load.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          StatusPill(
                            label: store.driverPermissionsReady
                                ? 'Location Always: OK'
                                : 'Location Always: BLOCK',
                            color: store.driverPermissionsReady
                                ? Colors.green
                                : Colors.red,
                          ),
                          StatusPill(
                            label: store.networkOnline ? 'Сеть ON' : 'Сеть OFF',
                            color: store.networkOnline
                                ? Colors.blue
                                : Colors.orange,
                          ),
                          StatusPill(
                            label: 'Buffer: ${load.offlineBuffer.length} точек',
                            color: load.offlineBuffer.isEmpty
                                ? Colors.teal
                                : Colors.orange,
                          ),
                        ],
                      ),
                      if (!store.driverPermissionsReady)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Трекинг невозможен: включите геолокацию "Всегда" в настройках.',
                            style: TextStyle(color: Color(0xFFB71C1C)),
                          ),
                        ),
                      const SizedBox(height: 14),
                      InfoRow(label: 'Погрузка', value: load.pickupAddress),
                      InfoRow(label: 'Разгрузка', value: load.dropoffAddress),
                      InfoRow(label: 'Комментарий', value: load.description),
                      InfoRow(
                        label: 'Локально последняя точка',
                        value: load.lastLocalPoint == null
                            ? 'Еще нет'
                            : '${formatDateTime(load.lastLocalPoint!.timestampUtc)} UTC',
                      ),
                      InfoRow(
                        label: 'В системе (shipper) последняя точка',
                        value: load.lastDeliveredPoint == null
                            ? 'Еще нет'
                            : '${formatDateTime(load.lastDeliveredPoint!.timestampUtc)} UTC (${formatRelativeTime(store.nowUtc, load.lastDeliveredPoint!.timestampUtc)})',
                      ),
                      InfoRow(
                        label: 'Скорость',
                        value: load.lastDeliveredPoint == null
                            ? '-'
                            : '${load.lastDeliveredPoint!.speedKmh.toStringAsFixed(1)} км/ч',
                      ),
                      InfoRow(
                        label: 'Accuracy',
                        value: load.lastDeliveredPoint == null
                            ? '-'
                            : '${load.lastDeliveredPoint!.accuracyM.toStringAsFixed(0)} м',
                      ),
                      InfoRow(
                        label: 'Offline buffer',
                        value: '${load.offlineBuffer.length} точек',
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Управление грузом',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => store.toggleLoadMovement(load.id),
                            icon: Icon(
                              load.moving
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                            ),
                            label: Text(load.moving ? 'Стоянка' : 'Движение'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => store.markLoadInTransit(load.id),
                            icon: const Icon(Icons.route_outlined),
                            label: const Text('In Transit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (store.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await store.completeLoad(load.id);
                                  if (context.mounted)
                                    Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.task_alt),
                                label: const Text('Completed'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  store.cancelLoad(load.id);
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelled'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// ---------------------------------------------------------------------------
// SETTINGS / SUPPORT SCREEN
// ---------------------------------------------------------------------------
class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({Key? key, required this.store})
    : super(key: key);

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Служба Поддержки',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('info.support@yool.live'),
                    SizedBox(height: 4),
                    Text('+998 12 345 67 89'),
                    SizedBox(height: 8),                 
                  ],
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Выйти'),
                subtitle: const Text('Выход из аккаунта'),
                onTap: store.logoutToLogin,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// BLOCKING SCREEN
// ---------------------------------------------------------------------------
class BlockingScreen extends StatelessWidget {
  const BlockingScreen({
    Key? key,
    required this.store,
    required this.onOpenSettings,
  }) : super(key: key);

  final AppStore store;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            color: const Color(0xFFFFFBF0),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(
                    Icons.location_off_rounded,
                    size: 56,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Для работы приложения требуется доступ к геолокации: "Всегда"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Пока геолокация выключена или разрешение не равно "Always", доступ к основному функционалу водителя заблокирован.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Что проверить',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        _stateLine(
                          'Location Services',
                          store.locationServicesEnabled,
                        ),
                        _stateLine(
                          'Permission = Always',
                          store.locationAlwaysEnabled,
                        ),
                        _stateLine(
                          'Background updates',
                          store.backgroundUpdatesEnabled,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Инструкция: Настройки -> Location -> Always',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Открыть настройки'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: store.recheckPermissions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Я включил - проверить снова'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Исключение по ТЗ: поддержка доступна через вкладку "Настройки".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateLine(String title, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text('$title: ${ok ? 'OK' : 'OFF'}'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REJECT REASON DIALOG
// ---------------------------------------------------------------------------
class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({Key? key}) : super(key: key);

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  RejectReason _selected = RejectReason.busy;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Причина отклонения'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final reason in RejectReason.values)
              RadioListTile<RejectReason>(
                value: reason,
                groupValue: _selected,
                onChanged: (v) {
                  if (v != null) setState(() => _selected = v);
                },
                title: Text(_rejectReasonLabel(reason)),
                contentPadding: EdgeInsets.zero,
              ),
            if (_selected == RejectReason.other)
              TextField(
                controller: _otherController,
                decoration: const InputDecoration(
                  labelText: 'Своя причина',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(RejectDecision(_selected, _otherController.text.trim())),
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}

class RejectDecision {
  RejectDecision(this.reason, this.otherText);

  final RejectReason reason;
  final String otherText;
}

// ---------------------------------------------------------------------------
// REUSABLE WIDGETS
// ---------------------------------------------------------------------------
class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({Key? key, required this.status}) : super(key: key);

  final LoadStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case LoadStatus.assigned:
        bg = const Color(0xFFE8EAF6);
        fg = const Color(0xFF303F9F);
        break;
      case LoadStatus.accepted:
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case LoadStatus.inTransit:
        bg = const Color(0xFFE0F2F1);
        fg = const Color(0xFF00695C);
        break;
      case LoadStatus.completed:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case LoadStatus.cancelled:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        break;
      case LoadStatus.rejected:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFEF6C00);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({Key? key, required this.label, required this.color})
    : super(key: key);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({Key? key, required this.label, required this.value})
    : super(key: key);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------
String statusLabel(LoadStatus status) {
  switch (status) {
    case LoadStatus.assigned:
      return 'Assigned';
    case LoadStatus.accepted:
      return 'Accepted';
    case LoadStatus.inTransit:
      return 'In Transit';
    case LoadStatus.completed:
      return 'Completed';
    case LoadStatus.cancelled:
      return 'Cancelled';
    case LoadStatus.rejected:
      return 'Rejected';
  }
}

String _rejectReasonLabel(RejectReason reason, {String? otherText}) {
  switch (reason) {
    case RejectReason.busy:
      return 'Занято';
    case RejectReason.routeMismatch:
      return 'Не подходит маршрут';
    case RejectReason.badPrice:
      return 'Не устраивает цена';
    case RejectReason.other:
      final t = (otherText ?? '').trim();
      return t.isEmpty ? 'Другое' : 'Другое: $t';
  }
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final utc = dt.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}

String formatRelativeTime(DateTime nowUtc, DateTime thenUtc) {
  final d = nowUtc.difference(thenUtc);
  if (d.inSeconds < 60) return '${d.inSeconds}с назад';
  if (d.inMinutes < 60) return '${d.inMinutes}м назад';
  if (d.inHours < 24) return '${d.inHours}ч назад';
  return '${d.inDays}д назад';
}

LoadItem? _findById(List<LoadItem> loads, String id) {
  for (final load in loads) {
    if (load.id == id) return load;
  }
  return null;
}

bool _isValidPhone(String value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value.trim());

bool _isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
