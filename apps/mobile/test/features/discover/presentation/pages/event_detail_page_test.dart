// Widget tests for EventDetailPage.
//
// Covers:
//   1. Loading state    — _LoadingSkeleton is rendered.
//   2. Loaded state     — event data is rendered; CTA is tappable + fires SnackBar.
//   3. Error state      — error icon + message + "Try again" button.
//   4. NotFound state   — "no longer exists" copy.
//   5. CTA SnackBar     — exact message copy per §F / Step 8.5.
//   6. Router           — /events/:id routes to EventDetailPage OUTSIDE the
//                         StatefulShellRoute (no NavigationBar visible).
//
// Mocking strategy:
//   - `eventDetailControllerProvider` is overridden per test via
//     ProviderScope.overrides. Each override installs a _FixedEventDetailController
//     that returns a predetermined state from build().
//   - GetIt / service locator is never initialised — all DI goes through
//     provider overrides, keeping tests hermetic.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/router/app_shell.dart';
import 'package:tribely/src/core/services/location_service.dart';
import 'package:tribely/src/core/services/location_service_providers.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/core/widgets/skeleton_loader.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/event_detail_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_page.dart';
import 'package:tribely/src/features/discover/presentation/pages/event_detail_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_map_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/event_detail_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/discover/presentation/state/event_detail_state.dart';
import 'package:tribely/src/features/events/domain/entities/event.dart';
import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/core/error/failures.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _testEvent = Event(
  id: 'evt-abc123',
  hostId: 'user-host-1',
  title: 'Sunset Drinks at Rooftop',
  description: 'Casual drinks with great views.',
  venue: const EventVenue(
    address: '1 Marina Blvd',
    city: 'Singapore',
    latitude: 1.2789,
    longitude: 103.8536,
  ),
  startsAt: DateTime.utc(2026, 6, 1, 18, 0),
  endsAt: DateTime.utc(2026, 6, 1, 21, 0),
  capacity: 12,
  category: EventCategory.drinks,
  costSplit: 'own',
  approvalMode: 'manual',
  status: 'published',
  createdAt: DateTime.utc(2026, 5, 1),
);

const _testEventId = 'evt-abc123';

// ---------------------------------------------------------------------------
// Router test mocks and stubs
// ---------------------------------------------------------------------------

class MockLocationService extends Mock implements LocationService {}

/// Fixed-state [DiscoverController] that bypasses the use case / GetIt graph.
class _FixedDiscoverController extends DiscoverController {
  @override
  DiscoverState build() => const DiscoverLoading();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

/// Fixed-state [DiscoverFilterController] that returns the initial filter state
/// without starting any debounce timer.
class _FixedFilterController extends DiscoverFilterController {
  @override
  DiscoverFilterState build() => const DiscoverFiltersActive();
}

/// Fixed-state [LocationPromptShownNotifier] that reports prompt shown so the
/// map tab skips the location rationale bottom sheet during tests.
class _PromptAlreadyShownNotifier extends LocationPromptShownNotifier {
  @override
  bool build() => true;
}

// ---------------------------------------------------------------------------
// Fixed-state controller helpers
// ---------------------------------------------------------------------------

/// A controller that always returns [_state] from build() without calling the
/// use case. Allows each test to inject a predetermined state.
class _FixedEventDetailController extends EventDetailController {
  _FixedEventDetailController(this._state) : super(_testEventId);
  final EventDetailState _state;

  @override
  EventDetailState build() => _state;

  @override
  Future<void> retry() async {
    // no-op in tests — state transition is verified via provider override.
  }
}

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps [EventDetailPage] inside a ProviderScope + MaterialApp with the given
/// controller state override.
///
/// [sessionState] defaults to [SessionUnauthenticated] — pass an
/// [SessionAuthenticated] instance to test the host-viewer CTA gating.
Future<void> _pumpPage(
  WidgetTester tester, {
  required String eventId,
  required EventDetailState initialState,
  SessionState sessionState = const SessionUnauthenticated(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventDetailControllerProvider(
          eventId,
        ).overrideWith(() => _FixedEventDetailController(initialState)),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
      ],
      child: MaterialApp(home: EventDetailPage(eventId: eventId)),
    ),
  );
  await tester.pump(); // allow microtask (Future(() => _load())) to schedule
}

// ---------------------------------------------------------------------------
// Router fixtures — mirrors app_router_test.dart stub-builder pattern
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

