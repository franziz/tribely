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
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/users/presentation/pages/edit_profile_page.dart';
import '../../features/users/presentation/pages/own_profile_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod's session state into a Listenable that go_router can
  // watch. Disposed automatically when the appRouterProvider is invalidated
  // (e.g. on hot reload).
  final notifier = _SessionRouterListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
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
          // (e.g. /profile, /profile/edit, /users/:id, /home) is auth-required
          // and bounced back to /welcome.
          if (isSplash || isVerify || !isPublic) return '/welcome';
          return null;
        case SessionAuthenticated(:final session):
          // Authenticated but unverified: route everything except /verify-email
          // back to /verify-email so sensitive actions can't be reached. The
          // banner on /home is still useful as a backup signal once we let
          // the user choose to dismiss the verify gate (TBD).
          if (!session.user.isEmailVerified) {
            return isVerify ? null : '/verify-email';
          }
          if (isSplash || isAuthFlow || isVerify) return '/home';
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
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'ownProfile',
        builder: (context, state) => const OwnProfilePage(),
        routes: [
          GoRoute(
            path: 'edit',
            name: 'editProfile',
            builder: (context, state) => const EditProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/users/:id',
        name: 'userProfile',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          return UserProfilePage(userId: userId);
        },
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
