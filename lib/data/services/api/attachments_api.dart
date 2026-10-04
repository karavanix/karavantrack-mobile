import 'package:dio/dio.dart';

import '../../../utils/result.dart';
import 'api_client.dart';

class AttachmentsApi {
  AttachmentsApi(this._client);

  final ApiClient _client;

  /// Uploads a proof-of-delivery photo and returns its attachment id. The
  /// server scales it down to 1600 px and keeps it private: the shipper
  /// sees it through the load's history.
  Future<Result<String>> uploadPhoto(String filePath) async => _client.post(
    '/attachments/image',
    data: FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'visibility': 'private',
      'folder': 'pod',
      'compress': 'true',
      'width': '1600',
    }),
    decode: (body) => (body as Map<String, Object?>)['ID'] as String,
  );
}
