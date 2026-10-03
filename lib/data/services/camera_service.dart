import 'package:image_picker/image_picker.dart';

import '../../utils/logger.dart';

/// Takes a photo with the system camera.
class CameraService {
  /// Path of the photo taken, or null when the driver backed out.
  Future<String?> takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return photo?.path;
    } catch (e, st) {
      // No camera, or camera access denied.
      log.error('Camera failed', e, st);
      return null;
    }
  }
}
