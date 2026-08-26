import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

/// Service that requests "Allow all the time" (Always) location permission.
///
/// Attempts the native permission prompts (iOS can request an "Always" upgrade
/// exactly once after "While Using"; Android can re-prompt). The granted result
/// is returned to the caller, which mirrors it into the AppStore so the Loads
/// screen can show its frosted blocking overlay when Always is not granted.
class LocationPermissionService {
  LocationPermissionService._();

  /// Returns `true` when the user has granted "Allow all the time" location
  /// permission, which is required for background / killed-state tracking.
  static Future<bool> isAlwaysGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Returns `true` when the OS will actually surface a permission prompt for
  /// "Always" (i.e. permission is merely un-requested or "while in use").
  /// `false` when the user has permanently denied it — at that point only the
  /// system Settings screen can change it, so callers should skip straight to
  /// that instead of showing a disclosure for a prompt that won't appear.
  static Future<bool> canPromptForAlways() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.denied ||
        permission == LocationPermission.whileInUse;
  }

  /// Checks the current location permission level. If it is not "always",
  /// attempts to acquire it via the OS prompts (iOS/Android).
  ///
  /// Does not show any UI of its own — when the permission is still not
  /// "Always", the returned `false` drives the Loads-screen blocking overlay.
  ///
  /// Returns `true` once the permission is granted.
  static Future<bool> enforceAlwaysPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) return true;

    // If denied entirely, request basic permission first. On iOS this shows
    // the native "Allow While Using App / Allow Once / Don't Allow" prompt.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always) return true;
    }

    // On iOS, after "While Using" is granted, request the Always upgrade via
    // permission_handler — this reliably calls
    // CLLocationManager.requestAlwaysAuthorization, which shows iOS's native
    // one-time "Allow Always" upgrade prompt. (Geolocator's second
    // requestPermission() call does not consistently trigger it.)
    // iOS only ever shows this prompt once per install; after that, the user
    // must go to Settings.
    if (Platform.isIOS && permission == LocationPermission.whileInUse) {
      // iOS needs a brief pause between the two native prompts or the second
      // prompt may be silently ignored.
      await Future.delayed(const Duration(milliseconds: 500));
      final iosResult = await permission_handler.Permission.locationAlways
          .request();
      if (iosResult.isGranted) return true;
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always) return true;
    }

    // Android: a second Geolocator.requestPermission() does work here
    // (unlike iOS where it silently does nothing after the first call).
    if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always) return true;
    }

    // Still not "Always" — the caller (app.dart) mirrors the result into the
    // AppStore, which drives the Loads-screen blocking overlay. No dialog here.
    return await isAlwaysGranted();
  }
}
