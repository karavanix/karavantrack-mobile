import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../utils/command.dart';
import '../../../utils/formatters.dart';
import '../../../utils/result.dart';
import '../../auth/view_models/login_view_model.dart';
import '../../verify_email/view_models/verify_email_view_model.dart';

enum ResetStep {
  /// Asking which account.
  email,

  /// The code is in the mail; the code and the new password go together.
  code,
}

typedef NewPassword = ({String code, String password});

/// Forgotten password: the e-mail gets a code, the code and a new
/// password set it. No sign-in at the end; the driver enters the new
/// password on the sign-in screen.
class ForgotPasswordViewModel extends ChangeNotifier {
  ForgotPasswordViewModel({required this._auth, String email = ''})
    : _email = email.trim() {
    sendCode = Command1(_sendCode);
    reset = Command1(_reset);
  }

  final AuthRepository _auth;

  /// Sends (or re-sends) the code to the e-mail given.
  late final Command1<void, String> sendCode;

  /// Sets the new password; Ok means it's done and the screen can close.
  late final Command1<void, NewPassword> reset;

  String _email;
  ResetStep _step = ResetStep.email;

  /// The e-mail the code went to; before that, what the sign-in form had.
  String get email => _email;

  ResetStep get step => _step;

  /// Back from the code to the e-mail, to correct it.
  void backToEmail() {
    _step = ResetStep.email;
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

  Future<Result<void>> _reset(NewPassword form) {
    final code = form.code.trim();
    if (code.isEmpty) {
      return Future.value(const Result.error(EmptyCodeException()));
    }
    if (form.password.length < 8) {
      return Future.value(
        const Result.error(FormException(FormProblem.passwordTooShort)),
      );
    }
    return _auth.resetPassword(
      email: _email,
      code: code,
      newPassword: form.password,
    );
  }

  @override
  void dispose() {
    sendCode.dispose();
    reset.dispose();
    super.dispose();
  }
}
