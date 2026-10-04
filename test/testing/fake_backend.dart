import 'package:dio/dio.dart';
import 'package:driver_tracking_app/data/services/tracking/tracking_service.dart';

import 'fake_server.dart';

typedef FakeInvite = ({String status, String loadId, bool acceptedByMe});

/// A load on the fake server. Statuses are the API's spelling.
class FakeLoad {
  FakeLoad(this.id, {this.status = 'assigned', String? title})
    : title = title ?? 'Load $id';

  final String id;
  String title;
  String status;
  final history = <({String from, String to})>[];

  /// Attachment ids sent with each status change, by the status it led to.
  final attachments = <String, List<String>>{};

  bool get isActive => FakeBackend._activeStatuses.contains(status);

  Map<String, Object?> toJson({bool withHistory = false}) => {
    'id': id,
    'title': title,
    'status': status,
    'pickup_address': 'Tashkent',
    'dropoff_address': 'Samarkand',
    'pickup_lat': 41.31,
    'pickup_lng': 69.28,
    'dropoff_lat': 39.65,
    'dropoff_lng': 66.96,
    'created_at': '2026-10-01T08:00:00Z',
    'updated_at': '2026-10-01T09:00:00Z',
    if (withHistory)
      'history': [
        for (final (i, h) in history.indexed)
          {
            'id': i + 1,
            'from_status': h.from,
            'to_status': h.to,
            'created_at': '2026-10-01T09:0$i:00Z',
            'attachments': <Object>[],
          },
      ],
  };
}

/// The API server's auth, profile, invite and load endpoints, in memory.
/// Behaves like the real one where the app depends on it: login answers 403
/// for anything wrong, register answers 409 for a verified e-mail, the code
/// is 123456, logout revokes the refresh token, a load only moves one
/// status at a time and a driver has one active load.
class FakeBackend {
  FakeBackend() {
    server = FakeServer(_handle);
  }

  late final FakeServer server;

  /// When false, every request fails as if there were no network.
  bool online = true;

  /// e-mail → password of verified accounts.
  final accounts = <String, String>{'driver@yool.live': 'password1'};
  final pending = <String>{};
  String firstName = 'Ali';
  String lastName = 'Valiev';
  bool profileDeleted = false;
  int logouts = 0;
  final devices = <String, String>{};
  final invites = <String, FakeInvite>{};

  /// In the order the server lists them.
  final loads = <String, FakeLoad>{};

  /// Load ids of the GPS points taken, in the order they came.
  final takenPoints = <String>[];

  /// Points that came for a load the server doesn't know.
  int droppedPoints = 0;

  /// Every photo upload fails (with a 500).
  bool failUploads = false;
  int uploads = 0;

  static const _activeStatuses = {
    'accepted',
    'picking_up',
    'picked_up',
    'in_transit',
    'dropping_off',
    'dropped_off',
  };
  static const _historyStatuses = {'dropped_off', 'confirmed', 'cancelled'};
  static const _transitions = {
    'accept': ('assigned', 'accepted'),
    'pickup/begin': ('accepted', 'picking_up'),
    'pickup/confirm': ('picking_up', 'picked_up'),
    'start': ('picked_up', 'in_transit'),
    'dropoff/begin': ('in_transit', 'dropping_off'),
    'dropoff/confirm': ('dropping_off', 'dropped_off'),
  };

  String? get activeLoadId {
    for (final load in loads.values) {
      if (load.isActive) return load.id;
    }
    return null;
  }

  /// Gives the driver [id] as an accepted load.
  set activeLoadId(String? id) {
    if (id == null) return;
    (loads[id] ??= FakeLoad(id)).status = 'accepted';
  }

  /// Adds [count] assigned loads `P1`, `P2`, ….
  void addPending(int count) {
    for (var i = 1; i <= count; i++) {
      loads['P$i'] = FakeLoad('P$i');
    }
  }

  /// `POST /tracking/locations`, answered as the real server does: about
  /// the load of the batch's latest point, "stop" once it's confirmed,
  /// cancelled or unknown. The real one checks each point's time against
  /// the load's window; here every point of a known load is taken. The
  /// library talks to the server with its own HTTP client, so this isn't
  /// behind [server].
  BatchResult takePoints(List<String?> loadIds) {
    for (final id in loadIds) {
      if (loads[id] case final load?) {
        takenPoints.add(load.id);
      } else {
        droppedPoints++;
      }
    }
    final latest = loads[loadIds.last];
    return BatchResult(
      status: 200,
      stopTracking:
          latest == null ||
          latest.status == 'confirmed' ||
          latest.status == 'cancelled',
      loadStatus: latest?.status,
    );
  }

  int _issued = 0;
  final _validRefresh = <String>{};

  List<RequestOptions> requestsTo(String path) => server.requestsTo(path);

