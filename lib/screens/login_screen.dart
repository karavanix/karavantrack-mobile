import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';
import '../widgets/telegram_auth_webview.dart';

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

  Future<void> _openTelegramWebView() async {
    Map<String, String>? authData;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TelegramAuthWebView(
          widgetUrl:
              'https://api.yool.live/api/v1/auth/telegram/widget?role=carrier',
          onAuthData: (data) {
            authData = data;
          },
        ),
      ),
    );

    if (authData != null && mounted) {
      final error = await widget.store.telegramSignIn(authData!);
      if (error != null && mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
        final loading = widget.store.isLoading;
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
                      // Logo
                      Icon(
                        Icons.local_shipping_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.tr('appName'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegister
                            ? t.tr('createAccount')
                            : t.tr('signIn'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card with email/password form
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isRegister) ...[
                                TextField(
                                  controller: _firstNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.tr('firstName'),
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _lastNameCtrl,
                                  decoration: InputDecoration(
                                    labelText: t.tr('lastName'),
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: t.tr('email'),
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordCtrl,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: t.tr('password'),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
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
                                      : Text(
                                          _isRegister
                                              ? t.tr('createAccount')
                                              : t.tr('signIn'),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(
                                  () => _isRegister = !_isRegister,
                                ),
                                child: Text(
                                  _isRegister
                                      ? t.tr('alreadyHaveAccount')
                                      : t.tr('dontHaveAccount'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ─── OAuth section (both login & register modes) ───
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              t.tr('orContinueWith'),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _OAuthButton(
                        onPressed: loading ? null : _openTelegramWebView,
                        icon: const _TelegramIcon(),
                        label: t.tr('continueWithTelegram'),
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 10),
                        _OAuthButton(
                          onPressed: loading ? null : _appleSignIn,
                          icon: const Icon(Icons.apple, size: 20),
                          label: t.tr('continueWithApple'),
                        ),
                      ],
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

// ─── Helper widgets ──────────────────────────────────────────────────────────

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
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
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
