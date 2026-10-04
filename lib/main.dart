import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config/dependencies.dart';
import 'data/services/deep_link_service.dart';
import 'data/services/local_store.dart';
import 'data/repositories/tracking_repository.dart';
import 'data/services/telegram_auth_service.dart';
import 'data/services/tracking/tracking_service.dart';
import 'ui/app.dart';
import 'ui/core/l10n/tracking_texts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before the first frame: a Telegram code may be what started the app
  // (the Telegram app's link, or MainActivity/SceneDelegate after the
  // browser login).
  final links = DeepLinkService();
  final telegram = TelegramAuthService()..listen(links.links());
  final store = await SharedPrefsLocalStore.create();
  // Before runApp: when iOS relaunches the app in the background to resume
  // tracking, no widget gets built, but the library needs its ready().
  final tracking = BgTrackingService();
  final trackingAtLaunch = await TrackingRepository.ready(
    tracking,
    store,
    trackingTexts(store),
  );
  final services = Services(
    store: store,
    telegram: telegram,
    links: links,
    tracking: tracking,
    trackingAtLaunch: trackingAtLaunch,
  );
  runApp(MultiProvider(providers: providers(services), child: const App()));
}
