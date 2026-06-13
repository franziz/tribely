// Widget tests for DiscoverPage scaffold (D5).
//
// Covers:
//   1. IndexedStack has both DiscoverListTab and DiscoverMapTab mounted at start.
//   2. Switching selectedTab to map updates the IndexedStack index (tab switcher
//      is wired through the scaffold state).
//   3. Sticky CTA "Create event" button is visible regardless of selected tab.
//   4. Tapping the CTA (authenticated) navigates to '/events/new' (mocked GoRouter).
//   5. FilterChipRow is rendered above the tab content on both tabs.
//   6. TRI-72 Brief C: signed-out tap opens sign-in gate sheet (not /events/new).
//   7. TRI-72 Brief C: authenticated tap pushes /events/new directly.
//
// Mocking strategy:
//   - [discoverControllerProvider] overridden with a fixed DiscoverLoading stub.
//   - [discoverFilterControllerProvider] overridden with a fixed filter stub.
//   - [sessionControllerProvider] overridden via _FixedSessionController.
//   - [signInGateControllerProvider] overridden with a stub that returns
//     SignInGateIdle to prevent GetIt access when the sheet opens.
//   - [locationServiceProvider] overridden with a MockLocationService that
//     returns null position (avoids real OS dialog; camera init is manual-smoke
//     territory per §Step 8.5).
//   - GoRouter wired via [MaterialApp.router] with [GoRouter] pointing to
//     '/' → DiscoverPage, so context.push('/events/new') can be asserted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/services/location_service.dart';
import 'package:tribely/src/core/services/location_service_providers.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/sign_in_gate_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_gate_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_intent.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_controller.dart';
import 'package:tribely/src/features/discover/presentation/controllers/discover_filter_controller.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_list_tab.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_map_tab.dart';
import 'package:tribely/src/features/discover/presentation/pages/discover_page.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_filter_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_map_providers.dart';
import 'package:tribely/src/features/discover/presentation/providers/discover_providers.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_filter_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';
import 'package:tribely/src/features/discover/presentation/widgets/discover_tab_switcher.dart';
import 'package:tribely/src/features/discover/presentation/widgets/filter_chip_row.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockLocationService extends Mock implements LocationService {}

// ---------------------------------------------------------------------------
// Session fixtures
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
// Fixed-state controllers
// ---------------------------------------------------------------------------

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

/// Fixed-state [LocationPromptShownNotifier] that always reports prompt shown
/// so widget tests skip the location rationale bottom sheet inside
/// [DiscoverMapTab].
class _PromptAlreadyShownNotifier extends LocationPromptShownNotifier {
  @override
  bool build() => true;
}

/// Fixed [SessionController] that avoids GetIt access in tests.
///
/// Must extend [SessionController] (not `Notifier<SessionState>`) because
/// [sessionControllerProvider]'s `overrideWith` expects the exact notifier type.
class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);
  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

/// Fixed [SignInGateController] that returns [SignInGateIdle] without touching
/// GetIt. Required whenever the sign-in gate sheet is opened in tests.
class _FixedSignInGateController extends SignInGateController {
  _FixedSignInGateController(super.intent);

  @override
  SignInGateState build() => const SignInGateIdle();

  @override
  Future<void> submit({required String email, required String password}) async {}
}

// ---------------------------------------------------------------------------
// Router + pump helper
// ---------------------------------------------------------------------------

/// Destination recorded when the CTA is tapped.
String? _lastPushedRoute;

