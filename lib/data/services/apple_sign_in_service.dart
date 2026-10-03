import 'dart:io';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../utils/result.dart';

typedef AppleCredential = ({
  String identityToken,
  String? firstName,
  String? lastName,
});

class AppleSignInCancelled implements Exception {
  const AppleSignInCancelled();
}

/// Sign in with Apple's system sheet. iOS only.
class AppleSignInService {
  bool get isAvailable => Platform.isIOS;

  /// Error(AppleSignInCancelled) when the user closed the sheet.
  Future<Result<AppleCredential>> requestCredential() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        return Result.error(Exception('Apple returned no identity token'));
      }
      return Result.ok((
        identityToken: token,
        // Apple only sends the name on the first sign-in.
        firstName: credential.givenName,
        lastName: credential.familyName,
      ));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Result.error(AppleSignInCancelled());
      }
      return Result.error(e);
    }
  }
}
