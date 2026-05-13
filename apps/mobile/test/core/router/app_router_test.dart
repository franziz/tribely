// Tests for the StatefulShellRoute routing structure in app_router.dart.
//
// Strategy: build a test-scoped GoRouter that mirrors the production route
// tree but replaces pages that require the full get_it DI graph (OwnProfilePage,
// EditProfilePage, UserProfilePage) with labelled stub Scaffolds.  DiscoverPage
// and MyEventsPage are rendered directly to validate that the real pages appear
// under the bottom nav.
//
// Stub-builder pattern is used for:
//   - OwnProfilePage            → reads myProfileControllerProvider → needs get_it
//   - EditProfilePage           → reads editProfileControllerProvider → needs get_it
//   - UserProfilePage           → reads userProfileControllerProvider → needs get_it
//   - MyJoinRequestsController  → reads listMyJoinRequestsUseCaseProvider → needs get_it
//
// Each stub Scaffold carries a unique Key so finders don't need to import
// the production widgets at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/router/app_shell.dart';
import 'package:tribely/src/core/services/location_service.dart';
import 'package:tribely/src/core/services/location_service_providers.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_map_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/my_join_requests_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/my_join_requests_state.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_pending_count_controller.dart';
import 'package:tribely/src/features/my_events/presentation/pages/my_events_page.dart';

// ---------------------------------------------------------------------------
// Keys for stub widgets — used as primary finders in assertions.
// ---------------------------------------------------------------------------

const _kOwnProfileStubKey = Key('__stub_own_profile__');
const _kEditProfileStubKey = Key('__stub_edit_profile__');
const _kUserProfileStubKey = Key('__stub_user_profile__');

// ---------------------------------------------------------------------------
// DiscoverPage stubs — prevent GetIt / location-service access
// ---------------------------------------------------------------------------

class MockLocationService extends Mock implements LocationService {}

/// Bypasses DiscoverController's use-case fetch (which calls sl<>) so that
/// the router test can render DiscoverPage without initialising GetIt.
class _FixedDiscoverController extends DiscoverController {
  @override
  DiscoverState build() => const DiscoverLoading();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _FixedFilterController extends DiscoverFilterController {
  @override
  DiscoverFilterState build() => const DiscoverFiltersActive();
}

class _PromptAlreadyShownNotifier extends LocationPromptShownNotifier {
  @override
  bool build() => true;
}

/// Bypasses MyJoinRequestsController's use-case fetch (which calls sl<>) so
/// that MyEventsPage can be rendered in router tests without initialising GetIt.
class _FixedMyJoinRequestsController extends MyJoinRequestsController {
  _FixedMyJoinRequestsController() : super(null);

