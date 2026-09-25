import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../l10n/app_localizations.dart';
import 'floating_dock.dart';

/// Which condition is currently blocking the Loads screen. Ordered by
/// priority when more than one applies at once (quickest to fix first) —
/// callers should pick the first one that's true rather than showing all.
enum BlockedReason {
  /// Device location services are off entirely — a single system toggle.
  gpsOff,

  /// Missing "Allow all the time" — background tracking can't run at all.
  alwaysPermission,

  /// Precise (vs. approximate/reduced) accuracy wasn't granted. Fixes still
  /// arrive, just fuzzed to ~1-3km, which silently corrupts the track rather
  /// than visibly breaking it — so this is checked and surfaced explicitly.
  preciseLocation,
}

/// Frosted blocking overlay shown over the Loads content while location
/// tracking can't work correctly: GPS is off, "Allow all the time" is
/// missing, or only approximate location accuracy was granted.
///
/// Rendered inside the Loads screen's body `Stack`, so it covers the load list
/// while leaving the screen's AppBar (above) and the shell's bottom dock
/// (painted on top of the body) fully interactive — the user can switch tabs.
class LoadsBlockedOverlay extends StatelessWidget {
  const LoadsBlockedOverlay({super.key, required this.reason});

  final BlockedReason reason;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
                  child: switch (reason) {
                    BlockedReason.gpsOff => _GpsOffContent(t: t, theme: theme),
                    BlockedReason.alwaysPermission => _PermissionContent(
                      t: t,
                      theme: theme,
                    ),
                    BlockedReason.preciseLocation => _PreciseLocationContent(
                      t: t,
                      theme: theme,
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
  const _GpsOffContent({required this.t, required this.theme});

  final AppLocalizations t;
  final ThemeData theme;

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
          t.tr('gpsOffTitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.tr('gpsOffMessage'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.location_on),
            label: Text(t.tr('turnOnGps')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Geolocator.openLocationSettings(),
          ),
        ),
      ],
    );
  }
}

class _PermissionContent extends StatelessWidget {
  const _PermissionContent({required this.t, required this.theme});

  final AppLocalizations t;
  final ThemeData theme;

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
          t.tr('alwaysLocationTitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.tr('alwaysLocationMessage'),
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
                text: t.tr(
                  Platform.isIOS
                      ? 'alwaysLocationIosStep1'
                      : 'alwaysLocationStep1',
                ),
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '2',
                text: t.tr(
                  Platform.isIOS
                      ? 'alwaysLocationIosStep2'
                      : 'alwaysLocationStep2',
                ),
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '3',
                text: t.tr(
                  Platform.isIOS
                      ? 'alwaysLocationIosStep3'
                      : 'alwaysLocationStep3',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(t.tr('openAppSettings')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => permission_handler.openAppSettings(),
          ),
        ),
      ],
    );
  }
}

class _PreciseLocationContent extends StatelessWidget {
  const _PreciseLocationContent({required this.t, required this.theme});

  final AppLocalizations t;
  final ThemeData theme;

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
          t.tr('preciseLocationTitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.tr('preciseLocationMessage'),
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
                text: t.tr(
                  Platform.isIOS
                      ? 'preciseLocationIosStep1'
                      : 'preciseLocationStep1',
                ),
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '2',
                text: t.tr(
                  Platform.isIOS
                      ? 'preciseLocationIosStep2'
                      : 'preciseLocationStep2',
                ),
              ),
              const SizedBox(height: 6),
              _InstructionStep(
                number: '3',
                text: t.tr(
                  Platform.isIOS
                      ? 'preciseLocationIosStep3'
                      : 'preciseLocationStep3',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(t.tr('openAppSettings')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => permission_handler.openAppSettings(),
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
