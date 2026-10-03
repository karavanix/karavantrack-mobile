import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/api/api_client.dart';
import '../data/services/api/auth_api.dart';
import '../data/services/local_store.dart';
import '../routing/app_startup.dart';

/// The object graph: services first, repositories on top of them. Views and
/// view models get what they need with `context.read<T>()`.
List<SingleChildWidget> providers(LocalStore store) => [
  Provider<LocalStore>.value(value: store),
  Provider(create: (_) => AuthApi(ApiClient.public())),
  ChangeNotifierProvider(
    create: (context) =>
        AuthRepository(api: context.read(), store: context.read()),
  ),
  Provider(
    create: (context) =>
        ApiClient.authenticated(tokens: context.read<AuthRepository>()),
  ),
  ChangeNotifierProvider(
    create: (context) => SettingsRepository(store: context.read()),
  ),
  ChangeNotifierProvider(create: (_) => AppStartup()..run(const [])),
];
