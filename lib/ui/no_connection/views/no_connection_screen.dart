import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/app_theme.dart';
import '../view_models/no_connection_view_model.dart';

class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({super.key, required this.viewModel});

  final NoConnectionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = AppTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel.retry, viewModel.signOut]),
      builder: (context, _) {
        final busy = viewModel.retry.running || viewModel.signOut.running;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.errorNetwork,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: colors.foreground),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: busy ? null : viewModel.retry.execute,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(t.tryAgain),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : viewModel.signOut.execute,
                      child: Text(t.signOut),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
