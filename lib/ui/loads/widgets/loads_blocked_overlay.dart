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
            child: SingleChildScrollView(
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: switch (problem) {
                    LocationProblem.gpsOff => _GpsOffContent(
                      t: t,
                      theme: theme,
                      onOpenSettings: onOpenLocationSettings,
                    ),
                    LocationProblem.noAlwaysAccess => _PermissionContent(
                      t: t,
                      theme: theme,
                      onOpenSettings: onOpenAppSettings,
                    ),
                    LocationProblem.notPrecise => _PreciseLocationContent(
                      t: t,
                      theme: theme,
                      onOpenSettings: onOpenAppSettings,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsOffContent extends StatelessWidget {
  const _GpsOffContent({
    required this.t,
    required this.theme,
    required this.onOpenSettings,
  });

  final AppLocalizations t;
  final ThemeData theme;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.gps_off_rounded,
            size: 48,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.gpsOffTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Platform.isIOS ? t.gpsOffIosMessage : t.gpsOffMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
            height: 1.5,
          ),
        ),
        // No app may open Location Services on iOS, only its own page in
        // Settings: the way from there is spelled out.
        if (Platform.isIOS) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InstructionStep(number: '1', text: t.gpsOffIosStep1),
                const SizedBox(height: 6),
                _InstructionStep(number: '2', text: t.gpsOffIosStep2),
                const SizedBox(height: 6),
                _InstructionStep(number: '3', text: t.gpsOffIosStep3),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Platform.isIOS ? Icons.settings : Icons.location_on),
            label: Text(Platform.isIOS ? t.openAppSettings : t.turnOnGps),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _PermissionContent extends StatelessWidget {
  const _PermissionContent({
    required this.t,
    required this.theme,
    required this.onOpenSettings,
  });

  final AppLocalizations t;
  final ThemeData theme;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_off_rounded,
            size: 48,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.alwaysLocationTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          Platform.isIOS ? t.alwaysLocationIosMessage : t.alwaysLocationMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        // Step-by-step instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InstructionStep(
                number: '1',
                text: Platform.isIOS
                    ? t.alwaysLocationIosStep1
                    : t.alwaysLocationStep1,
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '2',
                text: Platform.isIOS
                    ? t.alwaysLocationIosStep2
                    : t.alwaysLocationStep2,
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '3',
                text: Platform.isIOS
                    ? t.alwaysLocationIosStep3
                    : t.alwaysLocationStep3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(t.openAppSettings),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _PreciseLocationContent extends StatelessWidget {
  const _PreciseLocationContent({
    required this.t,
    required this.theme,
    required this.onOpenSettings,
  });

  final AppLocalizations t;
  final ThemeData theme;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_searching_rounded,
            size: 48,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t.preciseLocationTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.preciseLocationMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        // Step-by-step instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InstructionStep(
                number: '1',
                text: Platform.isIOS
                    ? t.preciseLocationIosStep1
                    : t.preciseLocationStep1,
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '2',
                text: Platform.isIOS
                    ? t.preciseLocationIosStep2
                    : t.preciseLocationStep2,
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '3',
                text: Platform.isIOS
                    ? t.preciseLocationIosStep3
                    : t.preciseLocationStep3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(t.openAppSettings),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenSettings,
          ),
        ),
      ],
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
