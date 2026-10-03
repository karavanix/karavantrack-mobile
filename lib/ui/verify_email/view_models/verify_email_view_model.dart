import '../../../data/repositories/auth_repository.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class EmptyCodeException implements Exception {
  const EmptyCodeException();
}

/// The code from the sign-up e-mail.
class VerifyEmailViewModel {
  VerifyEmailViewModel({required this._auth}) {
    verify = Command1(_verify);
    back = Command0(_back);
  }

  final AuthRepository _auth;
  late final Command1<void, String> verify;
  late final Command0<void> back;

  String get email => _auth.pendingVerificationEmail ?? '';

  Future<Result<void>> _verify(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const Result.error(EmptyCodeException());
    return _auth.verifyEmail(trimmed);
  }

  Future<Result<void>> _back() async {
    await _auth.cancelVerification();
    return const Result.ok(null);
  }

  void dispose() {
    verify.dispose();
    back.dispose();
  }
}