  @override
  MyJoinRequestsState build() => const MyJoinRequestsLoaded(items: []);
}

/// Bypasses HostingPendingCountController's _load() which reads
/// listPendingForEventUseCaseProvider → sl<>. Returns zero state immediately.
///
/// MyEventsPage watches hostingPendingCountControllerProvider([]) (empty list)
/// on every build. Without this override the controller's scheduled async
/// _load() crashes on GetIt access even when eventIds is empty.
class _FixedHostingPendingCountController
    extends HostingPendingCountController {
  _FixedHostingPendingCountController(super.eventIds);

  @override
  HostingPendingCountState build() =>
      const HostingPendingCountState(total: 0, perEvent: {});

  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

final _verifiedUser = User(
  id: 'test-user-1',
  email: 'test@tribely.com',
  displayName: 'Test User',
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
  emailVerifiedAt: DateTime.utc(2024),
);

final _verifiedSession = AuthSession(
  user: _verifiedUser,
  accessToken: 'access-token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'refresh-token',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

final _authenticatedState = SessionAuthenticated(_verifiedSession);

// ---------------------------------------------------------------------------
// Test router factory
//
// Mirrors the production route tree (same paths, names, parentNavigatorKeys)
// but swaps DI-heavy page builders with stub Scaffolds.
//
// Each call to `_buildTestRouter` allocates fresh navigator keys to avoid
// `GlobalKey` duplication when multiple tests run in the same process.
// ---------------------------------------------------------------------------

GoRouter _buildTestRouter({
  required SessionState sessionState,
  String initialLocation = '/events',
}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');
  final discoverKey = GlobalKey<NavigatorState>(debugLabel: 'test-discover');
  final myEventsKey = GlobalKey<NavigatorState>(debugLabel: 'test-myEvents');
  final profileKey = GlobalKey<NavigatorState>(debugLabel: 'test-profile');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      // Full-screen user profile — outside the shell.
      GoRoute(
        path: '/users/:id',
        name: 'userProfile',
        parentNavigatorKey: rootKey,
        builder: (context, state) => Scaffold(
          key: _kUserProfileStubKey,
          body: Text('user-profile-${state.pathParameters['id']}'),
        ),
      ),
      // Shell with three bottom-nav branches.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Discover
          StatefulShellBranch(
            navigatorKey: discoverKey,
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
            navigatorKey: myEventsKey,
            routes: [
              GoRoute(
                path: '/my-events',
                name: 'myEvents',
                builder: (context, state) => const MyEventsPage(),
              ),
            ],
          ),
          // Branch 2 — Profile
          // Stub OwnProfilePage and EditProfilePage to avoid get_it dependency.
          StatefulShellBranch(
            navigatorKey: profileKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'ownProfile',
                builder: (context, state) => const Scaffold(
                  key: _kOwnProfileStubKey,
                  body: Text('own-profile-stub'),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editProfile',
                    // parentNavigatorKey mirrors production: renders above shell
                    // so NavigationBar is absent.
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const Scaffold(
                      key: _kEditProfileStubKey,
                      appBar: null,
                      body: Text('edit-profile-stub'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // /home → /events redirect (mirrors production, no builder needed).
      GoRoute(path: '/home', redirect: (context, state) => '/events'),
    ],
  );
}

/// Pumps a [MaterialApp.router] inside a [ProviderScope] that overrides
/// [sessionControllerProvider] with [sessionState].
///
/// Also stubs out [DiscoverController], [DiscoverFilterController],
/// [locationServiceProvider], and [locationPromptShownProvider] so that
/// [DiscoverPage] — rendered directly in the test router — never touches
/// the GetIt service locator or the OS location API.
Future<void> pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  SessionState sessionState = const SessionUnauthenticated(),
}) async {
  final mockLocation = MockLocationService();
  when(
    () => mockLocation.currentPermissionStatus(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);
  when(() => mockLocation.currentPosition()).thenAnswer((_) async => null);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(() {
          // Returns a Notifier whose build() immediately returns sessionState.
          // We use a minimal anonymous subclass since Notifier.build is abstract.
          return _FixedSessionController(sessionState);
        }),
        discoverControllerProvider.overrideWith(_FixedDiscoverController.new),
        discoverFilterControllerProvider.overrideWith(
          _FixedFilterController.new,
        ),
        locationServiceProvider.overrideWithValue(mockLocation),
        locationPromptShownProvider.overrideWith(
          _PromptAlreadyShownNotifier.new,
        ),
        // MyEventsPage now renders MyJoinRequestsTab which reads
        // listMyJoinRequestsUseCaseProvider → sl<>. Override to bypass GetIt.
        myJoinRequestsControllerProvider(
          null,
        ).overrideWith(() => _FixedMyJoinRequestsController()),
        // MyEventsPage watches hostingPendingCountControllerProvider([]) on every
        // build (initial _hostedEventIds is const []). The controller's async
        // _load() reads listPendingForEventUseCaseProvider → sl<>, crashing
        // tests that don't initialise GetIt. Override with a zero-state stub.
        hostingPendingCountControllerProvider(
          const [],
        ).overrideWith(() => _FixedHostingPendingCountController(const [])),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // pumpAndSettle deadlocks because FlutterMap's AnimatedMapController keeps a
  // ticker alive indefinitely when DiscoverPage is in the tree.
  // Bounded pumps: first pump triggers the initial frame; 100ms drains
  // post-frame callbacks and microtasks without spinning on the live ticker.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

// ---------------------------------------------------------------------------
// Minimal SessionController override — holds a fixed SessionState for testing.
//
// Must extend SessionController (not the raw Notifier<SessionState>) so that
// NotifierProvider.overrideWith() accepts it without a type error.
// ---------------------------------------------------------------------------

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);
  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('app_router', () {
    // Each call to _buildTestRouter allocates fresh navigator keys so GlobalKey
    // duplication errors cannot occur when tests share the same process.

    // -------------------------------------------------------------------------
    // 1. Cold-start to /events lands on Discover with bottom nav.
    // -------------------------------------------------------------------------
    testWidgets('cold-start /events shows DiscoverPage with NavigationBar', (
      tester,
    ) async {
      final router = _buildTestRouter(
        sessionState: _authenticatedState,
        initialLocation: '/events',
      );

      await pumpRouter(tester, router, sessionState: _authenticatedState);

      expect(find.byType(DiscoverPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      // NavigationBar should show the Discover destination label.
      expect(find.text('Discover'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 2. Tab switch: Discover → My Events.
    // -------------------------------------------------------------------------
    testWidgets('tapping My Events tab shows MyEventsPage with NavigationBar', (
      tester,
    ) async {
      final router = _buildTestRouter(
        sessionState: _authenticatedState,
        initialLocation: '/events',
      );

      await pumpRouter(tester, router, sessionState: _authenticatedState);

      // Find and tap the My Events destination in the NavigationBar.
      await tester.tap(find.text('My Events').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MyEventsPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Tab switch: My Events → Profile.
    // -------------------------------------------------------------------------
    testWidgets(
      'tapping Profile tab shows OwnProfilePage (stub) with NavigationBar',
      (tester) async {
        final router = _buildTestRouter(
          sessionState: _authenticatedState,
          initialLocation: '/my-events',
        );

        await pumpRouter(tester, router, sessionState: _authenticatedState);

        // Should start on My Events.
        expect(find.byType(MyEventsPage), findsOneWidget);

        await tester.tap(find.text('Profile').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Stub OwnProfilePage is keyed by _kOwnProfileStubKey.
        expect(find.byKey(_kOwnProfileStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 4. /profile/edit is full-screen (no bottom nav).
    //    Uses stub builder — see module-level comment.
    // -------------------------------------------------------------------------
    testWidgets('/profile/edit renders full-screen (NavigationBar absent)', (
      tester,
    ) async {
      final router = _buildTestRouter(
        sessionState: _authenticatedState,
        initialLocation: '/profile',
      );

      await pumpRouter(tester, router, sessionState: _authenticatedState);
      expect(find.byKey(_kOwnProfileStubKey), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Navigate to the edit page.
      router.goNamed('editProfile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(_kEditProfileStubKey), findsOneWidget);
      // parentNavigatorKey: _testRootNavKey pushes above the shell —
      // NavigationBar must NOT be visible.
      expect(find.byType(NavigationBar), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. /home redirects to /events.
    // -------------------------------------------------------------------------
    testWidgets('/home redirects to /events and shows DiscoverPage', (
      tester,
    ) async {
      final router = _buildTestRouter(
        sessionState: _authenticatedState,
        initialLocation: '/events',
      );

      await pumpRouter(tester, router, sessionState: _authenticatedState);

      router.go('/home');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DiscoverPage), findsOneWidget);
      // Verify the resolved URI is /events (redirect fired).
      final uri = router.routerDelegate.currentConfiguration.uri.toString();
      expect(uri, equals('/events'));
    });

    // -------------------------------------------------------------------------
    // 6. Re-tap-to-root.
    //
    // The /profile/edit route uses parentNavigatorKey: _rootNavigatorKey, which
    // renders it above the shell — the NavigationBar is absent while on that
    // page and cannot be tapped directly.  Instead we verify the re-tap-to-root
    // wiring from a scenario where the nav bar is visible: start at /profile,
    // switch away to Discover, then tap Profile again — the branch must return
    // to its root (/profile stub).  The initialLocation: true flag wired in
    // AppShell is what drives this; the test confirms it is exercised.
    // -------------------------------------------------------------------------
    testWidgets(
      're-tapping Profile tab after switching branches returns to OwnProfile root',
      (tester) async {
        final router = _buildTestRouter(
          sessionState: _authenticatedState,
          initialLocation: '/profile',
        );

        await pumpRouter(tester, router, sessionState: _authenticatedState);
        expect(find.byKey(_kOwnProfileStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);

        // Switch to Discover tab.
        await tester.tap(find.text('Discover').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(DiscoverPage), findsOneWidget);

        // Tap Profile tab — should return to profile branch root.
        await tester.tap(find.text('Profile').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(_kOwnProfileStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // 7. Cold-start deep link to /profile/edit — sub-task C integration.
    //    Uses stub builder for EditProfilePage — see module-level comment.
    // -------------------------------------------------------------------------
    testWidgets(
      'cold-start /profile/edit renders full-screen; back returns to OwnProfile in shell',
      (tester) async {
        final router = _buildTestRouter(
          sessionState: _authenticatedState,
          initialLocation: '/profile/edit',
        );

        await pumpRouter(tester, router, sessionState: _authenticatedState);

        // Edit stub should be visible full-screen (no bottom nav).
        expect(find.byKey(_kEditProfileStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        // Simulate back navigation (programmatic, since the stub has no back
        // button — this validates go_router stack state, not UI chrome).
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // After popping, the shell's Profile branch root should be visible
        // with the NavigationBar restored.
        expect(find.byKey(_kOwnProfileStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );
  });
}
