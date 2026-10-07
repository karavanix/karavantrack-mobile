import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/location_state.dart';
import '../../core/l10n/l10n.dart';
import 'settings_mockup.dart';

/// What to pick in the phone's settings to fix [LocationProblem], with the
/// way there: opened only when the driver taps the blocking overlay's
/// button, and "Later" always closes it. Apple rejects sending the driver
/// to the settings on its own after "Don't Allow" (5.1.1(iv), 06.10.2026).
class LocationSettingsSheet extends StatelessWidget {
  const LocationSettingsSheet._({
    required this.problem,
    required this.onOpenSettings,
  });

  final LocationProblem problem;
  final VoidCallback onOpenSettings;

  /// [onOpenSettings] opens the settings page that fixes [problem]; the
  /// sheet is closed first.
  static Future<void> show(
    BuildContext context, {
    required LocationProblem problem,
    required VoidCallback onOpenSettings,
  }) => showModalBottomSheet<void>(
    context: context,
    // Over the shell's dock too.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LocationSettingsSheet._(
      problem: problem,
      onOpenSettings: onOpenSettings,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    // The last step is a picture of the settings page: the option to pick,
    // ringed, instead of its name in words.
    final (title, message, steps, picture) = switch (problem) {
      // No app may open Location Services on iOS, only its own page in
      // Settings: the way from there is spelled out. Android opens the
      // location toggle itself.
      LocationProblem.gpsOff => (
        t.gpsOffSheetTitle,
        ios ? t.gpsOffIosMessage : t.gpsOffMessage,
        ios
            ? [t.gpsOffIosStep1, t.gpsOffIosStep2, t.gpsOffIosStep3]
            : <String>[],
        ios ? const LocationServicesMockup() : null,
      ),
      LocationProblem.noAlwaysAccess => (
        ios ? t.alwaysSheetTitleIos : t.alwaysSheetTitle,
        t.alwaysSheetMessage,
        ios
            ? [t.alwaysLocationIosStep1, t.alwaysLocationIosStep2]
            : [t.alwaysLocationStep1, t.alwaysLocationStep2],
        const LocationSettingsMockup(focus: SettingsFocus.always),
      ),
      LocationProblem.notPrecise => (
        ios ? t.preciseSheetTitleIos : t.preciseSheetTitle,
        t.preciseSheetMessage,
        ios
            ? [t.preciseLocationIosStep1, t.preciseLocationIosStep2]
            : [t.preciseLocationStep1, t.preciseLocationStep2],
        const LocationSettingsMockup(focus: SettingsFocus.precise),
      ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    if (picture != null) ...[
                      const SizedBox(height: 12),
                      picture,
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(t.openAppSettings),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onOpenSettings();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.later),
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
