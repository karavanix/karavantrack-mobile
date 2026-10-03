import '../../../domain/models/user.dart';
import '../../../utils/result.dart';
import 'api_client.dart';

/// The signed-in user's own account.
class AccountApi {
  AccountApi(this._client);

  final ApiClient _client;

  Future<Result<User>> me() => _client.get('/users/me', decode: User.fromJson);

  Future<Result<void>> updateName({
    required String firstName,
    required String lastName,
  }) => _client.put(
    '/users/me',
    data: {'first_name': firstName, 'last_name': lastName},
    decode: (_) {},
  );

  Future<Result<void>> delete() => _client.delete('/users/me', decode: (_) {});

  Future<Result<void>> registerDevice({
    required String deviceId,
    required String token,
    required String platform,
  }) => _client.post(
    '/users/me/devices',
    data: {
      'device_id': deviceId,
      'device_token': token,
      'device_type': platform,
    },
    decode: (_) {},
  );

  /// Revokes every refresh token of the user issued so far, on all devices.
  Future<Result<void>> logout() => _client.post('/auth/logout', decode: (_) {});
}
