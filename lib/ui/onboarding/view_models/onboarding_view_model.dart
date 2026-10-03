import '../../../data/repositories/settings_repository.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

class OnboardingViewModel {
  OnboardingViewModel({required this._settings}) {
    finish = Command0(_finish);
  }

  final SettingsRepository _settings;
  late final Command0<void> finish;

  Future<Result<void>> _finish() async {
    await _settings.markOnboardingSeen();
    return const Result.ok(null);
  }

  void dispose() => finish.dispose();
}
