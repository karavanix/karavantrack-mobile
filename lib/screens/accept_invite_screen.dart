import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';

/// Landing screen for a driver-invite-by-link
/// (`https://app.yool.live/invite/{token}` / `yoollive://invite/{token}`).
///
/// Fetches the public invite summary via `GET /invites/{token}` and shows the
/// offered load with an Accept button. If the driver is not logged in yet,
/// the same Accept button walks them through login/registration first (shown
/// as a plain in-place swap to [LoginScreen] rather than a `Navigator.push` —
/// this screen is reached via [AppStore.pendingInviteToken], which app.dart's
/// `_HomeRouter` renders directly as its `home:` content, same as
/// [LoginScreen]/[VerifyEmailScreen] themselves; swapping in place lets
/// `_HomeRouter`'s own pendingVerificationEmail branch keep working
/// transparently underneath if registration requires OTP verification,
/// without a second Navigator route sitting on top hiding it).
class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({super.key, required this.store, required this.token});

  final AppStore store;
  final String token;

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  bool _loading = true;
  bool _accepting = false;
  bool _wantsLogin = false;
  Map<String, dynamic>? _invite;

  @override
  void initState() {
    super.initState();
    _fetchInvite();
  }

  Future<void> _fetchInvite() async {
    setState(() => _loading = true);
    Map<String, dynamic>? result;
    try {
      result = await ApiService.instance.getInvite(widget.token);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    setState(() {
      _invite = result;
      _loading = false;
    });
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _dismiss() {
    // pendingInviteToken clears → _HomeRouter re-evaluates and routes to the
    // normal logged-in/logged-out flow on its own.
    widget.store.clearPendingInvite();
  }

  Future<void> _handleAccept() async {
    if (!widget.store.isLoggedIn) {
      setState(() => _wantsLogin = true);
      return;
    }
    final t = AppLocalizations.of(context);
    setState(() => _accepting = true);
    final result = await widget.store.acceptInvite(widget.token);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (result['success'] != true) {
      _showError(result['message'] as String? ?? t.tr('inviteAcceptError'));
      // The invite state may have changed underneath us (e.g. a 409 race
      // with someone else accepting it) — re-fetch to show the right status.
      _fetchInvite();
    }
    // On success, store.acceptInvite() already cleared pendingInviteToken and
    // replicated acceptLoad's refresh/background-tracking side effects;
    // _HomeRouter will move on to MainShell on its next rebuild automatically.
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (_loading) {
          return Scaffold(
            appBar: AppBar(title: Text(t.tr('invite'))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final invite = _invite;
        if (invite == null) {
          return _MessageScreen(
            title: t.tr('invite'),
            message: t.tr('inviteNotFound'),
            onRetry: _fetchInvite,
            onDismiss: _dismiss,
          );
        }

        final status = invite['status'] as String? ?? 'pending';
        if (status != 'pending') {
          final messageKey = switch (status) {
            'accepted' => 'inviteStatusAccepted',
            'expired' => 'inviteStatusExpired',
            'revoked' => 'inviteStatusRevoked',
            _ => 'inviteNotFound',
          };
          return _MessageScreen(
            title: t.tr('invite'),
            message: t.tr(messageKey),
            onDismiss: _dismiss,
          );
        }

        if (!widget.store.isLoggedIn && _wantsLogin) {
          return LoginScreen(store: widget.store);
        }

        return _buildOfferScreen(context, t, invite);
      },
    );
  }

  Widget _buildOfferScreen(
    BuildContext context,
    AppLocalizations t,
    Map<String, dynamic> invite,
  ) {
    final theme = Theme.of(context);
    final colors = AppTheme.of(context);
    final load = invite['load'] as Map<String, dynamic>? ?? const {};

    final title = load['title'] as String? ?? '';
    final referenceId = load['reference_id'] as String?;
    final pickupAddress = load['pickup_address'] as String? ?? '';
    final dropoffAddress = load['dropoff_address'] as String? ?? '';
    final pickupAt = DateTime.tryParse(load['pickup_at'] as String? ?? '');
    final dropoffAt = DateTime.tryParse(load['dropoff_at'] as String? ?? '');
    final companyName = load['company_name'] as String? ?? '';

    final isLoggedIn = widget.store.isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: Text(t.tr('invite'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.tr('inviteLoadOffer'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title.isNotEmpty ? title : t.tr('load'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (referenceId != null && referenceId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      referenceId,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tr('details'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (companyName.isNotEmpty)
                    InfoRow(label: t.tr('inviteCompany'), value: companyName),
                  InfoRow(label: t.tr('pickup'), value: pickupAddress),
                  InfoRow(label: t.tr('dropoff'), value: dropoffAddress),
                  if (pickupAt != null)
                    InfoRow(label: t.tr('pickupTime'), value: formatDateTime(pickupAt)),
                  if (dropoffAt != null)
                    InfoRow(label: t.tr('dropoffTime'), value: formatDateTime(dropoffAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: _accepting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleAccept,
                    child: Text(isLoggedIn ? t.tr('acceptLoad') : t.tr('inviteLoginAndAccept')),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Simple full-screen status message (not-found / already-accepted / expired
/// / revoked / network-error) with an optional retry and a dismiss action
/// that hands routing back to `_HomeRouter`.
class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.title,
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              if (onRetry != null) ...[
                ElevatedButton(onPressed: onRetry, child: Text(t.tr('tryAgain'))),
                const SizedBox(height: 8),
              ],
              TextButton(onPressed: onDismiss, child: Text(t.tr('inviteGoToApp'))),
            ],
          ),
        ),
      ),
    );
  }
}
