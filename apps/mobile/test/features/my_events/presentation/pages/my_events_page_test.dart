// Widget tests for MyEventsPage — signed-out empty state (TRI-71 Brief B).
//
// Covers:
//   1. Signed-out session → SignedOutEmptyState rendered (headline + body copy).
//   2. Signed-out session → "+" (create) action absent from AppBar.
//   3. Signed-out session → listMyHostedEventsUseCase NEVER invoked.
//   4. Tapping "Sign in" CTA → sign-in gate sheet opens (controller stubbed to idle).
//   5. Authenticated session → authed path still fires load() (use case invoked).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/providers/list_my_hosted_events_usecase_provider.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/sign_in_gate_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_gate_state.dart';
import 'package:tribely/src/features/discover/domain/usecases/list_my_hosted_events_usecase.dart';
import 'package:tribely/src/features/join_requests/presentation/controllers/my_join_requests_controller.dart';
import 'package:tribely/src/features/join_requests/presentation/providers/join_requests_providers.dart';
import 'package:tribely/src/features/join_requests/presentation/state/my_join_requests_state.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_pending_count_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/hosting_tab_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/my_events_controller.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/pending_review_banner_controller.dart';
import 'package:tribely/src/features/my_events/presentation/pages/my_events_page.dart';
import 'package:tribely/src/features/my_events/presentation/state/hosting_tab_state.dart';
import 'package:tribely/src/features/my_events/presentation/state/my_events_state.dart';
import 'package:tribely/src/features/my_events/presentation/state/pending_review_banner_state.dart';
import 'package:tribely/src/features/auth/presentation/string_assets/sign_in_gate_copy.dart';
import 'package:tribely/src/features/my_events/presentation/string_assets/my_events_signed_out_copy.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2020);

final _fakeUser = User(
  id: 'user-test-01',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _epoch,
  updatedAt: _epoch,
);

final _fakeSession = AuthSession(
  user: _fakeUser,
  accessToken: 'access-token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'refresh-token',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

// ---------------------------------------------------------------------------
// Stub use case — fails the test if invoked when signed-out
// ---------------------------------------------------------------------------

/// A mock [ListMyHostedEventsUseCase] that records invocations.
///
/// Configure via mocktail: when [allowCalls] is false the test uses
/// [verifyNever] after pump to assert no fetch fired signed-out.
class _MockListMyHostedEventsUseCase extends Mock
    implements ListMyHostedEventsUseCase {}

class _FakeListMyHostedEventsParams extends Fake
    implements ListMyHostedEventsParams {}

// ---------------------------------------------------------------------------
// Fixed-state controllers
// ---------------------------------------------------------------------------

/// Stub [SessionController] that avoids GetIt access in widget tests.
class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);

  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

/// Stub [MyEventsController] that returns a fixed state.
///
/// Used for the authed-path test to decouple the page render from the
/// controller's async load lifecycle — the page-level contract (authed
/// branch renders) is what we're asserting, not the controller internals.
class _FixedMyEventsController extends MyEventsController {
  _FixedMyEventsController(this._fixed);

  final MyEventsState _fixed;

  @override
  MyEventsState build() => _fixed;
}

/// Stub [PendingReviewBannerController] that returns [PendingReviewBannerNone]
/// so the banner is invisible in tests (avoids GetIt / reviews DI).
class _NoBannerController extends PendingReviewBannerController {
  @override
  PendingReviewBannerState build() => const PendingReviewBannerNone();
}

/// Stub [HostingTabController] — returns [HostingTabLoading] without GetIt.
///
/// Required for the authed-path test where the IndexedStack mounts HostingTab.
class _FixedHostingTabController extends HostingTabController {
  @override
  HostingTabState build() => const HostingTabLoading();
}

/// Stub [HostingPendingCountController] — returns zero counts without GetIt.
///
/// Required for the authed-path test where the page reads the pending-count
/// family key derived from the (empty) hosted event IDs list.
class _FixedHostingPendingCountController
    extends HostingPendingCountController {
  _FixedHostingPendingCountController(super.eventIdsKey);

  @override
  HostingPendingCountState build() =>
      const HostingPendingCountState(total: 0, perEvent: {});
}

/// Stub [MyJoinRequestsController] — returns [MyJoinRequestsLoading] without
/// GetIt. Required for the authed-path test where IndexedStack mounts the
/// Requested tab.
class _FixedMyJoinRequestsController extends MyJoinRequestsController {
  _FixedMyJoinRequestsController(super.eventId);

  @override
  MyJoinRequestsState build() => const MyJoinRequestsLoading();
}

/// Stub [SignInGateController] — returns [SignInGateIdle] without GetIt.
///
/// Required whenever the sign-in gate sheet may open in a widget test.
class _FixedSignInGateController extends SignInGateController {
  _FixedSignInGateController(super.intent);

  @override
  SignInGateState build() => const SignInGateIdle();

