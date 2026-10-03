import 'package:dio/dio.dart';

/// Why an API call failed. Services turn every [DioException] into one of
/// these, so nothing above the service layer imports dio.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No response: offline, DNS, timeout, TLS. Worth retrying later.
final class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// The session is gone: the refresh token was rejected and the user has been
/// signed out. The router takes them to the login screen.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('unauthorized');
}

/// The server answered with an error status. The API's error body is
/// `{"code": "...", "message": "...", "details": ...}`; [code] is the
/// machine-readable part to branch on, [message] is for logs.
final class HttpException extends ApiException {
  const HttpException(this.statusCode, super.message, {this.code});

  final int statusCode;
  final String? code;

  bool get isClientError => statusCode >= 400 && statusCode < 500;
}

/// The response came back but its body isn't what the client expected.
final class DecodeException extends ApiException {
  const DecodeException(super.message);
}

ApiException apiExceptionFrom(DioException e) {
  if (e.error case final ApiException inner) return inner;
  final response = e.response;
  if (response == null) {
    return NetworkException(e.message ?? e.type.name);
  }
  final status = response.statusCode ?? 0;
  final body = response.data;
  final (code, message) = switch (body) {
    {'code': final String code, 'message': final String message} => (
      code,
      message,
    ),
    _ => (null, 'HTTP $status'),
  };
  return HttpException(status, message, code: code);
}
