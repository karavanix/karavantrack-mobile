import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../../../config/env.dart';
import '../../../utils/logger.dart';
import '../../../utils/result.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// HTTP access to the API. Two flavours share the same setup:
/// [ApiClient.public] for the auth endpoints (login, refresh, …), which
/// carry no token, and [ApiClient.authenticated] for everything else, which
/// attaches the access token and refreshes it on 401 (see [AuthInterceptor]).
///
/// Every call returns a [Result]; dio exceptions never leave this class.
class ApiClient {
  ApiClient.public({HttpClientAdapter? adapter}) : _dio = _createDio(adapter);

  ApiClient.authenticated({
    required TokenSource tokens,
    HttpClientAdapter? adapter,
  }) : _dio = _createDio(adapter) {
    // Retries go through a second client without the auth interceptor: a
    // retry issued from inside the interceptor's error queue would otherwise
    // wait on that same queue if it got a 401 again.
    _dio.interceptors.insert(
      0,
      AuthInterceptor(tokens: tokens, retry: _createDio(adapter)),
    );
  }

  final Dio _dio;

  /// [expected] are error statuses that are a normal answer to this
  /// request (404 for "none"): the caller still gets them as errors, but
  /// they're left out of the HTTP log.
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Set<int> expected = const {},
    required T Function(Object? body) decode,
  }) => _send('GET', path, query: query, expected: expected, decode: decode);

  Future<Result<T>> post<T>(
    String path, {
    Object? data,
    required T Function(Object? body) decode,
  }) => _send('POST', path, data: data, decode: decode);

  Future<Result<T>> put<T>(
    String path, {
    Object? data,
    required T Function(Object? body) decode,
  }) => _send('PUT', path, data: data, decode: decode);

  Future<Result<T>> delete<T>(
    String path, {
    Object? data,
    required T Function(Object? body) decode,
  }) => _send('DELETE', path, data: data, decode: decode);

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Set<int> expected = const {},
    required T Function(Object? body) decode,
  }) async {
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {if (expected.isNotEmpty) _expectedKey: expected},
        ),
      );
    } on DioException catch (e) {
      return Result.error(apiExceptionFrom(e));
    }
    try {
      return Result.ok(decode(response.data));
    } catch (e, st) {
      log.error('Unexpected response to $method $path', e, st);
      return Result.error(DecodeException('$method $path: $e'));
    }
  }

  static Dio _createDio(HttpClientAdapter? adapter) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiPrefix,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(quietHttpLog());
    return dio;
  }
}

const _expectedKey = 'expectedStatuses';

/// Method, URL, status and timing only: bodies and headers carry tokens
/// and personal data, and the log can be shared from the phone. Statuses a
/// request expects (see [ApiClient.get]) aren't logged as errors.
TalkerDioLogger quietHttpLog() => TalkerDioLogger(
  talker: log,
  settings: const TalkerDioLoggerSettings(
    errorFilter: _unexpected,
    printRequestHeaders: false,
    printRequestData: false,
    printResponseHeaders: false,
    printResponseData: false,
    printResponseMessage: false,
    printErrorHeaders: false,
  ),
);

bool _unexpected(DioException e) {
  final expected = e.requestOptions.extra[_expectedKey] as Set<int>?;
  return !(expected?.contains(e.response?.statusCode) ?? false);
}
