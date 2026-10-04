import 'dart:io';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../domain/models/location_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/floating_dock.dart';

/// Frosted blocking overlay shown over the Loads content while location
/// tracking can't work correctly: GPS is off, "Allow all the time" is
/// missing, or only approximate location accuracy was granted.
///
/// Rendered inside the Loads screen's body `Stack`, so it covers the load list
/// while leaving the screen's AppBar (above) and the shell's bottom dock
/// (painted on top of the body) fully interactive — the user can switch tabs.
class LoadsBlockedOverlay extends StatelessWidget {
  const LoadsBlockedOverlay({
    super.key,
    required this.problem,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final LocationProblem problem;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final ios = Platform.isIOS;

    return Positioned.fill(
      // Absorb taps so the obscured Loads content stays non-interactive.
      child: GestureDetector(
        onTap: () {},
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: theme.colorScheme.surface.withAlpha(140),
            alignment: Alignment.center,
            padding: EdgeInsets.fromLTRB(24, 24, 24, dockClearance(context)),
            child: switch (problem) {
              LocationProblem.gpsOff => _ProblemCard(
                icon: Icons.gps_off_rounded,
                title: t.gpsOffTitle,
                message: ios ? t.gpsOffIosMessage : t.gpsOffMessage,
                // No app may open Location Services on iOS, only its own
                // page in Settings: the way from there is spelled out.
                steps: ios
                    ? [t.gpsOffIosStep1, t.gpsOffIosStep2, t.gpsOffIosStep3]
                    : const [],
                buttonIcon: ios ? Icons.settings : Icons.location_on,
                buttonLabel: ios ? t.openAppSettings : t.turnOnGps,
                onPressed: onOpenLocationSettings,
              ),
              LocationProblem.noAlwaysAccess => _ProblemCard(
                icon: Icons.location_off_rounded,
                title: t.alwaysLocationTitle,
                message: ios
                    ? t.alwaysLocationIosMessage
                    : t.alwaysLocationMessage,
                steps: ios
                    ? [
                        t.alwaysLocationIosStep1,
                        t.alwaysLocationIosStep2,
                        t.alwaysLocationIosStep3,
                      ]
                    : [
                        t.alwaysLocationStep1,
                        t.alwaysLocationStep2,
                        t.alwaysLocationStep3,
                      ],
                buttonIcon: Icons.settings,
                buttonLabel: t.openAppSettings,
                onPressed: onOpenAppSettings,
              ),
              LocationProblem.notPrecise => _ProblemCard(
                icon: Icons.location_searching_rounded,
                title: t.preciseLocationTitle,
                message: t.preciseLocationMessage,
                steps: ios
                    ? [
                        t.preciseLocationIosStep1,
                        t.preciseLocationIosStep2,
                        t.preciseLocationIosStep3,
                      ]
                    : [
                        t.preciseLocationStep1,
                        t.preciseLocationStep2,
                        t.preciseLocationStep3,
                      ],
                buttonIcon: Icons.settings,
                buttonLabel: t.openAppSettings,
                onPressed: onOpenAppSettings,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// What's wrong, numbered steps to fix it, and the button that starts the
/// fix. The button stays in sight: on a short screen the text above it
/// scrolls instead (Honor, 04.10: it was below the fold).
class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.steps,
    required this.buttonIcon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<String> steps;
  final IconData buttonIcon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 40, color: Colors.orange),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(
                          180,
                        ),
                        height: 1.5,
                      ),
                    ),
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(80),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (i, step) in steps.indexed) ...[
                              if (i > 0) const SizedBox(height: 6),
                              _InstructionStep(number: '${i + 1}', text: step),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(buttonIcon),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small widget for numbered instruction steps.
class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}
