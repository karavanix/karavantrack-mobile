import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/repositories/settings_repository.dart';
import '../routing/router.dart';
import 'core/l10n/l10n.dart';
import 'core/themes/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = createRouter(
    startup: context.read(),
    auth: context.read(),
    settings: context.read(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    return MaterialApp.router(
      routerConfig: _router,
      title: 'YoolLive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.darkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // talker_flutter's log screen is still built on the framework's
      // frozen copy of Material; the bridge gives it our theme and
      // localizations. Deprecated on purpose (temporary by design); goes
      // once talker_flutter moves to material_ui.
      // ignore: deprecated_member_use
      builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
    );
  }
}
