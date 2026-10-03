import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'config/dependencies.dart';
import 'data/services/local_store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SharedPrefsLocalStore.create();
  runApp(MultiProvider(providers: providers(store), child: const App()));
}