const _kEventDetailStubKey = Key('__stub_event_detail__');

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);
  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

/// Builds a test-scoped GoRouter that includes the /events/:id route outside
/// the shell (matching production app_router.dart), using stub builders for
/// pages that require get_it DI.
GoRouter _buildTestRouter({String initialLocation = '/events'}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');
  final discoverKey = GlobalKey<NavigatorState>(debugLabel: 'test-discover');
  final myEventsKey = GlobalKey<NavigatorState>(debugLabel: 'test-myEvents');
  final profileKey = GlobalKey<NavigatorState>(debugLabel: 'test-profile');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      // Full-screen event detail — OUTSIDE the shell (parentNavigatorKey = root).
      GoRoute(
        path: '/events/:id',
        name: 'eventDetail',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return Scaffold(
            key: _kEventDetailStubKey,
            body: Text('event-detail-$eventId'),
          );
        },
      ),
      // Shell with three bottom-nav branches (minimal — only Discover matters).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: discoverKey,
            routes: [
              GoRoute(
                path: '/events',
                name: 'discover',
                builder: (_, _) => const DiscoverPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: myEventsKey,
            routes: [
              GoRoute(
                path: '/my-events',
                name: 'myEvents',
                builder: (_, _) => const Scaffold(body: Text('my-events-stub')),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'ownProfile',
                builder: (_, _) => const Scaffold(body: Text('profile-stub')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  required SessionState sessionState,
}) async {
  // DiscoverPage is rendered inside the shell at '/events'. It mounts
  // DiscoverController (→ browseEventsUseCaseProvider → sl<>) and
  // DiscoverMapTab (→ locationService + permission sheet). All three need
  // stubs so the router tests remain hermetic without initialising GetIt.
  final mockLocation = MockLocationService();
  when(
    () => mockLocation.currentPermissionStatus(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);
  when(() => mockLocation.currentPosition()).thenAnswer((_) async => null);

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
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // pumpAndSettle deadlocks because FlutterMap's AnimatedMapController keeps a
  // ticker alive indefinitely. Use bounded pumps: first pump triggers the
  // initial frame; the 100ms pump drains post-frame callbacks and microtasks.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EventDetailPage', () {
    // -----------------------------------------------------------------------
    // 1. Loading state
    // -----------------------------------------------------------------------
    testWidgets('Loading state renders SkeletonLoader widgets', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: const EventDetailLoading(),
      );

      // Loading skeleton must include at least one SkeletonLoader.
      expect(find.byType(SkeletonLoader), findsWidgets);
      // No event data should be visible.
      expect(find.text('Sunset Drinks at Rooftop'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 2. Loaded state
    // -----------------------------------------------------------------------
    testWidgets('Loaded state renders event title and CTA', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      // Title visible.
      expect(find.text('Sunset Drinks at Rooftop'), findsOneWidget);
      // CTA visible.
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Request to join'), findsOneWidget);
    });

    testWidgets('Loaded state renders category badge', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      expect(find.text('Drinks'), findsOneWidget);
    });

    testWidgets('Loaded state renders venue address', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      expect(find.textContaining('1 Marina Blvd'), findsOneWidget);
    });

    testWidgets('Loaded state renders description', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      expect(find.text('Casual drinks with great views.'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 3. CTA SnackBar — exact copy per §F + Step 8.5
    // -----------------------------------------------------------------------
    testWidgets('tapping CTA fires SnackBar with exact message', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump(); // trigger SnackBar animation

      expect(
        find.text("Join requests are coming soon — you'll be first to know."),
        findsOneWidget,
      );
    });

    testWidgets('CTA is tappable (onPressed is non-null)', (tester) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
      );

      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      // Per §F: CTA is NEVER disabled — onPressed must be wired.
      expect(button.onPressed, isNotNull);
      expect(button.state, equals(PrimaryButtonState.idle));
    });

    // -----------------------------------------------------------------------
    // 4. Error state
    // -----------------------------------------------------------------------
    testWidgets('Error state renders message and Try again button', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: const EventDetailError(
          ServerFailure('Something went wrong.', statusCode: 500),
        ),
      );

      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      // CTA should NOT appear in error state.
      expect(find.byType(PrimaryButton), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 5. NotFound state
    // -----------------------------------------------------------------------
    testWidgets('NotFound state renders "no longer exists" copy', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: const EventDetailNotFound(),
      );

      expect(find.text('This event no longer exists.'), findsOneWidget);
      // CTA should NOT appear in not-found state.
      expect(find.byType(PrimaryButton), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 6. Role-aware CTA gating
    // -----------------------------------------------------------------------

    testWidgets('host viewer (session.user.id == event.hostId) → CTA absent', (
      tester,
    ) async {
      // The authenticated user IS the event host.
      final hostSession = AuthSession(
        user: User(
          id: 'user-host-1', // matches _testEvent.hostId
          email: 'host@tribely.com',
          displayName: 'Host User',
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
          emailVerifiedAt: DateTime.utc(2024),
        ),
        accessToken: 'token',
        accessTokenExpiresAt: DateTime.utc(2099),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: DateTime.utc(2099),
      );

      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
        sessionState: SessionAuthenticated(hostSession),
      );

      // CTA must be absent — no empty button slot for the host viewer.
      expect(find.text('Request to join'), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('non-host authenticated viewer → CTA renders', (tester) async {
      // Authenticated but different user from the event host.
      final otherSession = AuthSession(
        user: User(
          id: 'user-other-99', // different from _testEvent.hostId
          email: 'other@tribely.com',
          displayName: 'Other User',
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
          emailVerifiedAt: DateTime.utc(2024),
        ),
        accessToken: 'token',
        accessTokenExpiresAt: DateTime.utc(2099),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: DateTime.utc(2099),
      );

      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
        sessionState: SessionAuthenticated(otherSession),
      );

      expect(find.text('Request to join'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('unauthenticated viewer → CTA renders (default)', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        eventId: _testEventId,
        initialState: EventDetailLoaded(_testEvent),
        sessionState: const SessionUnauthenticated(),
      );

      expect(find.text('Request to join'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 7. Host display name rendering
    // -----------------------------------------------------------------------

    testWidgets(
      'event.hostDisplayName non-null → "Hosted by <name>" rendered',
      (tester) async {
        final eventWithHostName = _testEvent.copyWith(hostDisplayName: 'Alice');

        await _pumpPage(
          tester,
          eventId: _testEventId,
          initialState: EventDetailLoaded(eventWithHostName),
        );

        expect(find.text('Hosted by Alice'), findsOneWidget);
      },
    );

    testWidgets(
      'event.hostDisplayName null → "Hosted by Host" fallback rendered',
      (tester) async {
        // _testEvent has no hostDisplayName set (null by default).
        await _pumpPage(
          tester,
          eventId: _testEventId,
          initialState: EventDetailLoaded(_testEvent),
        );

        expect(find.text('Hosted by Host'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Router tests — /events/:id outside the ShellRoute
  // -------------------------------------------------------------------------
  group('Router: /events/:id', () {
    testWidgets(
      'navigating to /events/abc123 renders outside the shell (no NavigationBar)',
      (tester) async {
        final router = _buildTestRouter(initialLocation: '/events/abc123');

        await _pumpRouter(tester, router, sessionState: _authenticatedState);

        // The stub event-detail page must be visible.
        expect(find.byKey(_kEventDetailStubKey), findsOneWidget);
        expect(find.textContaining('event-detail-abc123'), findsOneWidget);

        // Must NOT be inside the shell — NavigationBar must be absent.
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets(
      'navigating from /events to /events/abc123 hides NavigationBar',
      (tester) async {
        final router = _buildTestRouter(initialLocation: '/events');

        await _pumpRouter(tester, router, sessionState: _authenticatedState);

        // Shell with NavigationBar is visible on /events.
        expect(find.byType(NavigationBar), findsOneWidget);

        // Navigate to detail.
        unawaited(router.push('/events/abc123'));
        await tester.pump();
        // Allow the route push animation to complete (default ~300ms) without
        // calling pumpAndSettle (which deadlocks on the FlutterMap ticker).
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(_kEventDetailStubKey), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('popping /events/:id from the stack restores NavigationBar', (
      tester,
    ) async {
      final router = _buildTestRouter(initialLocation: '/events');

      await _pumpRouter(tester, router, sessionState: _authenticatedState);

      unawaited(router.push('/events/abc123'));
      await tester.pump();
      // Allow the push animation to fully complete before asserting.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationBar), findsNothing);

      router.pop();
      await tester.pump();
      // Allow the pop animation to fully complete before asserting.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DiscoverPage), findsOneWidget);
    });
  });
}
