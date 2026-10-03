/// Tokens returned by login, register, refresh and the OAuth sign-ins.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  factory TokenPair.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    return TokenPair(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}