  Future<FakeResponse> _handle(RequestOptions r) async {
    if (!online) return offline(r);
    final body = switch (r.data) {
      final Map<Object?, Object?> map => map.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final path = r.path;
    final authed = r.headers['Authorization'] != null;

    switch ((r.method, path)) {
      case ('POST', '/auth/login'):
        if (accounts[body['email']] != body['password']) {
          return _error(403, 'FORBIDDEN', 'permission denied');
        }
        return _tokens();
      case ('POST', '/auth/register'):
        final email = body['email'] as String;
        if (accounts.containsKey(email)) {
          return _error(409, 'CONFLICT', 'email');
        }
        pending.add(email);
        accounts[email] = body['password'] as String;
        firstName = body['first_name'] as String? ?? '';
        lastName = body['last_name'] as String? ?? '';
        return (status: 200, body: null);
      case ('POST', '/auth/verify-email'):
        if (body['code'] != '123456') {
          return _error(400, 'OTP_MISMATCH', 'otp mismatch');
        }
        pending.remove(body['email']);
        return _tokens();
      case ('POST', '/auth/refresh'):
        if (!_validRefresh.contains(body['refresh_token'])) {
          return _error(401, 'UNAUTHORIZED', 'token expired');
        }
        return _tokens();
      case ('POST', '/auth/pkce'):
        return (status: 200, body: {'state': 'st', 'code_challenge': 'ch'});
      case ('POST', '/auth/telegram'):
        if (body['id_token'] != 'tg-id-token') {
          return _error(403, 'FORBIDDEN', 'bad id_token');
        }
        return _tokens();
      case ('POST', '/auth/telegram/callback'):
        if (body['code'] != 'tg-code') {
          return _error(403, 'FORBIDDEN', 'bad code');
        }
        return _tokens();
      case ('POST', '/auth/logout'):
        logouts++;
        _validRefresh.clear();
        return (status: 200, body: null);
      case ('GET', '/users/me') when authed:
        return (
          status: 200,
          body: {
            'id': 'u1',
            'first_name': firstName,
            'last_name': lastName,
            'email': 'driver@yool.live',
          },
        );
      case ('PUT', '/users/me') when authed:
        firstName = body['first_name'] as String;
        lastName = body['last_name'] as String;
        return (status: 200, body: {});
      case ('DELETE', '/users/me') when authed:
        profileDeleted = true;
        _validRefresh.clear();
        return (status: 200, body: null);
      case ('POST', '/users/me/devices') when authed:
        devices[body['device_id'] as String] = body['device_token'] as String;
        return (status: 200, body: null);
      case ('GET', '/loads/pending') when authed:
        return _page(r, (l) => l.status == 'assigned');
      case ('GET', '/loads/history') when authed:
        return _page(r, (l) => _historyStatuses.contains(l.status));
      case ('GET', '/loads/active') when authed:
        final id = activeLoadId;
        if (id == null) return _error(404, 'NOT_FOUND', 'no active load');
        return (status: 200, body: loads[id]!.toJson(withHistory: true));
      case ('POST', '/attachments/image') when authed:
        uploads++;
        if (failUploads) return _error(500, 'INTERNAL_ERROR', 'storage');
        return (status: 200, body: {'ID': 'att-$uploads'});
    }

    final segments = Uri.parse(path).pathSegments;
    if (segments case ['loads', final id, ...final action] when authed) {
      final load = loads[id];
      if (load == null) return _error(404, 'NOT_FOUND', 'load');
      if (action.isEmpty && r.method == 'GET') {
        return (status: 200, body: load.toJson(withHistory: true));
      }
      if (_transitions[action.join('/')] case (
        final from,
        final to,
      ) when r.method == 'POST') {
        if (load.status != from) {
          return _error(400, 'BAD_REQUEST', 'status: invalid transition');
        }
        if (to == 'accepted' && activeLoadId != null) {
          return _error(409, 'CARRIER_HAS_ACTIVE_LOAD', 'active load');
        }
        load
          ..history.add((from: from, to: to))
          ..attachments[to] = [
            ...(body['attachment_ids'] as List? ?? const []).cast<String>(),
          ]
          ..status = to;
        return (status: 200, body: null);
      }
    }
    if (segments case ['invites', final token, ...]) {
      final invite = invites[token];
      if (invite == null) return _error(404, 'NOT_FOUND', 'invite');
      if (segments.length == 2 && r.method == 'GET') {
        return (
          status: 200,
          body: {
            'status': invite.status,
            'accepted_by_me': authed && invite.acceptedByMe,
            'load_id': invite.loadId,
            'load': {
              'title': 'Tashkent → Samarkand',
              'company_name': 'Karavan',
              'pickup_address': 'Tashkent',
              'dropoff_address': 'Samarkand',
            },
          },
        );
      }
      if (segments.length == 3 && segments[2] == 'accept' && authed) {
        if (activeLoadId != null && activeLoadId != invite.loadId) {
          return _error(409, 'CARRIER_HAS_ACTIVE_LOAD', 'active load');
        }
        if (invite.status != 'pending' && !invite.acceptedByMe) {
          return _error(409, 'CONFLICT', 'invite accepted');
        }
        invites[token] = (
          status: 'accepted',
          loadId: invite.loadId,
          acceptedByMe: true,
        );
        activeLoadId = invite.loadId;
        loads[invite.loadId]!.title = 'Tashkent → Samarkand';
        return (status: 200, body: {'load_id': invite.loadId});
      }
    }
    if (!authed) return _error(401, 'UNAUTHORIZED', 'no token');
    return _error(404, 'NOT_FOUND', '${r.method} $path');
  }

  FakeResponse _page(RequestOptions r, bool Function(FakeLoad) where) {
    final limit = r.queryParameters['limit'] as int;
    final offset = r.queryParameters['offset'] as int;
    final all = loads.values.where(where).toList();
    return (
      status: 200,
      body: {
        'result': [
          for (final load in all.skip(offset).take(limit)) load.toJson(),
        ],
        'limit': limit,
        'offset': offset,
        'count': all.length,
      },
    );
  }

  FakeResponse _tokens() {
    _issued++;
    final refresh = 'refresh-$_issued';
    _validRefresh.add(refresh);
    return (
      status: 200,
      body: {
        'access_token': 'access-$_issued',
        'refresh_token': refresh,
        'expires_in': 900,
      },
    );
  }

  FakeResponse _error(int status, String code, String message) =>
      (status: status, body: {'code': code, 'message': message});
}
