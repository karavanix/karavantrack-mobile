import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/repositories/push_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/push_service.dart';
import '../routing/router.dart';
import '../routing/routes.dart';
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
    profile: context.read(),
    invites: context.read(),
  );
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<PushMessage> _pushes;
  late final StreamSubscription<String> _openedLoads;
  String? _loadToOpen;

  @override
  void initState() {
    super.initState();
    final push = context.read<PushRepository>();
    // The system doesn't show a push that arrives while the app is open.
    _pushes = push.foregroundMessages.listen((m) {
      final text = m.title ?? m.body;
      if (text == null) return;
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
    });
    _openedLoads = push.openedLoadIds.listen((id) {
      _loadToOpen = id;
      _openTappedLoad();
    });
    _router.routerDelegate.addListener(_openTappedLoad);
  }

  /// A tapped notification opens its load, once the driver is in the app:
  /// a tap that launched it waits out the splash and sign-in screens.
  void _openTappedLoad() {
    final id = _loadToOpen;
    if (id == null) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (!path.startsWith(Routes.loads) && !path.startsWith(Routes.settings)) {
      return;
    }
    _loadToOpen = null;
    // Not from inside the router's own notification.
    scheduleMicrotask(() => _router.go(Routes.loadDetails(id)));
  }

  @override
  void dispose() {
    _pushes.cancel();
    _openedLoads.cancel();
    _router.routerDelegate.removeListener(_openTappedLoad);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    return MaterialApp.router(
      routerConfig: _router,
      scaffoldMessengerKey: _messenger,
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
