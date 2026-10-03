import 'package:driver_tracking_app/data/services/api/api_exception.dart';
import 'package:driver_tracking_app/data/services/apple_sign_in_service.dart';
import 'package:driver_tracking_app/ui/auth/view_models/login_view_model.dart';
import 'package:driver_tracking_app/ui/core/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations ru;

  setUpAll(() async {
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  String? text(Exception e, {bool signUp = false}) =>
      loginErrorText(ru, e, signUp: signUp);

  test('403 on sign-in: wrong e-mail or password', () {
    expect(
      text(const HttpException(403, 'permission denied', code: 'FORBIDDEN')),
      'Неверная почта или пароль.',
    );
  });

  test('409 on sign-up: the e-mail is taken', () {
    expect(
      text(const HttpException(409, 'email', code: 'CONFLICT'), signUp: true),
      'Аккаунт с этой почтой уже есть. Войдите в него.',
    );
  });

  test('form problems are caught before sending', () {
    expect(
      text(const FormException(FormProblem.invalidEmail)),
      'Введите корректный адрес почты.',
    );
    expect(
      text(const FormException(FormProblem.passwordTooShort), signUp: true),
      'Пароль должен быть не короче 8 символов.',
    );
  });

  test('no network, server down', () {
    expect(text(const NetworkException('x')), ru.errorNetwork);
    expect(text(const HttpException(502, 'bad gateway')), ru.errorServer);
  });

  test('closing the Apple sheet says nothing', () {
    expect(text(const AppleSignInCancelled()), isNull);
  });

  test('an unknown failure still gets a sentence', () {
    expect(text(Exception('boom')), ru.errorSignInFailed);
  });
}
