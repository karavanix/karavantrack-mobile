import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// gen-l10n quietly falls back to English for a key missing in ru/uz; this
/// makes a forgotten translation fail instead.
void main() {
  Set<String> keysOf(String locale) {
    final arb =
        jsonDecode(File('lib/ui/core/l10n/app_$locale.arb').readAsStringSync())
            as Map<String, Object?>;
    return arb.keys.where((k) => !k.startsWith('@')).toSet();
  }

  final english = keysOf('en');

  for (final locale in ['ru', 'uz']) {
    test('$locale has exactly the English keys', () {
      final keys = keysOf(locale);
      expect(english.difference(keys), isEmpty, reason: 'missing in $locale');
      expect(keys.difference(english), isEmpty, reason: 'extra in $locale');
    });
  }
}
