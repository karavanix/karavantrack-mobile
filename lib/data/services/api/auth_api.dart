import '../../../utils/result.dart';
import 'api_client.dart';
import 'models/token_pair.dart';

/// The `/auth/*` endpoints that don't need a token. Every account made from
/// this app is a carrier, hence the fixed role.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  static const _role = 'carrier';

  Future<Result<TokenPair>> login({
    required String email,
    required String password,
  }) => _client.post(
    '/auth/login',
    data: {'email': email, 'password': password},
    decode: TokenPair.fromJson,
  );

  /// Creates the account (or re-sends the code if it exists but was never
  /// verified) and e-mails a code. No tokens until [verifyEmail].
  Future<Result<void>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) => _client.post(
    '/auth/register',
    data: {
      'email': email,
      'password': password,
      'role': _role,
      if (firstName.isNotEmpty) 'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
    },
    decode: (_) {},
  );

  Future<Result<TokenPair>> verifyEmail({
    required String email,
    required String code,
  }) => _client.post(
    '/auth/verify-email',
    data: {'email': email, 'code': code},
    decode: TokenPair.fromJson,
  );

  Future<Result<TokenPair>> apple({
    required String idToken,
    required String authorizationCode,
    String? firstName,
    String? lastName,
  }) => _client.post(
    '/auth/apple',
    data: {
      'id_token': idToken,
      'authorization_code': authorizationCode,
      'role': _role,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    },
    decode: TokenPair.fromJson,
  );

  /// PKCE parameters for the Telegram login; the server keeps the verifier.
  Future<Result<({String state, String codeChallenge})>> pkce() => _client.post(
    '/auth/pkce',
    decode: (body) {
      final map = body as Map<String, Object?>;
      return (
        state: map['state'] as String,
        codeChallenge: map['code_challenge'] as String,
      );
    },
  );

  /// Sign-in with the id_token the device got from Telegram itself.
  Future<Result<TokenPair>> telegramIdToken(String idToken) => _client.post(
    '/auth/telegram',
    data: {'id_token': idToken, 'role': _role},
    decode: TokenPair.fromJson,
  );

  /// Sign-in with a browser-login code; the server exchanges it.
  Future<Result<TokenPair>> telegram({
    required String code,
    required String state,
    required String redirectUri,
  }) => _client.post(
    '/auth/telegram/callback',
    data: {
      'code': code,
      'state': state,
      'redirect_uri': redirectUri,
      'role': _role,
    },
    decode: TokenPair.fromJson,
  );

  Future<Result<TokenPair>> refresh(String refreshToken) => _client.post(
    '/auth/refresh',
    data: {'refresh_token': refreshToken},
    decode: TokenPair.fromJson,
  );
}
