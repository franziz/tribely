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
import 'package:tribely/src/features/discover/presentation/controllers/event_detail_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_map_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/event_detail_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/discover/presentation/state/event_detail_state.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/host_attending_list_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/host_pending_list_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/my_join_requests_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/request_to_join_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_attending_list_state.dart';
import 'package:tribely/src/features/join_requests/presentation/state/host_pending_list_state.dart';
import 'package:tribely/src/features/join_requests/presentation/state/my_join_requests_state.dart';
import 'package:tribely/src/features/join_requests/presentation/state/request_to_join_state.dart';
import 'package:tribely/src/features/users/domain/entities/user_capabilities.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_pending_count_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_tab_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/my_events_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/pending_review_banner_controller.dart';
import 'package:tribely/src/features/my_events/presentation/pages/my_events_page.dart';
import 'package:tribely/src/features/my_events/presentation/state/hosting_tab_state.dart';
import 'package:tribely/src/features/my_events/presentation/state/my_events_state.dart';
import 'package:tribely/src/features/my_events/presentation/state/pending_review_banner_state.dart';
import 'package:tribely/src/features/help_centre/presentation/pages/help_article_page.dart';
import 'package:tribely/src/core/router/app_router.dart';

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
/// MyEventsPage watches hostingPendingCountControllerProvider('') (empty key)
/// on every build. Without this override the controller's scheduled async
/// _load() crashes on GetIt access even when eventIds is empty.
class _FixedHostingPendingCountController
    extends HostingPendingCountController {
  _FixedHostingPendingCountController(super.eventIdsKey);

  @override
  HostingPendingCountState build() =>
      const HostingPendingCountState(total: 0, perEvent: {});

  @override
  Future<void> refresh() async {}
}

/// Bypasses HostingTabController's _load() which reads
/// listMyHostedEventsUseCaseProvider → sl<>. Returns an empty loaded state
/// immediately so MyEventsPage can render in router tests without GetIt.
class _FixedHostingTabController extends HostingTabController {
  @override
  HostingTabState build() => const HostingTabLoaded(events: []);
}

/// Bypasses MyEventsController's async load() which reads
/// listMyHostedEventsUseCaseProvider → sl<>. Returns an empty loaded state
/// immediately so MyEventsPage can render in router tests without GetIt.
///
/// MyEventsPage watches myEventsControllerProvider on every build to derive
/// the pending-count key. Without this override the scheduled async load()
/// crashes on GetIt access even when the event list is empty.
class _FixedMyEventsController extends MyEventsController {
  @override
  MyEventsState build() => const MyEventsLoaded(hostedEventIds: []);

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}
}

/// Bypasses PendingReviewBannerController's async _fetchIfEligible() which
/// reads getPendingReviewPromptUseCaseProvider → sl<>. Returns None
/// immediately so MyEventsPage renders without crashing on GetIt access.
class _FixedPendingReviewBannerController
    extends PendingReviewBannerController {
  @override
  PendingReviewBannerState build() => const PendingReviewBannerNone();

  @override
  void dismiss() {}

  @override
  void onComposerNavigated() {}
}

// ---------------------------------------------------------------------------
// EventDetailPage stubs — prevent GetIt access when /events/:id is rendered
// in router tests (TRI-290: the page is now reachable unauthenticated).
// ---------------------------------------------------------------------------

/// Synchronously resolves to the given [UserCapabilities]. Mirrors the
/// equivalent class in event_detail_sticky_bar_test.dart.
class _FakeMyCapabilitiesNotifier extends MyCapabilitiesNotifier {
  _FakeMyCapabilitiesNotifier(this._caps);
  final UserCapabilities _caps;

  @override
  Future<UserCapabilities> build() async => _caps;
}

/// Bypasses EventDetailController's use-case fetch (which calls sl<>) so that
/// the /events/:id route can be rendered in router tests without GetIt.
class _FixedEventDetailController extends EventDetailController {
  _FixedEventDetailController(super.eventId, this._state);
  final EventDetailState _state;

  @override
  EventDetailState build() => _state;

  @override
  Future<void> retry() async {}
}

/// Bypasses RequestToJoinController's use-case fetch for router tests.
/// Keeps the existing-request state at Idle with no request (SessionUnauthenticated
/// guard in loadExisting() handles this in prod; stub avoids any timer leak).
class _FixedRequestToJoinRouterController extends RequestToJoinController {
  _FixedRequestToJoinRouterController(super.eventId);

  @override
  RequestToJoinState build() => const RequestToJoinIdle();

  @override
  Future<void> loadExisting() async {}

  @override
  Future<void> submit({bool acknowledgedSafetyReminder = false}) async {}

  @override
  Future<void> withdraw(String joinRequestId) async {}
}

/// Bypasses HostPendingListController's _load() for router tests.
class _FixedHostPendingListRouterController extends HostPendingListController {
  _FixedHostPendingListRouterController(super.eventId);

  @override
  HostPendingListState build() => const HostPendingListLoaded(items: []);

