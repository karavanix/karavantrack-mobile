import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../services/debug_service.dart';
import '../services/telegram_auth_service.dart';

/// Login screen with email/password. Toggles to register mode.
/// OAuth buttons (Telegram + Apple) appear in both login and register modes.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showError(t.tr('enterEmailAndPassword'));
      return;
    }

    String? error;
    if (_isRegister) {
      error = await widget.store.register(
        email: email,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        password: password,
        role: 'carrier',
      );
    } else {
      error = await widget.store.login(email: email, password: password);
    }

    if (error != null && mounted) _showError(error);
  }

  Future<void> _appleSignIn() async {
    final error = await widget.store.appleSignIn();
    if (error != null && mounted) _showError(error);
  }

  Future<void> _telegramSignIn() async {
    final log = DebugService.talker;
    log.info('[TG][ui] "Continue with Telegram" tapped');
    try {
      await TelegramAuthService.startAuth();
      // Auth completes asynchronously via MethodChannel → store.telegramSignInWithCode.
    } catch (e, st) {
      log.error('[TG][ui] startAuth() threw', e, st);
      if (mounted) _showError('Telegram Sign In failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
        final loading = widget.store.isLoading;
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
                                  MaterialPageRoute(
                                    builder: (_) => TalkerScreen(
                                      talker: DebugService.talker,
                                    ),
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
                            t.tr('appName'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.tr('tagline'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Form fields — no card chrome
                          if (_isRegister) ...[
                            _FilledField(
                              controller: _firstNameCtrl,
                              label: t.tr('firstName'),
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _FilledField(
                              controller: _lastNameCtrl,
                              label: t.tr('lastName'),
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _FilledField(
                            controller: _emailCtrl,
                            label: t.tr('email'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _FilledField(
                            controller: _passwordCtrl,
                            label: t.tr('password'),
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? t.tr('showPassword')
                                  : t.tr('hidePassword'),
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
                                    _isRegister
                                        ? t.tr('createAccount')
                                        : t.tr('signIn'),
                                  ),
                          ),
                          const SizedBox(height: 10),

                          // OAuth buttons — tight stack, no divider
                          _OAuthButton(
                            onPressed: loading ? null : _telegramSignIn,
                            icon: const _TelegramIcon(),
                            label: t.tr('continueWithTelegram'),
                          ),
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 10),
                            _OAuthButton(
                              onPressed: loading ? null : _appleSignIn,
                              icon: Icon(
                                Icons.apple,
                                size: 22,
                                color: colors.foreground,
                              ),
                              label: t.tr('continueWithApple'),
                            ),
                          ],

                          if (_isRegister) ...[
                            const SizedBox(height: 16),
                            _TermsLine(),
                          ],

                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(
                                () => _isRegister = !_isRegister,
                              ),
                              child: Text(
                                _isRegister
                                    ? t.tr('alreadyHaveAccount')
                                    : t.tr('dontHaveAccount'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: _LanguagePill(store: widget.store),
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Language pill (top-right) ──────────────────────────────────────────────

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return PopupMenuButton<String>(
      tooltip: AppLocalizations.of(context).tr('language'),
      initialValue: store.locale,
      onSelected: (code) => store.setLocale(code),
      color: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => AppLocalizations.supportedLocales
          .map(
            (code) => PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.languageNames[code]!,
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
              store.locale.toUpperCase(),
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
  static final _privacyUri = Uri.parse('https://app.yool.live/privacy-policy');
  static final _termsUri = Uri.parse('https://app.yool.live/terms-of-service');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
            TextSpan(text: '${t.tr('byCreatingAccount')} '),
            TextSpan(
              text: t.tr('termsOfService'),
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(_termsUri, mode: LaunchMode.externalApplication),
            ),
            TextSpan(text: ' ${t.tr('and')} '),
            TextSpan(
              text: t.tr('privacyPolicy'),
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => launchUrl(_privacyUri, mode: LaunchMode.externalApplication),
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
