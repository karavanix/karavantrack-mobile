import '../../../data/repositories/profile_repository.dart';
import '../../../domain/use_cases/session_lifecycle.dart';
import '../../../utils/command.dart';
import '../../../utils/result.dart';

/// Signed in, but the profile couldn't be loaded and there's no copy on the
/// device.
class NoConnectionViewModel {
  NoConnectionViewModel({required this._profile, required this._session}) {
    retry = Command0(_retry);
    signOut = Command0(_signOut);
  }

  final ProfileRepository _profile;
  final SessionLifecycle _session;
  late final Command0<void> retry;
  late final Command0<void> signOut;

  Future<Result<void>> _retry() async {
    await _profile.refresh();
    return const Result.ok(null);
  }

  Future<Result<void>> _signOut() async {
    await _session.signOut();
    return const Result.ok(null);
  }

  void dispose() {
    retry.dispose();
    signOut.dispose();
  }
}