  @override
  Future<void> retry() async {}

  @override
  Future<void> load() async {}

  @override
  Future<void> approve(String joinRequestId) async {}

  @override
  Future<void> decline(String joinRequestId, {String? reason}) async {}

  @override
  void clearSectionError() {}

  @override
  void clearRaceConflict() {}
}

/// Bypasses HostAttendingListController's _load() for router tests.
class _FixedHostAttendingListRouterController
    extends HostAttendingListController {
  _FixedHostAttendingListRouterController(super.eventId);

  @override
  HostAttendingListState build() => const HostAttendingListLoaded(items: []);

  @override
  Future<void> retry() async {}
}

/// Minimal event fixture for the /events/:id router test. Content is irrelevant
/// (the test only checks the URI); the event must be future-dated + published
/// so EventDetailPage builds without error-state branches.
const _kRouterTestEventId = 'evt-demo-1';
final _routerTestEvent = Event(
  id: _kRouterTestEventId,
  hostId: 'host-1',
  title: 'Router Test Event',
  description: 'A minimal event for router tests.',
  venue: const EventVenue(
    address: '1 Orchard Rd',
    city: 'Singapore',
    latitude: 1.3,
    longitude: 103.8,
    category: 'restaurant',
  ),
  startsAt: DateTime.utc(2099, 6, 1, 18, 0),
  endsAt: DateTime.utc(2099, 6, 1, 21, 0),
  capacity: 8,
  category: EventCategory.drinks,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 1, 1),
  hostIsVerified: false,
);

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
        // MyEventsPage watches hostingPendingCountControllerProvider('') on every
        // build (initial _hostedEventIds is const [], sorted-join key is '').
        // The controller's async _load() reads listPendingForEventUseCaseProvider
        // → sl<>, crashing tests that don't initialise GetIt. Override with a
        // zero-state stub.
        hostingPendingCountControllerProvider(
          '',
        ).overrideWith(() => _FixedHostingPendingCountController('')),
        // HostingTabController's async _load() reads
        // listMyHostedEventsUseCaseProvider → sl<>, crashing tests that don't
        // initialise GetIt. Override with an empty loaded-state stub.
        hostingTabControllerProvider.overrideWith(
          _FixedHostingTabController.new,
        ),
        // MyEventsController's async load() reads
        // listMyHostedEventsUseCaseProvider → sl<>, crashing tests that don't
        // initialise GetIt. Override with an empty loaded-state stub.
        myEventsControllerProvider.overrideWith(_FixedMyEventsController.new),
        // PendingReviewBannerController's _fetchIfEligible() reads
        // getPendingReviewPromptUseCaseProvider → sl<>. Override with a None
        // stub so MyEventsPage renders without crashing on GetIt access.
        pendingReviewBannerControllerProvider.overrideWith(
          _FixedPendingReviewBannerController.new,
        ),
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
// Production-router pump helper — uses appRouterProvider with redirect logic.
//
// Compared to [pumpRouter] (which uses a simplified test router without
// redirect), this helper exercises the real GoRouter redirect callback so
// session-driven route guards can be asserted.
// ---------------------------------------------------------------------------

