import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../l10n/app_localizations.dart';

/// Service that enforces "Allow all the time" (Always) location permission
/// on Android. If the user has only "While in use" or less, a blocking
/// non-dismissible dialog is shown directing them to the app's location
/// permission settings page.
class LocationPermissionService {
  LocationPermissionService._();

  /// Returns `true` when the user has granted "Allow all the time" location
  /// permission, which is required for background / killed-state tracking.
  static Future<bool> isAlwaysGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Checks the current location permission level. If it is not "always",
  /// shows a blocking dialog that directs the user to the app's settings.
  ///
  /// The dialog is non-dismissible — the user *must* grant "Allow all the
  /// time" before they can proceed. The method re-checks automatically when
  /// the app is resumed (user returns from settings).
  ///
  /// Returns `true` once the permission is granted.
  static Future<bool> enforceAlwaysPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) return true;

    // If denied entirely, try requesting basic permission first
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.always) return true;
    }

    // At this point user has "while in use" or denied — show blocking dialog
    if (context.mounted) {
      await _showAlwaysPermissionDialog(context);
    }

    return await isAlwaysGranted();
  }

  /// Shows a non-dismissible full-screen dialog that explains why "Always"
  /// location is required and provides a button to open app settings.
  /// Automatically dismisses when the permission is granted upon resume.
  static Future<void> _showAlwaysPermissionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AlwaysPermissionDialog();
      },
    );
  }
}

/// Stateful dialog widget that re-checks permission on app lifecycle resume.
class _AlwaysPermissionDialog extends StatefulWidget {
  @override
  State<_AlwaysPermissionDialog> createState() =>
      _AlwaysPermissionDialogState();
}

class _AlwaysPermissionDialogState extends State<_AlwaysPermissionDialog>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from settings, re-check permission
    if (state == AppLifecycleState.resumed) {
      _recheckPermission();
    }
  }

  Future<void> _recheckPermission() async {
    if (_checking) return;
    _checking = true;

    final granted = await LocationPermissionService.isAlwaysGranted();
    if (granted && mounted) {
      Navigator.of(context).pop();
    }

    _checking = false;
  }

  Future<void> _openAppSettings() async {
    // Opens the app's specific permission settings page where the user
    // can select "Allow all the time".
    await permission_handler.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      // Prevent back-button dismissal
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
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
        title: Text(
          t.tr('alwaysLocationTitle'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                color: theme.colorScheme.surfaceContainerHighest
                    .withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InstructionStep(
                    number: '1',
                    text: t.tr('alwaysLocationStep1'),
                  ),
                  const SizedBox(height: 6),
                  _InstructionStep(
                    number: '2',
                    text: t.tr('alwaysLocationStep2'),
                  ),
                  const SizedBox(height: 6),
                  _InstructionStep(
                    number: '3',
                    text: t.tr('alwaysLocationStep3'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
              onPressed: _openAppSettings,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small widget for numbered instruction steps in the dialog.
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
