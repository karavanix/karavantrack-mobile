import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Prominent in-app disclosure shown before the OS "Allow all the time"
/// location prompt, satisfying Google Play's Prominent Disclosure & Consent
/// Requirement for the BACKGROUND_LOCATION permission: the user must see,
/// inside the app, what is collected and why, and explicitly consent, before
/// the system permission dialog appears.
///
/// Returns `true` only if the user tapped "Allow" — the caller should then
/// proceed to request the OS permission. Returns `false` on "Not Now" (the
/// dialog cannot be dismissed by tapping outside or the back button, so this
/// is always a deliberate choice).
class LocationDisclosureDialog {
  LocationDisclosureDialog._();

  static final _privacyUri = Uri.parse('https://app.yool.live/privacy-policy');

  static Future<bool> show(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(t.tr('locationDisclosureTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.tr('locationDisclosureBody')),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${t.tr('locationDisclosurePrivacyPrefix')} '),
                      TextSpan(
                        text: t.tr('privacyPolicy'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              launchUrl(_privacyUri, mode: LaunchMode.externalApplication),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.tr('locationDisclosureDecline')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.tr('locationDisclosureAllow')),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
