import 'package:package_info_plus/package_info_plus.dart';

class AppInfoService {
  /// `1.5.3+46`: version name and build number from the build itself.
  Future<String> version() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }
}
