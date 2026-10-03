import 'package:material_ui/material_ui.dart';

import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../view_models/verify_email_view_model.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.viewModel});

  final VerifyEmailViewModel viewModel;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();

  VerifyEmailViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.verify.addListener(_onVerifyChanged);
  }

  @override
  void dispose() {
    _vm.verify.removeListener(_onVerifyChanged);
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onVerifyChanged() {
    if (_vm.verify.result case Error(:final error)) {
      _vm.verify.clearResult();
      final t = context.l10n;
      final text = error is EmptyCodeException
          ? t.enterVerificationCode
          : errorText(t, error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _submit() => _vm.verify.execute(_codeCtrl.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([_vm.verify, _vm.back]),
      builder: (context, child) {
        final loading = _vm.verify.running || _vm.back.running;
        final email = _vm.email;
        return Scaffold(
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
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.verifyEmail,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.verificationCodeSent} $email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _codeCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                style: const TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: t.verificationCodeLabel,
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: loading ? null : _submit,
                                  child: loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(t.verify),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: loading ? null : _vm.back.execute,
                          child: Text(t.verifyBackToSignUp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
