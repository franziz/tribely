import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/my_events/presentation/pages/my_events_page.dart';
import '../../features/users/presentation/pages/edit_profile_page.dart';
import '../../features/users/presentation/pages/own_profile_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';
import 'app_shell.dart';

// Navigator keys for the root navigator and each bottom-nav branch.
// The root key must be passed to GoRouter so that full-screen routes
// (editProfile, userProfile) push above the shell rather than inside a branch.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _discoverNavKey = GlobalKey<NavigatorState>(debugLabel: 'discover');
final _myEventsNavKey = GlobalKey<NavigatorState>(debugLabel: 'myEvents');
final _profileNavKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod's session state into a Listenable that go_router can
  // watch. Disposed automatically when the appRouterProvider is invalidated
  // (e.g. on hot reload).
  final notifier = _SessionRouterListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      // Routes that unauthenticated users are allowed to visit.
      // Everything not in this set requires authentication.
      const publicRoutes = {
        '/welcome',
        '/sign-in',
        '/sign-up',
        '/reset-password',
      };
      final isPublic = publicRoutes.contains(loc);
      final isAuthFlow = isPublic; // alias for the authenticated-branch check
      final isVerify = loc == '/verify-email';

      switch (session) {
        case SessionRestoring():
          // Stay on splash until restore completes.
          return isSplash ? null : '/splash';
        case SessionUnauthenticated():
          // Splash and verify-email both redirect to welcome (the former
          // because restore is done, the latter because the user is no longer
          // authenticated). Public routes are allowed through. Everything else
          // (e.g. /events, /my-events, /profile, /users/:id) is auth-required
          // and bounced back to /welcome.
          if (isSplash || isVerify || !isPublic) return '/welcome';
          return null;
        case SessionAuthenticated(:final session):
          // Authenticated but unverified: route everything except /verify-email
          // back to /verify-email so sensitive actions can't be reached.
          if (!session.user.isEmailVerified) {
            return isVerify ? null : '/verify-email';
          }
          // Splash, auth-flow pages, and verify all bounce to the shell landing.
          if (isSplash || isAuthFlow || isVerify) return '/events';
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'signIn',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return SignInPage(prefilledEmail: email);
        },
      ),
      GoRoute(
        path: '/sign-up',
        name: 'signUp',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verifyEmail',
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'resetPassword',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ResetPasswordPage(email: email);
        },
      ),
      // Legacy /home redirect — catches in-flight deep links and push payloads
      // that were issued before the /events rename. Redirect fires before any
      // builder so the builder can be omitted entirely.
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/events',
      ),
      // Full-screen route for other users' profiles. Declared outside the shell
      // with parentNavigatorKey pointing at root so it renders without the
      // bottom nav bar.
      GoRoute(
        path: '/users/:id',
        name: 'userProfile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfilePage(userId: userId);
        },
      ),
      // Shell with three branches sharing the persistent bottom NavigationBar.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Discover (/events)
          StatefulShellBranch(
            navigatorKey: _discoverNavKey,
            routes: [
              GoRoute(
                path: '/events',
                name: 'discover',
                builder: (context, state) => const DiscoverPage(),
              ),
            ],
          ),
          // Branch 1 — My Events
          StatefulShellBranch(
            navigatorKey: _myEventsNavKey,
            routes: [
              GoRoute(
                path: '/my-events',
                name: 'myEvents',
                builder: (context, state) => const MyEventsPage(),
              ),
            ],
          ),
          // Branch 2 — Profile
          // /profile/edit uses parentNavigatorKey: _rootNavigatorKey so it
          // renders as a full-screen push above the shell (no bottom nav).
          StatefulShellBranch(
            navigatorKey: _profileNavKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'ownProfile',
                builder: (context, state) => const OwnProfilePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editProfile',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfilePage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's session state into a [Listenable] for go_router's
/// [GoRouter.refreshListenable]. When session state changes, this notifier
/// fires and go_router re-evaluates `redirect`.
class _SessionRouterListenable extends ChangeNotifier {
  _SessionRouterListenable(this.ref) {
    _sub = ref.listen<SessionState>(
      sessionControllerProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }
  final Ref ref;
  late final ProviderSubscription<SessionState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