/// Builds a [GoRouter] rooted at '/' → [DiscoverPage], with a capture route
/// for '/events/new' so the test can assert the navigation target without
/// needing a real CreateEventPage.
GoRouter _buildRouter() {
  _lastPushedRoute = null;
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DiscoverPage()),
      GoRoute(
        path: '/events/new',
        builder: (context, state) {
          _lastPushedRoute = '/events/new';
          return const Scaffold(body: Text('Create event page'));
        },
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) =>
            const Scaffold(body: Text('Sign up stub')),
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  MockLocationService? locationService,
  SessionState sessionState = const SessionUnauthenticated(),
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final mockLocation = locationService ?? MockLocationService();
  // Default: permission denied, no position — avoids real OS dialog.
  when(
    () => mockLocation.currentPermissionStatus(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);
  when(() => mockLocation.currentPosition()).thenAnswer((_) async => null);
  when(
    () => mockLocation.requestPermission(),
  ).thenAnswer((_) async => LocationPermissionStatus.denied);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        discoverControllerProvider.overrideWith(_FixedDiscoverController.new),
        discoverFilterControllerProvider.overrideWith(
          _FixedFilterController.new,
        ),
        locationServiceProvider.overrideWithValue(mockLocation),
        // Suppress the location-rationale bottom sheet — DiscoverMapTab is
        // mounted inside the IndexedStack even when the List tab is active.
        // Without this override, _initCamera() tries to show a non-dismissable
        // modal sheet (isDismissible=false) that blocks all subsequent pump()s.
        locationPromptShownProvider.overrideWith(
          _PromptAlreadyShownNotifier.new,
        ),
        // TRI-72: session state drives the gate-vs-push decision in
        // _DiscoverPageState._onCreateEvent.
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        // TRI-72: override the sign-in gate controller so the sheet can open
        // without triggering GetIt (no service locator in widget tests).
        signInGateControllerProvider.overrideWith(
          (intent) => _FixedSignInGateController(intent),
        ),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  // Settle initial frame + any post-frame callbacks.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiscoverPage scaffold', () {
    // -----------------------------------------------------------------------
    // 1. Both tabs are mounted inside the IndexedStack from the start.
    // -----------------------------------------------------------------------
    testWidgets(
      '1. IndexedStack has both DiscoverListTab and DiscoverMapTab mounted',
      (tester) async {
        await _pumpPage(tester, sessionState: _authenticatedState);

        // Both children should be in the widget tree (IndexedStack keeps all
        // children mounted regardless of which is visible).
        // DiscoverMapTab is at index 1 (offstage when list tab is active), so
        // skipOffstage: false is required to find it.
        expect(find.byType(DiscoverListTab), findsOneWidget);
        expect(
          find.byType(DiscoverMapTab, skipOffstage: false),
          findsOneWidget,
        );

        // Verify via IndexedStack that it owns two children.
        final stack = tester.widget<IndexedStack>(
          find.byType(IndexedStack, skipOffstage: false),
        );
        expect(stack.children.length, 2);
      },
    );

    // -----------------------------------------------------------------------
    // 2. Switching tab updates IndexedStack index.
    // -----------------------------------------------------------------------
    testWidgets('2. Tapping Map segment changes IndexedStack index to 1', (
      tester,
    ) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      // Initial state: List tab active → index 0.
      IndexedStack stack = tester.widget<IndexedStack>(
        find.byType(IndexedStack),
      );
      expect(stack.index, 0);

      // Tap the "Map" segment in the DiscoverTabSwitcher.
      await tester.tap(find.text('Map'));
      await tester.pump();

      stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 1);
    });

    testWidgets(
      '2b. Tapping List segment after Map changes IndexedStack index back to 0',
      (tester) async {
        await _pumpPage(tester, sessionState: _authenticatedState);

        // Switch to map first.
        await tester.tap(find.text('Map'));
        await tester.pump();

        // Switch back to list.
        await tester.tap(find.text('List'));
        await tester.pump();

        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 0);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Sticky CTA visible on both tabs.
    // -----------------------------------------------------------------------
    testWidgets('3a. "Create event" CTA visible on List tab', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      // Default is List tab.
      expect(find.text('Create event'), findsOneWidget);
    });

    testWidgets('3b. "Create event" CTA visible on Map tab', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      await tester.tap(find.text('Map'));
      await tester.pump();

      expect(find.text('Create event'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 4. Authenticated tap: CTA routes directly to /events/new (no gate).
    // -----------------------------------------------------------------------
    testWidgets(
      '4. Authenticated: tapping "Create event" navigates directly to /events/new',
      (tester) async {
        await _pumpPage(tester, sessionState: _authenticatedState);

        await tester.tap(find.text('Create event'));
        await tester.pumpAndSettle();

        expect(_lastPushedRoute, '/events/new');
        expect(find.text('Create event page'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 5. FilterChipRow visible on both tabs.
    // -----------------------------------------------------------------------
    testWidgets('5a. FilterChipRow rendered on List tab', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    testWidgets('5b. FilterChipRow rendered on Map tab', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      await tester.tap(find.text('Map'));
      await tester.pump();

      expect(find.byType(FilterChipRow), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Bonus: Screen title and tab switcher are present.
    // -----------------------------------------------------------------------
    testWidgets('Screen title "Discover" is rendered', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      expect(find.text('Discover'), findsOneWidget);
    });

    testWidgets('DiscoverTabSwitcher is rendered', (tester) async {
      await _pumpPage(tester, sessionState: _authenticatedState);

      expect(find.byType(DiscoverTabSwitcher), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 6. TRI-72 Brief C: signed-out tap opens sign-in gate sheet (Tier 1).
    // -----------------------------------------------------------------------
    testWidgets(
      '6. Signed-out: tapping "Create event" opens sign-in gate sheet',
      (tester) async {
        await _pumpPage(tester, sessionState: const SessionUnauthenticated());

        await tester.tap(find.text('Create event'));
        await tester.pumpAndSettle();

        // Gate sheet headline confirms the create-event intent context.
        expect(find.text('Sign in to create an event'), findsOneWidget);
        // Navigation to /events/new must NOT have occurred.
        expect(_lastPushedRoute, isNull);
        expect(find.text('Create event page'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 7. TRI-72 Brief C: authenticated tap skips gate (direct push).
    //    Validated by test #4 above; this test makes the intent explicit.
    // -----------------------------------------------------------------------
    testWidgets(
      '7. Authenticated: "Create event" tap does not open gate sheet',
      (tester) async {
        await _pumpPage(tester, sessionState: _authenticatedState);

        await tester.tap(find.text('Create event'));
        await tester.pumpAndSettle();

        // Sheet headline must NOT appear.
        expect(find.text('Sign in to create an event'), findsNothing);
        // Navigation happened directly.
        expect(_lastPushedRoute, '/events/new');
      },
    );
  });
}
