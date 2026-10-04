import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../utils/command.dart';
import '../../../utils/logger.dart';
import '../../../utils/result.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/app_theme.dart';
import '../view_models/login_view_model.dart';

/// Login screen with email/password. Toggles to register mode.
/// OAuth buttons (Telegram + Apple) appear in both login and register modes.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});

  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _obscurePassword = true;

  LoginViewModel get _vm => widget.viewModel;

  List<Command<void>> get _commands => [
    _vm.submit,
    _vm.signInWithApple,
    _vm.signInWithTelegram,
  ];

  @override
  void initState() {
    super.initState();
    if (_vm.previousSignUp case final form?) {
      _emailCtrl.text = form.email;
      _firstNameCtrl.text = form.firstName;
      _lastNameCtrl.text = form.lastName;
    }
    for (final command in _commands) {
      command.addListener(_onCommandChanged);
    }
    _vm.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    for (final command in _commands) {
      command.removeListener(_onCommandChanged);
    }
    _vm.removeListener(_onViewModelChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _onCommandChanged() {
    for (final command in _commands) {
      if (command.result case Error(:final error)) {
        command.clearResult();
        _showError(error);
      }
    }
  }

  void _onViewModelChanged() {
    if (_vm.telegramError case final error?) {
      _vm.clearTelegramError();
      _showError(error);
    }
  }

  void _showError(Exception error) {
    final text = loginErrorText(context.l10n, error, signUp: _vm.isSignUp);
    if (text == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _submit() => _vm.submit.execute((
    email: _emailCtrl.text,
    password: _passwordCtrl.text,
    firstName: _firstNameCtrl.text,
    lastName: _lastNameCtrl.text,
  ));

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = AppTheme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_vm, ..._commands]),
      builder: (context, child) {
        final loading = _vm.busy;
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand block — triple-tap to open debug log viewer
                          Center(
                            child: GestureDetector(
                              onLongPress: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TalkerScreen(talker: log),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/icon/icon.png',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            t.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Form fields — no card chrome
                          if (_vm.isSignUp) ...[
                            _FilledField(
                              controller: _firstNameCtrl,
                              label: t.firstName,
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _FilledField(
                              controller: _lastNameCtrl,
                              label: t.lastName,
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _FilledField(
                            controller: _emailCtrl,
                            label: t.email,
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _FilledField(
                            controller: _passwordCtrl,
                            label: t.password,
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? t.showPassword
                                  : t.hidePassword,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: colors.mutedForeground,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Primary CTA
                          _TallButton(
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
                                : Text(
                                    _vm.isSignUp ? t.createAccount : t.signIn,
                                  ),
                          ),
                          const SizedBox(height: 10),

                          // OAuth buttons — tight stack, no divider
                          if (_vm.telegramWaiting)
                            _TelegramWaiting(
                              onOpen: loading
                                  ? null
                                  : _vm.signInWithTelegram.execute,
                              onCancel: _vm.cancelTelegram,
                            )
                          else
                            _OAuthButton(
                              onPressed: loading
                                  ? null
                                  : _vm.signInWithTelegram.execute,
                              icon: const _TelegramIcon(),
                              label: t.continueWithTelegram,
                            ),
                          if (_vm.appleAvailable) ...[
                            const SizedBox(height: 10),
                            _OAuthButton(
                              onPressed: loading
                                  ? null
                                  : _vm.signInWithApple.execute,
                              icon: Icon(
                                Icons.apple,
                                size: 22,
                                color: colors.foreground,
                              ),
                              label: t.continueWithApple,
                            ),
                          ],

                          if (_vm.isSignUp) ...[
                            const SizedBox(height: 16),
                            _TermsLine(
                              onTerms: _vm.openTerms,
                              onPrivacy: _vm.openPrivacyPolicy,
                            ),
                          ],

                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _vm.toggleMode,
                              child: Text(
                                _vm.isSignUp
                                    ? t.alreadyHaveAccount
                                    : t.dontHaveAccount,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_vm.forInvite)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _vm.backToInvite,
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: _LanguagePill(viewModel: _vm),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Filled, borderless input ───────────────────────────────────────────────

class _FilledField extends StatelessWidget {
  const _FilledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: colors.foreground),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: colors.mutedForeground),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Unified 52px button shells ─────────────────────────────────────────────

class _TallButton extends StatelessWidget {
  const _TallButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: child,
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.foreground,
          backgroundColor: colors.muted,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// In place of the Telegram button while the driver confirms in Telegram:
/// they may come back without confirming (declined, or just looked around).
class _TelegramWaiting extends StatelessWidget {
  const _TelegramWaiting({required this.onOpen, required this.onCancel});

  final VoidCallback? onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _TelegramIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.telegramWaitingTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.telegramWaitingBody,
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: Text(t.cancel)),
              TextButton(onPressed: onOpen, child: Text(t.telegramOpenAgain)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Language pill (top-right) ──────────────────────────────────────────────

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.viewModel});

  final LoginViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return PopupMenuButton<Locale>(
      tooltip: context.l10n.language,
      initialValue: viewModel.locale,
      onSelected: viewModel.setLocale,
      color: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => viewModel.locales
          .map(
            (locale) => PopupMenuItem<Locale>(
              value: locale,
              child: Row(
                children: [
                  Text(
                    locale.languageCode.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    viewModel.nameOf(locale),
                    style: TextStyle(color: colors.foreground),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.muted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              viewModel.locale.languageCode.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: colors.foreground,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Terms & privacy line ────────────────────────────────────────────────────

class _TermsLine extends StatelessWidget {
  const _TermsLine({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = AppTheme.of(context);
    final linkStyle = TextStyle(
      color: colors.primary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: colors.mutedForeground,
          ),
          children: [
            TextSpan(text: '${t.byCreatingAccount} '),
            TextSpan(
              text: t.termsOfService,
              style: linkStyle,
              recognizer: TapGestureRecognizer()..onTap = onTerms,
            ),
            TextSpan(text: ' ${t.and} '),
            TextSpan(
              text: t.privacyPolicy,
              style: linkStyle,
              recognizer: TapGestureRecognizer()..onTap = onPrivacy,
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Telegram icon ──────────────────────────────────────────────────────────

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _TelegramPainter()),
    );
  }
}

class _TelegramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF2AABEE)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      bgPaint,
    );

    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.48)
      ..lineTo(size.width * 0.83, size.height * 0.27)
      ..lineTo(size.width * 0.54, size.height * 0.73)
      ..lineTo(size.width * 0.41, size.height * 0.59)
      ..close();
    canvas.drawPath(path, arrowPaint);

    final tailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final tail = Path()
      ..moveTo(size.width * 0.41, size.height * 0.59)
      ..lineTo(size.width * 0.54, size.height * 0.73)
      ..lineTo(size.width * 0.54, size.height * 0.57)
      ..close();
    canvas.drawPath(tail, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
