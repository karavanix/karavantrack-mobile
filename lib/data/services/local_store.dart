import 'package:shared_preferences/shared_preferences.dart';

/// Key-value storage on the device. Repositories depend on this interface
/// rather than on SharedPreferences, so tests can use an in-memory fake.
abstract interface class LocalStore {
  String? getString(String key);

  bool? getBool(String key);

  Future<void> setString(String key, String value);

  Future<void> setBool(String key, bool value);

  Future<void> remove(String key);
}

/// Every key the app keeps on the device.
abstract final class StoreKeys {
  static const accessToken = 'auth_token';
  static const refreshToken = 'refresh_token';
  static const locale = 'app_locale';
  static const darkTheme = 'app_theme_dark';
  static const seenLanguage = 'seen_language';
  static const seenOnboarding = 'seen_onboarding';
  static const pendingVerificationEmail = 'pending_verification_email';
  static const cachedProfile = 'cached_profile';
  static const pushDeviceId = 'fcm_device_id';

  static const all = {
    accessToken,
    refreshToken,
    locale,
    darkTheme,
    seenLanguage,
    seenOnboarding,
    pendingVerificationEmail,
    cachedProfile,
    pushDeviceId,
  };
}

/// [LocalStore] on SharedPreferences. Reads are served from a cache loaded
/// once in [create], so they are synchronous; writes go to disk.
class SharedPrefsLocalStore implements LocalStore {
  SharedPrefsLocalStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPrefsLocalStore> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: StoreKeys.all,
      ),
    );
    return SharedPrefsLocalStore._(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
