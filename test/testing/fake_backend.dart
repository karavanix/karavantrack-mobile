import 'package:dio/dio.dart';

import 'fake_server.dart';

typedef FakeInvite = ({String status, String loadId, bool acceptedByMe});

/// The API server's auth, profile and invite endpoints, in memory. Behaves
/// like the real one where the app depends on it: login answers 403 for
/// anything wrong, register answers 409 for a verified e-mail, the code is
/// 123456, logout revokes the refresh token.
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
  String? activeLoadId;

  int _issued = 0;
  final _validRefresh = <String>{};

  List<RequestOptions> requestsTo(String path) => server.requestsTo(path);

  Future<FakeResponse> _handle(RequestOptions r) async {
    if (!online) return offline(r);
    final body = (r.data as Map?)?.cast<String, Object?>() ?? const {};
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
    }

    final segments = Uri.parse(path).pathSegments;
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
        return (status: 200, body: {'load_id': invite.loadId});
      }
    }
    if (!authed) return _error(401, 'UNAUTHORIZED', 'no token');
    return _error(404, 'NOT_FOUND', '${r.method} $path');
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
