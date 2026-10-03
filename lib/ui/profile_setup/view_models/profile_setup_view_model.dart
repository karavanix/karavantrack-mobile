import '../../../data/repositories/profile_repository.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

typedef FullName = ({String firstName, String lastName});

class FirstNameMissing implements Exception {
  const FirstNameMissing();
}

/// Saves the driver's name; shared by the first-run profile screen and the
/// edit sheet in settings.
Future<Result<void>> saveProfileName(
  ProfileRepository profile,
  FullName name,
) async {
  final first = name.firstName.trim();
  if (first.isEmpty) return const Result.error(FirstNameMissing());
  return profile.updateName(firstName: first, lastName: name.lastName.trim());
}

/// The name a new account must give before reaching the app.
class ProfileSetupViewModel {
  ProfileSetupViewModel({required this._profile}) {
    save = Command1((name) => saveProfileName(_profile, name));
  }

  final ProfileRepository _profile;
  late final Command1<void, FullName> save;

  /// Apple and Telegram may already have given a name.
  FullName get initial => (
    firstName: _profile.user?.firstName ?? '',
    lastName: _profile.user?.lastName ?? '',
  );

  void dispose() => save.dispose();
}
