import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE pair (RFC 7636): the verifier stays on the device, the challenge
/// goes into the login link, and only the holder of the verifier can trade
/// the code that comes back.
typedef Pkce = ({String verifier, String challenge});

Pkce createPkce([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final verifier = _base64Url(bytes);
  return (verifier: verifier, challenge: pkceChallenge(verifier));
}

/// S256: base64url(SHA-256(verifier)), unpadded.
String pkceChallenge(String verifier) =>
    _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
