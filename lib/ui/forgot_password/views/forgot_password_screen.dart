import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/api/api_exception.dart';
import '../../../utils/result.dart';
import '../../auth/view_models/login_view_model.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../verify_email/view_models/verify_email_view_model.dart';
import '../view_models/forgot_password_view_model.dart';

/// Three steps on one screen: the e-mail, the code, then the new
/// password with its confirmation. Closes with `true` once the password
/// is set.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.viewModel});

  final ForgotPasswordViewModel viewModel;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailCtrl = TextEditingController(text: _vm.email);
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmationCtrl = TextEditingController();
  bool _obscurePassword = true;

  ForgotPasswordViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.sendCode.addListener(_onSendCodeChanged);
    _vm.confirmCode.addListener(_onConfirmCodeChanged);
    _vm.reset.addListener(_onResetChanged);
  }

  @override
  void dispose() {
    _vm.sendCode.removeListener(_onSendCodeChanged);
    _vm.confirmCode.removeListener(_onConfirmCodeChanged);
    _vm.reset.removeListener(_onResetChanged);
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmationCtrl.dispose();
    super.dispose();
  }

  void _onSendCodeChanged() {
    if (_vm.sendCode.result case Error(:final error)) {
      _vm.sendCode.clearResult();
      _showError(error);
    }
  }

  void _onConfirmCodeChanged() {
    if (_vm.confirmCode.result case Error(:final error)) {
      _vm.confirmCode.clearResult();
      _showError(error);
    }
  }

  void _onResetChanged() {
    switch (_vm.reset.result) {
      case Ok():
        _vm.reset.clearResult();
        context.pop(true);
      case Error(:final error):
        _vm.reset.clearResult();
        // The server refused the code: the view model went back to the
        // code step, and the field starts clean for the next one.
        if (_vm.step == ResetStep.code) _codeCtrl.clear();
        _showError(error);
      case null:
        break;
    }
  }

  void _showError(Exception error) {
    final text = resetPasswordErrorText(context.l10n, error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([
        _vm,
        _vm.sendCode,
        _vm.confirmCode,
        _vm.reset,
      ]),
      builder: (context, child) {
        final loading = _vm.sendCode.running || _vm.reset.running;
        final step = _vm.step;
        return PopScope(
          // Back goes one step back, not out of the screen.
          canPop: step == ResetStep.email,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _vm.back();
          },
          child: Scaffold(
            appBar: AppBar(title: Text(t.resetPasswordTitle)),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          switch (step) {
                            ResetStep.email => Icons.lock_reset_outlined,
                            ResetStep.code => Icons.mark_email_read_outlined,
                            ResetStep.password => Icons.password_outlined,
                          },
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          switch (step) {
                            ResetStep.email => t.resetPasswordIntro,
                            ResetStep.code => t.resetCodeSent(_vm.email),
                            ResetStep.password => t.resetNewPasswordIntro,
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: switch (step) {
                              ResetStep.email => _emailStep(t, loading),
                              ResetStep.code => _codeStep(t, loading),
                              ResetStep.password => _passwordStep(t, loading),
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (step == ResetStep.code)
                          Center(
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => _vm.sendCode.execute(_vm.email),
                              child: Text(t.resetResendCode),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emailStep(AppLocalizations t, bool loading) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: InputDecoration(labelText: t.email),
      ),
      const SizedBox(height: 20),
      _Button(
        loading: loading,
        onPressed: () => _vm.sendCode.execute(_emailCtrl.text),
        label: t.sendCode,
      ),
    ],
  );

  Widget _codeStep(AppLocalizations t, bool loading) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        autofocus: true,
        style: const TextStyle(
          fontSize: 24,
          letterSpacing: 8,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: t.verificationCodeLabel,
          counterText: '',
        ),
        onSubmitted: (code) => _vm.confirmCode.execute(code),
      ),
      const SizedBox(height: 20),
      _Button(
        loading: loading,
        onPressed: () => _vm.confirmCode.execute(_codeCtrl.text),
        label: t.next,
      ),
    ],
  );

  Widget _passwordStep(AppLocalizations t, bool loading) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        autofocus: true,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: t.newPassword,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? t.showPassword : t.hidePassword,
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirmationCtrl,
        // One eye for both: showing the first shows the second too.
        obscureText: _obscurePassword,
        decoration: InputDecoration(labelText: t.confirmPassword),
        onSubmitted: (_) => _submitPassword(),
      ),
      const SizedBox(height: 20),
      _Button(
        loading: loading,
        onPressed: _submitPassword,
        label: t.changePassword,
      ),
    ],
  );

  void _submitPassword() => _vm.reset.execute((
    password: _passwordCtrl.text,
    confirmation: _confirmationCtrl.text,
  ));
}

class _Button extends StatelessWidget {
  const _Button({
    required this.loading,
    required this.onPressed,
    required this.label,
  });

  final bool loading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    ),
  );
}

/// The message for a failed step of the reset. The code messages differ
/// from the sign-up ones: here a new code is one tap away.
String resetPasswordErrorText(
  AppLocalizations l10n,
  Exception error,
) => switch (error) {
  FormException(problem: FormProblem.invalidEmail) => l10n.errorInvalidEmail,
  FormException(problem: FormProblem.passwordTooShort) =>
    l10n.errorPasswordTooShort,
  FormException() => l10n.errorServer,
  EmptyCodeException() => l10n.enterVerificationCode,
  PasswordMismatchException() => l10n.errorPasswordsMismatch,
  HttpException(code: 'OTP_EXPIRED' || 'OTP_NOT_FOUND') =>
    l10n.errorResetCodeExpired,
  HttpException(code: 'OTP_TOO_MANY_ATTEMPTS') => l10n.errorResetCodeTooMany,
  _ => errorText(l10n, error),
};
