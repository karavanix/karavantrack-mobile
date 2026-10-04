import '../../../domain/models/fix.dart';
import '../../../domain/models/load.dart';
import '../../../utils/logger.dart';
import '../../../utils/result.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// The driver's loads.
class LoadsApi {
  LoadsApi(this._client);

  final ApiClient _client;

  /// Loads assigned to the driver, waiting to be accepted.
  Future<Result<LoadPage>> pending({required int limit, required int offset}) =>
      _client.get(
        '/loads/pending',
        query: {'limit': limit, 'offset': offset},
        decode: LoadPage.fromJson,
      );

  /// Dropped off, confirmed and cancelled loads.
  Future<Result<LoadPage>> history({required int limit, required int offset}) =>
      _client.get(
        '/loads/history',
        query: {'limit': limit, 'offset': offset},
        decode: LoadPage.fromJson,
      );

  /// The load the driver has now, or Ok(null) when there is none (the
  /// server answers 404).
  Future<Result<Load?>> active() async {
    final result = await _client.get(
      '/loads/active',
      expected: const {404},
      decode: Load.fromJson,
    );
    return switch (result) {
      Error(error: HttpException(statusCode: 404)) => _none(),
      Ok(:final value) => Result.ok(value),
      Error(:final error) => Result.error(error),
    };
  }

  Result<Load?> _none() {
    log.debug('[loads] GET /loads/active: 404, no active load');
    return const Result.ok(null);
  }

  Future<Result<Load>> get(String id) =>
      _client.get('/loads/$id', decode: Load.fromJson);

  Future<Result<void>> perform(
    String id,
    LoadAction action, {
    List<String> attachmentIds = const [],
    Fix? location,
  }) => _client.post(
    '/loads/$id/${action.path}',
    data: {'attachment_ids': attachmentIds, 'location': ?location?.toJson()},
    decode: (_) {},
  );
}
