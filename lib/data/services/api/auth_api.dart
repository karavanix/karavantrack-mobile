import '../../../utils/result.dart';
import 'api_client.dart';
import 'models/token_pair.dart';

/// What the server records about a new account besides the credentials:
/// the language of its e-mails and pushes (`ru`, `uz` or `en`) and where
/// the sign-up came from. Every sign-up carries one; for an account that
/// already exists the server ignores it.
typedef SignUpInfo = ({String language, String source});

/// The `/auth/*` endpoints that don't need a token. Every account made from
/// this app is a carrier, hence the fixed role.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  static const _role = 'carrier';

  static Map<String, Object?> _signUpFields(SignUpInfo info) => {
    'language': info.language,
    'attribution': {'source': info.source},
  };

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
    required SignUpInfo info,
  }) => _client.post(
    '/auth/register',
    data: {
      'email': email,
      'password': password,
      'role': _role,
      if (firstName.isNotEmpty) 'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
      ..._signUpFields(info),
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
    required SignUpInfo info,
  }) => _client.post(
    '/auth/apple',
    data: {
      'id_token': idToken,
      'authorization_code': authorizationCode,
      'role': _role,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
      ..._signUpFields(info),
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
  Future<Result<TokenPair>> telegramIdToken(
    String idToken, {
    required SignUpInfo info,
  }) => _client.post(
    '/auth/telegram',
    data: {'id_token': idToken, 'role': _role, ..._signUpFields(info)},
    decode: TokenPair.fromJson,
  );

  /// Sign-in with a browser-login code; the server exchanges it.
  Future<Result<TokenPair>> telegram({
    required String code,
    required String state,
    required String redirectUri,
    required SignUpInfo info,
  }) => _client.post(
    '/auth/telegram/callback',
    data: {
      'code': code,
      'state': state,
      'redirect_uri': redirectUri,
      'role': _role,
      ..._signUpFields(info),
    },
    decode: TokenPair.fromJson,
  );

  /// E-mails a reset code to [email]. Always Ok: whether the account
  /// exists is not told.
  Future<Result<void>> forgotPassword(String email) => _client.post(
    '/auth/password/forgot',
    data: {'email': email},
    decode: (_) {},
  );

  /// Sets the password with the code from the e-mail. No tokens: the user
  /// signs in with the new password. Every other device is signed out.
  Future<Result<void>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _client.post(
    '/auth/password/reset',
    data: {'email': email, 'code': code, 'new_password': newPassword},
    decode: (_) {},
  );

  Future<Result<TokenPair>> refresh(String refreshToken) => _client.post(
    '/auth/refresh',
    data: {'refresh_token': refreshToken},
    decode: TokenPair.fromJson,
  );
}
