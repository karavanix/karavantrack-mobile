import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// API Configuration
// ---------------------------------------------------------------------------
const String _kBaseUrl = 'https://api.yool.live';
const String _kBasePath = '/api/v1';

String _url(String path) => '$_kBaseUrl$_kBasePath$path';

// ---------------------------------------------------------------------------
// API Service — singleton HTTP client for the Carriers API
// ---------------------------------------------------------------------------
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _tokenKey = 'auth_token';
  static const String _refreshKey = 'refresh_token';

  String? _accessToken;
  String? _refreshToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshKey);
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
  }

  bool get hasToken => _accessToken != null;

  String? get accessToken => _accessToken;

  // ─── Token refresh ──────────────────────────────────────────────────────

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
        final access = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (access != null && refresh != null) {
          await setTokens(access: access, refresh: refresh);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ─── Authenticated request wrapper (auto-refresh on 401) ────────────────

  Future<http.Response> _authed(Future<http.Response> Function() fn) async {
    final resp = await fn();
    if (resp.statusCode == 401 && _refreshToken != null) {
      final refreshed = await refreshTokens();
      if (refreshed) return fn();
    }
    return resp;
  }

  // ─── Auth ───────────────────────────────────────────────────────────────

  /// POST /auth/login
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
      await setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return {'success': true, 'data': data};
    }
    return {'success': false, 'message': _parseError(response)};
  }

  /// POST /auth/register
  Future<Map<String, dynamic>> register({
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    required String password,
    required String role,
  }) async {
    final body = <String, dynamic>{'password': password, 'role': role};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (firstName != null && firstName.isNotEmpty) {
      body['first_name'] = firstName;
    }
    if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;

    final response = await http.post(
      Uri.parse(_url('/auth/register')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['access_token'] != null) {
        await setTokens(
          access: data['access_token'] as String,
          refresh: data['refresh_token'] as String,
        );
      }
      return {'success': true, 'data': data};
    }
    return {'success': false, 'message': _parseError(response)};
  }

  /// POST /auth/logout
  Future<void> logout() async {
    try {
      await _authed(
        () => http.post(Uri.parse(_url('/auth/logout')), headers: _authHeaders),
      );
    } catch (_) {}
    await clearTokens();
  }

  // ─── Users ──────────────────────────────────────────────────────────────

  /// GET /users/me
  Future<Map<String, dynamic>?> getMe() async {
    final response = await _authed(
      () => http.get(Uri.parse(_url('/users/me')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// PUT /users/me
  Future<bool> updateMe({String? firstName, String? lastName}) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;

    final response = await _authed(
      () => http.put(
        Uri.parse(_url('/users/me')),
        headers: _authHeaders,
        body: jsonEncode(body),
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /users/me/devices
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
        'device_name': ?deviceName,
        'device_type': ?deviceType,
      };
      await _authed(
        () => http.post(
          Uri.parse(_url('/users/me/devices')),
          headers: _authHeaders,
          body: jsonEncode(body),
        ),
      );
    } catch (_) {}
  }

  // ─── Loads ──────────────────────────────────────────────────────────────

  /// GET /loads/pending — paginated list of assigned loads.
  Future<Map<String, dynamic>> getPendingLoads({
    int? limit,
    int? offset,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (offset != null) params['offset'] = offset.toString();

    final uri = Uri.parse(
      _url('/loads/pending'),
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await _authed(() => http.get(uri, headers: _authHeaders));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'result': [], 'count': 0};
  }

  /// GET /loads/active — the current active load (accepted/in_transit).
  Future<Map<String, dynamic>?> getActiveLoad() async {
    final response = await _authed(
      () => http.get(Uri.parse(_url('/loads/active')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// GET /loads/{id}
  Future<Map<String, dynamic>?> getLoad(String id) async {
    final response = await _authed(
      () => http.get(Uri.parse(_url('/loads/$id')), headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// POST /loads/{id}/accept
  Future<bool> acceptLoad(String id) async {
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$id/accept')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/start
  Future<bool> startLoad(String id) async {
    final response = await _authed(
      () =>
          http.post(Uri.parse(_url('/loads/$id/start')), headers: _authHeaders),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/pickup/begin  (accepted → picking_up)
  Future<bool> beginPickup(String id) async {
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$id/pickup/begin')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/pickup/confirm  (picking_up → picked_up)
  Future<bool> confirmPickup(String id) async {
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$id/pickup/confirm')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/dropoff/begin  (in_transit → dropping_off)
  Future<bool> beginDropoff(String id) async {
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$id/dropoff/begin')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/dropoff/confirm  (dropping_off → dropped_off)
  Future<bool> confirmDropoff(String id) async {
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$id/dropoff/confirm')),
        headers: _authHeaders,
      ),
    );
    return response.statusCode == 200;
  }

  /// POST /loads/{id}/location
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
      'heading_deg': ?headingDeg,
    };
    final response = await _authed(
      () => http.post(
        Uri.parse(_url('/loads/$loadId/location')),
        headers: _authHeaders,
        body: jsonEncode(body),
      ),
    );
    return response.statusCode == 200;
  }

  // ─── Companies ──────────────────────────────────────────────────────────

  /// GET /carriers/companies/{id}
  Future<Map<String, dynamic>?> getCompany(String id) async {
    final response = await _authed(
      () => http.get(
        Uri.parse(_url('/carriers/companies/$id')),
        headers: _authHeaders,
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['message'] as String?) ?? 'Error ${response.statusCode}';
    } catch (_) {
      return 'Error ${response.statusCode}';
    }
  }
}
