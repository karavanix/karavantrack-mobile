import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeResponse = ({int status, Object? body});

/// Stands in for the network under dio: every request goes to [handler],
/// and is recorded in [requests].
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);

  Future<FakeResponse> Function(RequestOptions request) handler;

  final requests = <RequestOptions>[];

  List<RequestOptions> requestsTo(String path) =>
      requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A [FakeServer] handler for no connection: fails the way dio's own
/// adapter does when the host can't be reached.
Future<FakeResponse> offline(RequestOptions request) =>
    throw DioException.connectionError(
      requestOptions: request,
      reason: 'offline',
    );
