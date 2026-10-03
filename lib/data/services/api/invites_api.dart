import '../../../domain/models/invite.dart';
import '../../../utils/result.dart';
import 'api_client.dart';

class InvitesApi {
  InvitesApi(this._client);

  /// The authenticated client: viewing works without a token, but with one
  /// the server can say whether this user is the one who accepted it.
  final ApiClient _client;

  Future<Result<Invite>> get(String token) =>
      _client.get('/invites/$token', decode: Invite.fromJson);

  /// Returns the id of the load now assigned to the driver.
  Future<Result<String>> accept(String token) => _client.post(
    '/invites/$token/accept',
    decode: (body) => (body as Map<String, Object?>)['load_id'] as String,
  );
}
