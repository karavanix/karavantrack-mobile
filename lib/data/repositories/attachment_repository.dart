import '../../utils/result.dart';
import '../services/api/attachments_api.dart';

/// Files the driver attaches to a load's status changes.
class AttachmentRepository {
  AttachmentRepository({required this._api});

  final AttachmentsApi _api;

  /// Ok with the attachment id to pass along with the status change.
  Future<Result<String>> uploadPhoto(String path) => _api.uploadPhoto(path);
}
