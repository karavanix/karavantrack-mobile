import 'package:driver_tracking_app/data/services/api/api_exception.dart';
import 'package:driver_tracking_app/domain/use_cases/advance_load.dart';
import 'package:driver_tracking_app/ui/core/errors.dart';
import 'package:driver_tracking_app/ui/core/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations ru;

  setUpAll(() async {
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  String text(Exception e) => loadActionErrorText(ru, e);

  test('a refused step: the load changed', () {
    for (final status in [400, 403, 404, 409]) {
      expect(text(HttpException(status, 'x')), ru.loadChanged);
    }
  });

  test('another active load has its own sentence', () {
    expect(
      text(const HttpException(409, 'x', code: 'CARRIER_HAS_ACTIVE_LOAD')),
      ru.inviteCarrierHasActiveLoad,
    );
  });

  test('the photo, the network and the server', () {
    expect(
      text(const PhotoUploadException(NetworkException('x'))),
      ru.podUploadFailed,
    );
    expect(text(const NetworkException('x')), ru.errorNetwork);
    expect(text(const HttpException(502, 'x')), ru.errorServer);
  });
}
