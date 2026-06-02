import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/phone_entry_page.dart';
import '../../features/reviews/presentation/pages/my_reviews_written_page.dart';
import '../../features/reviews/presentation/pages/review_composer_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/sign_up_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/verify_phone_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/discover/presentation/pages/event_detail_page.dart';
import '../../features/events/presentation/pages/create_event_page.dart';
import '../../features/events/presentation/pages/phone_gate_page.dart';
import '../../features/my_events/presentation/pages/my_events_page.dart';
import '../../features/account/presentation/pages/account_deleted_page.dart';
import '../../features/account/presentation/pages/delete_account_page.dart';
import '../../features/user_blocks/presentation/pages/blocked_users_page.dart';
import '../../features/users/presentation/pages/edit_profile_page.dart';
import '../../features/users/presentation/pages/own_profile_page.dart';
import '../../features/users/presentation/pages/settings_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';
import '../../features/users/presentation/pages/verification_failure_page.dart';
import '../../features/check_ins/presentation/pages/safety_report_page.dart';
import '../../features/check_ins/presentation/pages/safety_report_submitted_page.dart';
import '../../features/check_ins/presentation/providers/check_ins_providers.dart';
import '../../features/check_ins/presentation/widgets/check_ins_overlay.dart';
import '../../features/help_centre/presentation/pages/help_article_page.dart';
import '../../features/support/presentation/pages/support_contact_page.dart';
import '../../features/support/presentation/pages/support_contact_success_page.dart';
import '../lifecycle/app_lifecycle_listener.dart';
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
        // Terminal account-deleted screen — must be public so the post-signOut
        // session change (SessionUnauthenticated) does not redirect mid-frame
        // back to /welcome before the screen can render (AC4/AC5 race fix).
        '/account-deleted',
        // Help centre articles are informational and must be reachable without
        // a session (e.g. linked from the report-received sheet pre-auth).
        '/help',
      };
      // Auth-wizard subset of publicRoutes — pages that an *authenticated* user
      // must be bounced away from (back to the shell landing). Distinct from
      // `publicRoutes` because /help/* and /account-deleted are reachable from
      // inside an authenticated session and must NOT trigger a redirect to
      // /events when visited.
      const authFlowRoutes = {
        '/welcome',
        '/sign-in',
        '/sign-up',
        '/reset-password',
      };
      // Prefix match so /help/article/:id (and any future /help/*) is covered.
      final isPublic = publicRoutes.any(
        (p) => loc == p || loc.startsWith('$p/'),
      );
      final isAuthFlow = authFlowRoutes.contains(loc);
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
          // Phone-verification gate at the entry to the create-event wizard.
          // Server-side gate (POST /events) remains the source of truth; this
          // client-side gate prevents the user from filling 5 wizard steps then
          // hitting a 403. Mid-session revocation (phoneVerifiedAt → null) is
          // handled by this same redirect on the next router refresh.
          if (loc == '/events/new' && !session.user.isPhoneVerified) {
            return '/events/new/phone-gate';
          }
          // Symmetric guard: a phone-verified user who somehow lands on the gate
          // (deep link, back-stack) is forwarded into the wizard.
          if (loc == '/events/new/phone-gate' && session.user.isPhoneVerified) {
            return '/events/new';
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
      // Phone OTP wizard — step 1: country picker + phone entry.
      GoRoute(
        path: '/auth/phone/entry',
        name: 'phoneEntry',
        builder: (context, state) => const PhoneEntryPage(),
      ),
      // Phone OTP wizard — step 2: 6-digit code entry.
      // Declared as a sibling (not a child) so context.go('/auth/phone/verify')
      // from PhoneEntryPage pushes a new stack frame rather than replacing the
      // current route. The controller retains the entered phone number, so the
      // "Wrong number? Go back" action restores entry state correctly.
      GoRoute(
        path: '/auth/phone/verify',
        name: 'verifyPhone',
        builder: (context, state) => const VerifyPhonePage(),
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
      GoRoute(path: '/home', redirect: (context, state) => '/events'),
      // Full-screen review composer. Declared outside the shell with
      // parentNavigatorKey pointing at root so it renders without the bottom
      // nav bar. Accepts eventId, ratedUserId, and optional reviewId, ratedUserName,
      // prefillRating, prefillComment, reviewCreatedAt query params.
      GoRoute(
        path: '/reviews/write',
        name: 'reviewComposer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final eventId = q['eventId'] ?? '';
          final ratedUserId = q['ratedUserId'] ?? '';
          final reviewId = q['reviewId'];
          final ratedUserName = q['ratedUserName'];
          final prefillRatingStr = q['prefillRating'];
          final prefillComment = q['prefillComment'];
          final reviewCreatedAtStr = q['reviewCreatedAt'];
          return ReviewComposerPage(
            eventId: eventId,
            ratedUserId: ratedUserId,
            reviewId: reviewId,
            ratedUserName: ratedUserName,
            prefillRating: prefillRatingStr != null
                ? int.tryParse(prefillRatingStr)
                : null,
            prefillComment: prefillComment,
            reviewCreatedAt: reviewCreatedAtStr != null
                ? DateTime.tryParse(reviewCreatedAtStr)
                : null,
          );
        },
      ),
      // Full-screen "Reviews I wrote" page. Declared outside the shell with
      // parentNavigatorKey pointing at root so it renders without the bottom
      // nav bar.
      GoRoute(
        path: '/profile/reviews-written',
        name: 'myReviewsWritten',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyReviewsWrittenPage(),
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
      // Full-screen verification failure / lockout page. Declared outside the
      // shell with parentNavigatorKey pointing at root so the bottom nav bar
      // is hidden and the sheet modal survives tab switches.
      GoRoute(
        path: '/verification/failure',
        name: 'verificationFailure',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VerificationFailurePage(),
      ),
      // Full-screen Settings page. No bottom nav — lives on root navigator.
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      // Full-screen Blocked Users page (under Settings → Privacy & Safety).
      // No bottom nav — lives on root navigator.
      GoRoute(
        path: '/settings/blocked-users',
        name: 'blockedUsers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockedUsersPage(),
      ),
      // Phone-verification gate — shown to unverified users who attempt to
      // enter the create-event wizard. Declared outside the shell so the
      // bottom nav bar is hidden, matching the /events/new sibling.
      GoRoute(
        path: '/events/new/phone-gate',
        name: 'createEventPhoneGate',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PhoneGatePage(),
      ),
      // Full-screen create-event flow. Declared outside the shell with
      // parentNavigatorKey pointing at root so it renders without the bottom
      // nav bar. Uses context.push (not go) to preserve back-stack from
      // the My Events tab.
      GoRoute(
        path: '/events/new',
        name: 'createEvent',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateEventPage(),
      ),
      // Full-screen read-only event detail. Declared outside the shell so
      // the bottom nav bar is hidden (§E). Uses context.push from the
      // Discover feed/map; back navigation returns to the caller's position.
      GoRoute(
        path: '/events/:id',
        name: 'eventDetail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return EventDetailPage(eventId: eventId);
        },
      ),
      // Full-screen safety report form — reached from "I need help" in the
      // check-in prompt sheet. The active check-in id is read from
      // `checkInsControllerProvider`'s `CheckInsShowing` state — the page is
      // only reached while a check-in is being prompted.
      GoRoute(
        path: '/check-ins/safety-report',
        name: 'safetyReport',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SafetyReportPage(),
      ),
      // Terminal-state confirmation page after a safety report is submitted.
      // Back navigation is suppressed; "Done" returns to /events.
      GoRoute(
        path: '/help/article/:id',
        name: 'helpArticle',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return HelpArticleScreen(articleId: id);
        },
      ),
      GoRoute(
        path: '/check-ins/safety-report/submitted',
        name: 'safetyReportSubmitted',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SafetyReportSubmittedPage(),
      ),
      // Full-screen account deletion confirmation — reached via context.push()
      // from OwnProfilePage. Declared outside the shell so the bottom nav bar
      // is hidden. Uses parentNavigatorKey: _rootNavigatorKey per the pattern
      // established by /events/new and /verification/failure.
      GoRoute(
        path: '/account/delete',
        name: 'deleteAccount',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DeleteAccountPage(),
      ),
      // Terminal screen after successful account deletion — reached via
      // context.go('/account-deleted') from the delete-account controller.
      // Declared outside the shell AND listed in publicRoutes so the
      // SessionUnauthenticated redirect does not bounce mid-frame to /welcome.
      GoRoute(
        path: '/account-deleted',
        name: 'accountDeleted',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AccountDeletedPage(),
      ),
      // Full-screen support contact form — reached via Settings → Help & Support
      // or via deep link `/support/contact?reportId=XXX`. Requires authentication;
      // the redirect guard above covers unauthenticated access.
      GoRoute(
        path: '/support/contact',
        name: 'supportContact',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SupportContactPage(),
      ),
      // Terminal success screen after a support ticket is submitted. Reached via
      // context.pushReplacement from SupportContactPage. The `?id=` query param
      // is available to the page but is not displayed (brief: no case number shown).
      GoRoute(
        path: '/support/contact/success',
        name: 'supportContactSuccess',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SupportContactSuccessPage(),
      ),
      // Shell with three branches sharing the persistent bottom NavigationBar.
      // OnResumedListener is mounted HERE — above the indexedStack — so a
      // single observer covers all three branches.  Mounting inside a branch
      // builder would miss transitions when the user is on a different tab, and
      // could fire multiple times if multiple branches are live simultaneously.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) => CheckInsOverlay(
            child: OnResumedListener(
              onResumed: () {
                // Trigger a check-in surface on every foreground resume so the
                // controller can transition to CheckInsShowing when pending
                // check-ins exist. CheckInsOverlay reacts to Showing with
                // showModalBottomSheet.
                ref.read(checkInsControllerProvider.notifier).refresh();
              },
              child: AppShell(navigationShell: navigationShell),
            ),
          ),
        ),
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
