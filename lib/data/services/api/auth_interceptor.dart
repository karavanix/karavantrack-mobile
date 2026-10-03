import 'package:dio/dio.dart';

import '../../../utils/result.dart';

/// Where the interceptor gets the access token from and how it renews it.
/// Implemented by AuthRepository, the only owner of the tokens.
abstract interface class TokenSource {
  String? get accessToken;

  /// Exchanges the refresh token for a new pair. Ok with the new access
  /// token; Error(UnauthorizedException) when the server rejected the
  /// refresh token and the user has been signed out; any other Error when
  /// the refresh couldn't be done (offline, 5xx) and the session is kept.
  Future<Result<String>> refreshAccessToken();
}

/// Attaches `Authorization: Bearer <access token>` and handles 401.
///
/// Being a [QueuedInterceptor], it handles errors one at a time. When a
/// batch of requests all fail with 401 because the token expired, the first
/// one refreshes the token and retries; the rest wait in the queue, then see
/// that the token they were sent with is no longer the current one and just
/// retry with the new token. One refresh per batch.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this._tokens, required this._retry});

  final TokenSource _tokens;
  final Dio _retry;

  static const _retriedKey = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    var token = _tokens.accessToken;
    if (token == null || options.headers['Authorization'] == 'Bearer $token') {
      // Sent with the current token (or there is none): it's this request's
      // job to refresh.
      switch (await _tokens.refreshAccessToken()) {
        case Ok(:final value):
          token = value;
        case Error(:final error):
          return handler.next(err.copyWith(error: error));
      }
    }

    try {
      final response = await _retry.fetch<Object?>(
        options.copyWith(
          headers: {...options.headers, 'Authorization': 'Bearer $token'},
          extra: {...options.extra, _retriedKey: true},
          // A multipart body is a one-shot stream; send a fresh copy.
          data: switch (options.data) {
            final FormData form => form.clone(),
            final other => other,
          },
        ),
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
