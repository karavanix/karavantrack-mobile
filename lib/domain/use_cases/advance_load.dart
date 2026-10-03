import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/loads_repository.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../utils/result.dart';
import '../models/load.dart';

/// The photo the driver attached couldn't be uploaded, so the status was
/// left as it was.
final class PhotoUploadException implements Exception {
  const PhotoUploadException(this.cause);

  final Exception cause;

  @override
  String toString() => 'PhotoUploadException: $cause';
}

/// The driver's next step on a load (accept, picked up, on the way, …),
/// with an optional photo.
///
/// Tracking itself follows the active load (TrackingLifecycle starts it
/// once the accepted load comes back from the server). What the step adds
/// is the hint that the truck is about to set off: after "Accept" and "On
/// the way" the library is told the phone is moving, so the departure is
/// recorded from the first metres instead of after the motion sensors
/// notice, or after 150-200 m without them.
class AdvanceLoadUseCase {
  AdvanceLoadUseCase({
    required this._loads,
    required this._attachments,
    required this._tracking,
  });

  final LoadsRepository _loads;
  final AttachmentRepository _attachments;
  final TrackingRepository _tracking;

  static const _departures = {LoadAction.accept, LoadAction.start};

  Future<Result<void>> call(Load load, {String? photoPath}) async {
    final action = load.status.nextAction;
    if (action == null) {
      return Result.error(Exception('No action in status ${load.status}'));
    }
    final attachmentIds = <String>[];
    if (photoPath != null) {
      // The photo goes first, and a failed upload stops the status change:
      // the driver meant to attach it, so it mustn't silently go missing.
      switch (await _attachments.uploadPhoto(photoPath)) {
        case Ok(:final value):
          attachmentIds.add(value);
        case Error(:final error):
          return Result.error(PhotoUploadException(error));
      }
    }
    final result = await _loads.perform(
      load.id,
      action,
      attachmentIds: attachmentIds,
    );
    // Queued behind the start the new status triggers; does nothing if
    // tracking didn't start.
    if (result is Ok<void> && _departures.contains(action)) {
      await _tracking.moving();
    }
    return result;
  }
}
