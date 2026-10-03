import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/invite_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../ui/auth/view_models/login_view_model.dart';
import '../ui/auth/views/login_screen.dart';
import '../ui/core/ui/placeholder_screen.dart';
import '../ui/invite/view_models/invite_view_model.dart';
import '../ui/invite/views/invite_screen.dart';
import '../ui/language/view_models/language_view_model.dart';
import '../ui/language/views/language_screen.dart';
import '../ui/main_shell/views/main_shell.dart';
import '../ui/no_connection/view_models/no_connection_view_model.dart';
import '../ui/no_connection/views/no_connection_screen.dart';
import '../ui/onboarding/view_models/onboarding_view_model.dart';
import '../ui/onboarding/views/onboarding_screen.dart';
import '../ui/profile_setup/view_models/profile_setup_view_model.dart';
import '../ui/profile_setup/views/profile_setup_screen.dart';
import '../ui/settings/view_models/settings_view_model.dart';
import '../ui/settings/views/settings_screen.dart';
import '../ui/splash/views/splash_screen.dart';
import '../ui/verify_email/view_models/verify_email_view_model.dart';
import '../ui/verify_email/views/verify_email_screen.dart';
import 'app_startup.dart';
import 'redirect.dart' as nav;
import 'routes.dart';

GoRouter createRouter({
  required AppStartup startup,
  required AuthRepository auth,
  required SettingsRepository settings,
  required ProfileRepository profile,
  required InviteRepository invites,
}) {
  nav.ProfileGate profileGate() => switch (profile.user) {
    final user? =>
      user.isProfileComplete
          ? nav.ProfileGate.complete
          : nav.ProfileGate.incomplete,
    null when profile.status == ProfileStatus.unavailable =>
      nav.ProfileGate.unavailable,
    null => nav.ProfileGate.loading,
  };

  nav.RouteState snapshot() => nav.RouteState(
    ready: startup.ready,
    signedIn: auth.isSignedIn,
    profile: profileGate(),
    seenLanguage: settings.seenLanguage,
    seenOnboarding: settings.seenOnboarding,
    pendingVerification: auth.pendingVerificationEmail != null,
    inviteToken: invites.token,
    inviteSignInRequested: invites.acceptAfterSignIn,
    acceptedLoadId: invites.acceptedLoadId,
  );

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: Listenable.merge([
      startup,
      auth,
      settings,
      profile,
      invites,
    ]),
    redirect: (context, state) => nav.redirect(snapshot(), state.uri.path),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (context, _) => _Owned(
          create: () => VerifyEmailViewModel(auth: context.read()),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => VerifyEmailScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '${Routes.invitePrefix}/:token',
        builder: (context, state) => _Owned(
          // A new token means a new invite screen.
          key: ValueKey(state.pathParameters['token']),
          create: () =>
              InviteViewModel(invites: context.read(), auth: context.read()),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => InviteScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Routes.language,
        builder: (context, _) => _Owned(
          create: () => LanguageViewModel(settings: context.read()),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => LanguageScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, _) => _Owned(
          create: () => OnboardingViewModel(settings: context.read()),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => OnboardingScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, _) => _Owned(
          create: () => LoginViewModel(
            auth: context.read(),
            settings: context.read(),
            invites: context.read(),
          ),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => LoginScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Routes.profileSetup,
        builder: (context, _) => _Owned(
          create: () => ProfileSetupViewModel(profile: context.read()),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => ProfileSetupScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Routes.noConnection,
        builder: (context, _) => _Owned(
          create: () => NoConnectionViewModel(
            profile: context.read(),
            session: context.read(),
          ),
          dispose: (vm) => vm.dispose(),
          builder: (vm) => NoConnectionScreen(viewModel: vm),
        ),
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
                  // Before ':loadId', which would match it too.
                  GoRoute(
                    path: 'history',
                    builder: (_, _) =>
                        const PlaceholderScreen(title: 'History'),
                  ),
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
                path: Routes.settings,
                builder: (context, _) => _Owned(
                  create: () => SettingsViewModel(
                    profile: context.read(),
                    settings: context.read(),
                    session: context.read(),
                    appInfo: context.read(),
                  ),
                  dispose: (vm) => vm.dispose(),
                  builder: (vm) => SettingsScreen(viewModel: vm),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Creates a screen's view model once, for as long as the screen is
/// shown, and disposes it with the screen. Route builders run again on
/// every navigation, so the view model can't be created in them directly.
class _Owned<T extends Object> extends StatefulWidget {
  const _Owned({
    super.key,
    required this.create,
    required this.dispose,
    required this.builder,
  });

  final T Function() create;
  final void Function(T) dispose;
  final Widget Function(T) builder;

  @override
  State<_Owned<T>> createState() => _OwnedState<T>();
}

class _OwnedState<T extends Object> extends State<_Owned<T>> {
  late final T _viewModel = widget.create();

  @override
  void dispose() {
    widget.dispose(_viewModel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_viewModel);
}
