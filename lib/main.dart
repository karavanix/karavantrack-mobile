import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config/dependencies.dart';
import 'data/services/local_store.dart';
import 'data/services/telegram_auth_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before the first frame: that's when MainActivity/SceneDelegate deliver
  // a Telegram code from a cold start.
  final telegram = TelegramAuthService()..listen();
  final services = Services(
    store: await SharedPrefsLocalStore.create(),
    telegram: telegram,
  );
  runApp(MultiProvider(providers: providers(services), child: const App()));
}
