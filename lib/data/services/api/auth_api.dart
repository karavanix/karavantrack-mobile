import '../../../utils/result.dart';
import 'api_client.dart';
import 'models/token_pair.dart';

/// The `/auth/*` endpoints. They don't need a token, so this goes through a
/// public [ApiClient].
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<Result<TokenPair>> refresh(String refreshToken) => _client.post(
    '/auth/refresh',
    data: {'refresh_token': refreshToken},
    decode: TokenPair.fromJson,
  );
}
