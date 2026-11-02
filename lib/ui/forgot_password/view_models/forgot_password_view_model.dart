import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api/api_exception.dart';
import '../../../utils/command.dart';
import '../../../utils/formatters.dart';
import '../../../utils/result.dart';
import '../../auth/view_models/login_view_model.dart';
import '../../verify_email/view_models/verify_email_view_model.dart';

enum ResetStep {
  /// Asking which account.
  email,

  /// The code is in the mail; asking for it.
  code,

  /// The code is in hand; asking for the new password, twice.
  password,
}

typedef NewPassword = ({String password, String confirmation});

/// The two passwords typed differ.
class PasswordMismatchException implements Exception {
  const PasswordMismatchException();
}

/// Forgotten password in three steps: the e-mail gets a code, the code
/// is typed in, then a new password with its confirmation sets it. The
/// server checks the code only together with the password, so a wrong
/// code comes back from the last step and returns the driver to the
/// code step. No sign-in at the end; the driver enters the new password
/// on the sign-in screen.
class ForgotPasswordViewModel extends ChangeNotifier {
  ForgotPasswordViewModel({required this._auth, String email = ''})
    : _email = email.trim() {
    sendCode = Command1(_sendCode);
    confirmCode = Command1(_confirmCode);
    reset = Command1(_reset);
  }

  final AuthRepository _auth;

  /// Sends (or re-sends) the code to the e-mail given.
  late final Command1<void, String> sendCode;

  /// Keeps the code typed and moves on to the password.
  late final Command1<void, String> confirmCode;

  /// Sets the new password; Ok means it's done and the screen can close.
  late final Command1<void, NewPassword> reset;

  String _email;
  String _code = '';
  ResetStep _step = ResetStep.email;

  /// The e-mail the code went to; before that, what the sign-in form had.
  String get email => _email;

  ResetStep get step => _step;

  /// One step back: from the password to the code, from the code to the
  /// e-mail. Nothing to do at the e-mail.
  void back() {
    _step = switch (_step) {
      ResetStep.email || ResetStep.code => ResetStep.email,
      ResetStep.password => ResetStep.code,
    };
    notifyListeners();
  }

  Future<Result<void>> _sendCode(String email) async {
    final trimmed = email.trim();
    if (!isValidEmail(trimmed)) {
      return const Result.error(FormException(FormProblem.invalidEmail));
    }
    final result = await _auth.requestPasswordReset(trimmed);
    if (result is Ok<void>) {
      _email = trimmed;
      _step = ResetStep.code;
      notifyListeners();
    }
    return result;
  }

  Future<Result<void>> _confirmCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const Result.error(EmptyCodeException());
    _code = trimmed;
    _step = ResetStep.password;
    notifyListeners();
    return const Result.ok(null);
  }

  Future<Result<void>> _reset(NewPassword form) async {
    if (form.password.length < 8) {
      return const Result.error(FormException(FormProblem.passwordTooShort));
    }
    if (form.password != form.confirmation) {
      return const Result.error(PasswordMismatchException());
    }
    final result = await _auth.resetPassword(
      email: _email,
      code: _code,
      newPassword: form.password,
    );
    if (result case Error(
      error: HttpException(:final code?),
    ) when code.startsWith('OTP_')) {
      // The code, not the password, was refused: back to the code.
      _code = '';
      _step = ResetStep.code;
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    sendCode.dispose();
    confirmCode.dispose();
    reset.dispose();
    super.dispose();
  }
}
