import 'package:flutter/widgets.dart';

import '../../../data/services/local_store.dart';
import '../../../data/services/tracking/tracking_config.dart';
import 'l10n.dart';

/// The tracking library's own texts in the app's language. Read from the
/// device rather than a BuildContext: the library is configured before the
/// first frame, and also when the app runs with no UI at all.
TrackingTexts trackingTexts(LocalStore store) {
  final t = lookupAppLocalizations(
    Locale(store.getString(StoreKeys.locale) ?? 'en'),
  );
  return TrackingTexts(
    notificationTitle: t.trackingNotificationTitle,
    notificationText: t.trackingNotificationText,
    rationaleTitle: t.trackingRationaleTitle,
    // The library puts in the system's wording of "Allow all the time".
    rationaleMessage: t.trackingRationaleMessage(
      '{backgroundPermissionOptionLabel}',
    ),
    rationaleAllow: t.trackingRationaleAllow,
    rationaleCancel: t.locationDisclosureDecline,
  );
}
