import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/loads_repository.dart';
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
class AdvanceLoadUseCase {
  AdvanceLoadUseCase({required this._loads, required this._attachments});

  final LoadsRepository _loads;
  final AttachmentRepository _attachments;

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
    return _loads.perform(load.id, action, attachmentIds: attachmentIds);
  }
}
