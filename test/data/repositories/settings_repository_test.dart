import 'dart:ui';

import 'package:driver_tracking_app/data/repositories/settings_repository.dart';
import 'package:driver_tracking_app/data/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fake_local_store.dart';

void main() {
  test('defaults: English, dark theme, nothing seen', () {
    final settings = SettingsRepository(store: FakeLocalStore());

    expect(settings.locale, const Locale('en'));
    expect(settings.darkTheme, isTrue);
    expect(settings.seenLanguage, isFalse);
    expect(settings.seenOnboarding, isFalse);
  });

  test('changes are stored and survive a restart', () async {
    final store = FakeLocalStore();
    final settings = SettingsRepository(store: store);

    await settings.setLocale(const Locale('uz'));
    await settings.setDarkTheme(false);
    await settings.markLanguageSeen();
    await settings.markOnboardingSeen();

    final restarted = SettingsRepository(store: store);
    expect(restarted.locale, const Locale('uz'));
    expect(restarted.darkTheme, isFalse);
    expect(restarted.seenLanguage, isTrue);
    expect(restarted.seenOnboarding, isTrue);
    expect(store.values[StoreKeys.locale], 'uz');
  });

  test('notifies only on an actual change', () async {
    final settings = SettingsRepository(store: FakeLocalStore());
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setLocale(const Locale('en'));
    await settings.setLocale(const Locale('ru'));
    await settings.markLanguageSeen();
    await settings.markLanguageSeen();

    expect(notified, 2);
  });
}
