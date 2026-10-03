import 'package:material_ui/material_ui.dart';

import '../../../domain/models/invite.dart';
import '../../../utils/formatters.dart';
import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/themes/app_theme.dart';
import '../../core/ui/info_row.dart';
import '../view_models/invite_view_model.dart';

/// Landing screen for a driver-invite-by-link
/// (`https://app.yool.live/invite/{token}` / `yoollive://invite/{token}`):
/// the offered load with an Accept button. Signed out, the button leads
/// through sign-in first and the load is accepted on return.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.viewModel});

  final InviteViewModel viewModel;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  InviteViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.accept.addListener(_onAcceptChanged);
  }

  @override
  void dispose() {
    _vm.accept.removeListener(_onAcceptChanged);
    super.dispose();
  }

  void _onAcceptChanged() {
    if (_vm.accept.result case Error(:final error)) {
      _vm.accept.clearResult();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(context.l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.accept]),
      builder: (context, _) {
        if (_vm.autoAccepting) return _spinner(t);
        return switch (_vm.state) {
          InviteLoading() => _spinner(t),
          InviteNotFound() => _MessageScreen(
            title: t.invite,
            message: t.inviteNotFound,
            onDismiss: _vm.dismiss,
          ),
          InviteFailed() => _MessageScreen(
            title: t.invite,
            message: t.inviteLoadError,
            onRetry: _vm.load.execute,
            onDismiss: _vm.dismiss,
          ),
          InviteBlockedByActiveLoad() => _MessageScreen(
            title: t.invite,
            message: t.inviteCarrierHasActiveLoad,
            onDismiss: _vm.dismiss,
          ),
          InviteReady(:final invite) => switch (invite.status) {
            InviteStatus.pending => _buildOfferScreen(context, t, invite),
            final status => _MessageScreen(
              title: t.invite,
              message: switch (status) {
                InviteStatus.accepted => t.inviteStatusAccepted,
                InviteStatus.expired => t.inviteStatusExpired,
                InviteStatus.revoked => t.inviteStatusRevoked,
                _ => t.inviteNotFound,
              },
              onDismiss: _vm.dismiss,
            ),
          },
        };
      },
    );
  }

  Widget _spinner(AppLocalizations t) => Scaffold(
    appBar: AppBar(title: Text(t.invite)),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildOfferScreen(
    BuildContext context,
    AppLocalizations t,
    Invite invite,
  ) {
    final theme = Theme.of(context);
    final colors = AppTheme.of(context);
    final load = invite.load;

    final title = load.title;
    final referenceId = load.referenceId;
    final pickupAddress = load.pickupAddress;
    final dropoffAddress = load.dropoffAddress;
    final pickupAt = load.pickupAt;
    final dropoffAt = load.dropoffAt;
    final companyName = load.companyName;

    final isLoggedIn = _vm.signedIn;

    return Scaffold(
      appBar: AppBar(title: Text(t.invite)),
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
                      Icon(
                        Icons.local_shipping_outlined,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.inviteLoadOffer,
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
                    title.isNotEmpty ? title : t.load,
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
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
                    t.details,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (companyName.isNotEmpty)
                    InfoRow(label: t.inviteCompany, value: companyName),
                  InfoRow(label: t.pickup, value: pickupAddress),
                  InfoRow(label: t.dropoff, value: dropoffAddress),
                  if (pickupAt != null)
                    InfoRow(
                      label: t.pickupTime,
                      value: formatDateTime(pickupAt),
                    ),
                  if (dropoffAt != null)
                    InfoRow(
                      label: t.dropoffTime,
                      value: formatDateTime(dropoffAt),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: _vm.accept.running
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _vm.accept.execute,
                    child: Text(
                      isLoggedIn ? t.acceptLoad : t.inviteLoginAndAccept,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Simple full-screen status message (not-found / already-accepted / expired
/// / revoked / network-error) with an optional retry and a dismiss action
/// that drops the invite (the router then goes on to the app).
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
    final t = context.l10n;
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
                ElevatedButton(onPressed: onRetry, child: Text(t.tryAgain)),
                const SizedBox(height: 8),
              ],
              TextButton(onPressed: onDismiss, child: Text(t.inviteGoToApp)),
            ],
          ),
        ),
      ),
    );
  }
}