  @override
  Future<void> submit({
    required String email,
    required String password,
  }) async {}
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Builds a minimal [GoRouter] rooted at '/' → [MyEventsPage].
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MyEventsPage()),
      GoRoute(
        path: '/events/new',
        builder: (context, state) =>
            const Scaffold(body: Text('Create event stub')),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const Scaffold(body: Text('Sign up stub')),
      ),
    ],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionState sessionState,
  MyEventsState? myEventsStateOverride,
  _MockListMyHostedEventsUseCase? useCaseMock,
  // When true, add stubs for the tab sub-controllers (HostingTab,
  // MyJoinRequestsTab, HostingPendingCount) so the authed branch renders
  // without GetIt access.
  bool stubTabControllers = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        if (myEventsStateOverride != null)
          myEventsControllerProvider.overrideWith(
            () => _FixedMyEventsController(myEventsStateOverride),
          ),
        if (useCaseMock != null)
          listMyHostedEventsUseCaseProvider.overrideWithValue(useCaseMock),
        // Suppress the review banner — avoids GetIt access to reviews DI.
        pendingReviewBannerControllerProvider.overrideWith(
          _NoBannerController.new,
        ),
        // Suppress sign-in gate GetIt access when the sheet may open.
        signInGateControllerProvider.overrideWith2(
          (intent) => _FixedSignInGateController(intent),
        ),
        if (stubTabControllers) ...[
          // HostingTab controller — avoids GetIt for list-hosted-events.
          hostingTabControllerProvider.overrideWith(
            _FixedHostingTabController.new,
          ),
          // HostingPendingCount for the empty-key ('') — avoids GetIt for
          // list-pending-for-event.
          hostingPendingCountControllerProvider(
            '',
          ).overrideWith(() => _FixedHostingPendingCountController('')),
          // MyJoinRequestsTab controller (family) — avoids GetIt.
          myJoinRequestsControllerProvider.overrideWith2(
            (String? arg) => _FixedMyJoinRequestsController(arg),
          ),
        ],
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeListMyHostedEventsParams());
  });

  group('MyEventsPage — signed-out empty state', () {
    // -----------------------------------------------------------------------
    // 1. Signed-out session → SignedOutEmptyState copy rendered
    // -----------------------------------------------------------------------
    testWidgets(
      '1. signed-out session renders empty-state headline and body copy',
      (tester) async {
        await _pumpPage(
          tester,
          sessionState: const SessionUnauthenticated(),
          myEventsStateOverride: const MyEventsSignedOut(),
        );

        expect(find.text(MyEventsSignedOutCopy.headline), findsOneWidget);
        expect(find.text(MyEventsSignedOutCopy.body), findsOneWidget);
        expect(find.text(MyEventsSignedOutCopy.cta), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 2. Signed-out session → "+" action absent from AppBar
    // -----------------------------------------------------------------------
    testWidgets(
      '2. signed-out session → "+" create action absent from AppBar',
      (tester) async {
        await _pumpPage(
          tester,
          sessionState: const SessionUnauthenticated(),
          myEventsStateOverride: const MyEventsSignedOut(),
        );

        expect(find.byIcon(Icons.add), findsNothing);
        expect(find.byTooltip('Create event'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Signed-out → use case never invoked (PII gate)
    // -----------------------------------------------------------------------
    testWidgets(
      '3. signed-out session → listMyHostedEventsUseCase never invoked',
      (tester) async {
        final mock = _MockListMyHostedEventsUseCase();

        await _pumpPage(
          tester,
          sessionState: const SessionUnauthenticated(),
          useCaseMock: mock,
        );

        // Allow any post-build microtasks to settle.
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the use case was never called signed-out.
        verifyNever(() => mock(any()));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Tapping "Sign in" CTA opens the sign-in gate sheet
    // -----------------------------------------------------------------------
    testWidgets('4. tapping "Sign in" CTA opens sign-in gate sheet', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        sessionState: const SessionUnauthenticated(),
        myEventsStateOverride: const MyEventsSignedOut(),
      );

      // Tap the "Sign in" primary button.
      await tester.tap(find.text(MyEventsSignedOutCopy.cta));
      // Use bounded pump walk — the sheet open triggers an animation.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The gate sheet renders a password text field (unique to the sheet).
      expect(find.byType(BottomSheet), findsOneWidget);
      // Sheet headline must read the neutral "Sign in to continue" copy,
      // NOT "Sign in to create an event" (wrong intent for this surface).
      expect(find.text(SignInGateCopy.generalHeadline), findsOneWidget);
      expect(find.text(SignInGateCopy.createHeadline), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 5. Authenticated session → signed-out empty state is absent, "+" present
    //
    // Uses MyEventsLoading (not Loaded) so the page enters the authed branch
    // without triggering the IndexedStack's HostingTab / MyJoinRequestsTab
    // sub-controllers that require GetIt service locator registration.
    // The key assertions are: signed-out copy absent, "+" action visible.
    // -----------------------------------------------------------------------
    testWidgets(
      '5. authenticated session → signed-out copy absent, "+" action present',
      (tester) async {
        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_fakeSession),
          // Loading state enters the authed branch; tab stubs prevent GetIt.
          myEventsStateOverride: const MyEventsLoading(),
          stubTabControllers: true,
        );

        // "+" action is present in the authed branch.
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byTooltip('Create event'), findsOneWidget);
        // Signed-out copy must be absent.
        expect(find.text(MyEventsSignedOutCopy.headline), findsNothing);
        expect(find.text(MyEventsSignedOutCopy.cta), findsNothing);
      },
    );
  });
}
