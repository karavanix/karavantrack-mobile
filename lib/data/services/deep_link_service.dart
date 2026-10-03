import 'package:app_links/app_links.dart';

import '../../utils/logger.dart';

/// Links that open the app: `https://app.yool.live/invite/{token}` (App
/// Links / Universal Links) and `yoollive://invite/{token}`. The Telegram
/// redirect also uses the custom scheme but is handled natively.
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  /// The link that launched the app, then every link while it runs.
  Stream<Uri> links() async* {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) yield initial;
    } catch (e, st) {
      log.error('Reading the launch link failed', e, st);
    }
    yield* _appLinks.uriLinkStream;
  }
}
