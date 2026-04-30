import 'package:http/http.dart' as http;
import 'package:talker_flutter/talker_flutter.dart';

class DebugService {
  DebugService._();
  static final talker = TalkerFlutter.init();
  static http.Client createHttpClient() => _LoggingHttpClient();
}

class _LoggingHttpClient extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    DebugService.talker.info('→ ${request.method} ${request.url}');
    final sw = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      DebugService.talker.info(
        '← ${response.statusCode} ${request.url} (${sw.elapsedMilliseconds}ms)',
      );
      return response;
    } catch (e, st) {
      DebugService.talker.error('✗ ${request.method} ${request.url}', e, st);
      rethrow;
    }
  }
}
