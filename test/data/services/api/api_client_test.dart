import 'package:dio/dio.dart';
import 'package:driver_tracking_app/data/repositories/auth_repository.dart';
import 'package:driver_tracking_app/data/services/api/api_client.dart';
import 'package:driver_tracking_app/data/services/api/api_exception.dart';
import 'package:driver_tracking_app/data/services/api/auth_api.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:driver_tracking_app/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fake_local_store.dart';
import '../../../testing/fake_server.dart';
import '../../../testing/fake_services.dart';

/// The real chain — ApiClient, AuthInterceptor, AuthRepository, AuthApi —
/// over a fake network.
AuthRepository authRepository(FakeServer server, FakeLocalStore store) =>
    AuthRepository(
      api: AuthApi(ApiClient.public(adapter: server)),
      store: store,
      apple: FakeAppleSignInService(),
      telegram: FakeTelegramAuthService(),
    );

void main() {
  late FakeServer server;
  late FakeLocalStore store;
  late AuthRepository auth;
  late ApiClient api;

  /// A server where `old` has expired and refreshing with `r1` yields `new`.
  Future<FakeResponse> expiringServer(RequestOptions request) async {
    if (request.path == '/auth/refresh') {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if ((request.data as Map)['refresh_token'] != 'r1') {
        return (status: 401, body: {'code': 'UNAUTHORIZED', 'message': ''});
      }
      return (
        status: 200,
        body: {'access_token': 'new', 'refresh_token': 'r2', 'expires_in': 900},
      );
    }
    if (request.headers['Authorization'] != 'Bearer new') {
      return (status: 401, body: {'code': 'UNAUTHORIZED', 'message': ''});
    }
    return (status: 200, body: {'path': request.path});
  }

  setUp(() {
    server = FakeServer(expiringServer);
    store = FakeLocalStore({
      StoreKeys.accessToken: 'old',
      StoreKeys.refreshToken: 'r1',
    });
    auth = authRepository(server, store);
    api = ApiClient.authenticated(tokens: auth, adapter: server);
  });

  Future<Result<String>> getPath(String path) =>
      api.get(path, decode: (body) => (body as Map)['path'] as String);

  test('sends the current access token', () async {
    store.values[StoreKeys.accessToken] = 'new';
    auth = authRepository(server, store);
    api = ApiClient.authenticated(tokens: auth, adapter: server);

    final result = await getPath('/carrier/loads');

    expect(result, isA<Ok<String>>());
    expect(server.requests.single.headers['Authorization'], 'Bearer new');
  });

  test('a batch of 401s refreshes once and retries every request', () async {
    final results = await Future.wait([
      getPath('/a'),
      getPath('/b'),
      getPath('/c'),
    ]);

    expect(server.requestsTo('/auth/refresh'), hasLength(1));
    expect(
      [for (final r in results) (r as Ok<String>).value],
      ['/a', '/b', '/c'],
    );
    expect(auth.accessToken, 'new');
    expect(store.values[StoreKeys.accessToken], 'new');
    expect(store.values[StoreKeys.refreshToken], 'r2');
    expect(auth.isSignedIn, isTrue);
  });

  test('a rejected refresh token signs out', () async {
    store.values[StoreKeys.refreshToken] = 'revoked';
    auth = authRepository(server, store);
    api = ApiClient.authenticated(tokens: auth, adapter: server);
    var notified = 0;
    auth.addListener(() => notified++);

    final results = await Future.wait([getPath('/a'), getPath('/b')]);

    for (final result in results) {
      expect((result as Error<String>).error, isA<UnauthorizedException>());
    }
    expect(server.requestsTo('/auth/refresh'), hasLength(1));
    expect(auth.isSignedIn, isFalse);
    expect(store.values, isEmpty);
    expect(notified, 1);
  });

  test('a refresh that fails for lack of network keeps the session', () async {
    server.handler = (request) => request.path == '/auth/refresh'
        ? offline(request)
        : expiringServer(request);

    final result = await getPath('/a');

    expect((result as Error<String>).error, isA<NetworkException>());
    expect(auth.isSignedIn, isTrue);
    expect(store.values[StoreKeys.refreshToken], 'r1');
  });

  test('a 401 on the retried request is not refreshed again', () async {
    server.handler = (request) async => request.path == '/auth/refresh'
        ? expiringServer(request)
        : (status: 401, body: {'code': 'UNAUTHORIZED', 'message': ''});

    final result = await getPath('/a');

    expect(
      (result as Error<String>).error,
      isA<HttpException>().having((e) => e.statusCode, 'status', 401),
    );
    expect(server.requestsTo('/auth/refresh'), hasLength(1));
    expect(server.requestsTo('/a'), hasLength(2));
  });

  test('an error body becomes HttpException with the server code', () async {
    server.handler = (_) async => (
      status: 409,
      body: {'code': 'CONFLICT', 'message': 'carrier has an active load'},
    );

    final result = await api.post('/x', decode: (_) {});

    expect(
      (result as Error<void>).error,
      isA<HttpException>()
          .having((e) => e.statusCode, 'status', 409)
          .having((e) => e.code, 'code', 'CONFLICT'),
    );
  });

  test('no connection becomes NetworkException', () async {
    server.handler = offline;

    final result = await api.get('/x', decode: (_) {});

    expect((result as Error<void>).error, isA<NetworkException>());
  });

  test('an unexpected body becomes DecodeException', () async {
    server.handler = (_) async => (status: 200, body: ['not', 'a', 'map']);
    store.values[StoreKeys.accessToken] = 'new';

    final result = await getPath('/x');

    expect((result as Error<String>).error, isA<DecodeException>());
  });
}
