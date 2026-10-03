import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../ui/core/ui/placeholder_screen.dart';
import '../ui/main_shell/views/main_shell.dart';
import '../utils/logger.dart';
import 'app_startup.dart';
import 'redirect.dart' as nav;
import 'routes.dart';

GoRouter createRouter({
  required AppStartup startup,
  required AuthRepository auth,
  required SettingsRepository settings,
}) {
  nav.RouteState snapshot() => nav.RouteState(
    ready: startup.ready,
    signedIn: auth.isSignedIn,
    // Until the profile is loaded from the server every session counts
    // as complete.
    profileCompleted: true,
    seenLanguage: settings.seenLanguage,
    seenOnboarding: settings.seenOnboarding,
  );

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: Listenable.merge([startup, auth, settings]),
    redirect: (context, state) => nav.redirect(snapshot(), state.uri.path),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const PlaceholderScreen(title: 'YoolLive'),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, _) => const PlaceholderScreen(title: 'Verify e-mail'),
      ),
      GoRoute(
        path: '${Routes.invitePrefix}/:token',
        builder: (_, state) => PlaceholderScreen(
          title: 'Invite ${state.pathParameters['token']}',
        ),
      ),
      GoRoute(
        path: Routes.language,
        builder: (_, _) => PlaceholderScreen(
          title: 'Language',
          actions: [
            for (final locale in SettingsRepository.supportedLocales)
              (
                label: SettingsRepository.languageNames[locale.languageCode]!,
                onPressed: () async {
                  await settings.setLocale(locale);
                  await settings.markLanguageSeen();
                },
              ),
          ],
        ),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => PlaceholderScreen(
          title: 'Onboarding',
          actions: [(label: 'Next', onPressed: settings.markOnboardingSeen)],
        ),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const PlaceholderScreen(title: 'Login'),
      ),
      GoRoute(
        path: Routes.profileSetup,
        builder: (_, _) => const PlaceholderScreen(title: 'Profile'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.loads,
                builder: (_, _) => const PlaceholderScreen(title: 'Loads'),
                routes: [
                  GoRoute(
                    path: ':loadId',
                    builder: (_, state) => PlaceholderScreen(
                      title: 'Load ${state.pathParameters['loadId']}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (_, _) => const PlaceholderScreen(title: 'History'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, _) => PlaceholderScreen(
                  title: 'Settings',
                  actions: [
                    (
                      label: 'Toggle theme',
                      onPressed: () =>
                          settings.setDarkTheme(!settings.darkTheme),
                    ),
                    (
                      label: 'Logs',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TalkerScreen(talker: log),
                        ),
                      ),
                    ),
                    (label: 'Sign out', onPressed: auth.signOut),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