Future<GoRouter> pumpProductionRouter(
  WidgetTester tester, {
  required SessionState sessionState,
  required String initialLocation,
}) async {
  final mockLocation = MockLocationService();
  when(
    () => mockLocation.currentPermissionStatus(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);
  when(() => mockLocation.currentPosition()).thenAnswer((_) async => null);

  late GoRouter capturedRouter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        discoverControllerProvider.overrideWith(_FixedDiscoverController.new),
        discoverFilterControllerProvider.overrideWith(
          _FixedFilterController.new,
        ),
        locationServiceProvider.overrideWithValue(mockLocation),
        locationPromptShownProvider.overrideWith(
          _PromptAlreadyShownNotifier.new,
        ),
        myJoinRequestsControllerProvider(
          null,
        ).overrideWith(() => _FixedMyJoinRequestsController()),
        hostingPendingCountControllerProvider(
          '',
        ).overrideWith(() => _FixedHostingPendingCountController('')),
        hostingTabControllerProvider.overrideWith(
          _FixedHostingTabController.new,
        ),
        myEventsControllerProvider.overrideWith(_FixedMyEventsController.new),
        pendingReviewBannerControllerProvider.overrideWith(
          _FixedPendingReviewBannerController.new,
        ),
        // TRI-290: /events/:id is now reachable unauthenticated; stub the
        // providers EventDetailPage watches so GetIt is never touched.
        // The override is keyed to _kRouterTestEventId — only the
        // B5-Q2-7 test navigates to this id; other tests are unaffected.
        eventDetailControllerProvider(_kRouterTestEventId).overrideWith(
          () => _FixedEventDetailController(
            _kRouterTestEventId,
            EventDetailLoaded(_routerTestEvent),
          ),
        ),
        requestToJoinControllerProvider(_kRouterTestEventId).overrideWith(
          () => _FixedRequestToJoinRouterController(_kRouterTestEventId),
        ),
        hostPendingListControllerProvider(_kRouterTestEventId).overrideWith(
          () => _FixedHostPendingListRouterController(_kRouterTestEventId),
        ),
        hostAttendingListControllerProvider(_kRouterTestEventId).overrideWith(
          () => _FixedHostAttendingListRouterController(_kRouterTestEventId),
        ),
        myCapabilitiesProvider.overrideWith(
          () => _FakeMyCapabilitiesNotifier(
            const UserCapabilities(
              canPostPrivateVenue: false,
              safetyReminderSeen: true,
            ),
          ),
        ),
        selfieGatingStateProvider.overrideWithValue(
          const SelfieGatingApproved(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          capturedRouter = ref.watch(appRouterProvider);
          // Override initialLocation by imperatively navigating after build.
          return MaterialApp.router(routerConfig: capturedRouter);
        },
      ),
    ),
  );

  // Navigate to the desired initial location after the router is mounted.
  capturedRouter.go(initialLocation);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  return capturedRouter;
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

    // -------------------------------------------------------------------------
    // B5-Q2 regression: /help/* must NOT bounce authenticated users.
    //
    // These four tests exercise the real production redirect callback via
    // [pumpProductionRouter]. The redirect bug (isAuthFlow = isPublic alias)
    // caused authenticated users navigating to /help/article/:id to be
    // bounced to /events.
    // -------------------------------------------------------------------------

    // B5-Q2-1: Authenticated verified user → /help/article/:id stays on article.
    testWidgets(
      'B5-Q2: authenticated user navigating to /help/article/:id is NOT bounced to /events',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: _authenticatedState,
          initialLocation: '/help/article/report-faq',
        );

        // The redirect must not have fired — location must still be the article.
        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/help/article/report-faq'),
          reason:
              'Authenticated user must reach /help/article/report-faq; '
              'isAuthFlow must not include /help/* (regression guard for B5-Q2)',
        );
        expect(find.byType(HelpArticleScreen), findsOneWidget);
      },
    );

    // B5-Q2-2: Authenticated verified user → /sign-in is bounced to /events.
    testWidgets(
      'B5-Q2: authenticated user navigating to /sign-in is redirected to /events',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: _authenticatedState,
          initialLocation: '/sign-in',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/events'),
          reason:
              'Auth-wizard route /sign-in must redirect authenticated users '
              'to /events (isAuthFlow must still include /sign-in)',
        );
      },
    );

    // B5-Q2-3: Unauthenticated user → /help/article/:id stays on article.
    testWidgets(
      'B5-Q2: unauthenticated user navigating to /help/article/:id is NOT bounced to /welcome',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: const SessionUnauthenticated(),
          initialLocation: '/help/article/report-faq',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/help/article/report-faq'),
          reason:
              'Unauthenticated user must reach /help/article/report-faq; '
              '/help/* must remain in publicRoutes',
        );
        expect(find.byType(HelpArticleScreen), findsOneWidget);
      },
    );

    // B5-Q2-4: TRI-290 — Unauthenticated user → /events stays on /events (positive pole).
    testWidgets(
      'B5-Q2: unauthenticated user navigating to /events is NOT bounced to /welcome',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: const SessionUnauthenticated(),
          initialLocation: '/events',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/events'),
          reason:
              'TRI-290: /events is a public read route; unauthenticated users '
              'browse it without a bounce.',
        );
      },
    );

    // B5-Q2-5: TRI-290 footgun-lock — /events/new stays auth-walled.
    testWidgets(
      'B5-Q2: unauthenticated user navigating to /events/new is redirected to /welcome',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: const SessionUnauthenticated(),
          initialLocation: '/events/new',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/welcome'),
          reason:
              'create-event wizard stays auth-walled '
              '(read-route predicate must not match /events/new).',
        );
      },
    );

    // B5-Q2-6: TRI-290 footgun-lock — /events/new/phone-gate stays auth-walled.
    testWidgets(
      'B5-Q2: unauthenticated user navigating to /events/new/phone-gate is redirected to /welcome',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: const SessionUnauthenticated(),
          initialLocation: '/events/new/phone-gate',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/welcome'),
          reason: 'phone-gate stays auth-walled.',
        );
      },
    );

    // B5-Q2-7: TRI-290 — Unauthenticated user → /events/:id stays on the detail route.
    testWidgets(
      'B5-Q2: unauthenticated user navigating to /events/:id is NOT bounced to /welcome',
      (tester) async {
        final router = await pumpProductionRouter(
          tester,
          sessionState: const SessionUnauthenticated(),
          initialLocation: '/events/$_kRouterTestEventId',
        );

        final uri = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          uri,
          equals('/events/$_kRouterTestEventId'),
          reason:
              'TRI-290: /events/:id is a public read route; unauthenticated '
              'users reach the event detail page without a bounce.',
        );
      },
    );
  });
}
