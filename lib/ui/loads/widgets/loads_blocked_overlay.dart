import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../domain/models/location_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/ui/floating_dock.dart';
import 'location_settings_sheet.dart';

/// Frosted blocking overlay shown over the Loads content while location
/// tracking can't work correctly: GPS is off, "Allow all the time" is
/// missing, or only approximate location accuracy was granted.
///
/// It says why tracking matters to the driver, not what the app needs, and
/// its button only opens [LocationSettingsSheet] with the way to fix it:
/// the driver goes to the settings from there or picks "Later".
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

    void showSheet() => LocationSettingsSheet.show(
      context,
      problem: problem,
      onOpenSettings: problem == LocationProblem.gpsOff
          ? onOpenLocationSettings
          : onOpenAppSettings,
    );

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
                message: t.gpsOffCardMessage,
                buttonIcon: Icons.location_on,
                buttonLabel: t.turnOnGps,
                onPressed: showSheet,
              ),
              LocationProblem.noAlwaysAccess => _ProblemCard(
                icon: Icons.location_off_rounded,
                title: t.locationCardTitle,
                message: t.locationCardMessage,
                buttonIcon: Icons.location_on,
                buttonLabel: t.locationCardButton,
                onPressed: showSheet,
              ),
              LocationProblem.notPrecise => _ProblemCard(
                icon: Icons.location_searching_rounded,
                title: t.preciseCardTitle,
                message: t.preciseCardMessage,
                buttonIcon: Icons.my_location,
                buttonLabel: t.preciseCardButton,
                onPressed: showSheet,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// What's wrong and the button that starts the fix. The button stays in sight: on a short screen the text above it
/// scrolls instead (Honor, 04.10: it was below the fold).
class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonIcon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
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
