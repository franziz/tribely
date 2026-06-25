// Widget tests for EmptyState.
//
// Covers:
//   1. noEventsMatchFilters: renders "Nothing here yet" headline.
//   2. noEventsMatchFilters: renders "Reset filters" secondary button.
//   3. noEventsMatchFilters: body copy rendered.
//   4. noEventsInArea: renders "No events in Singapore yet" headline.
//   5. noEventsInArea: renders "Create an event" primary button.
//   6. noEventsInArea: body copy rendered.
//   7. TRI-72 Brief C: signed-out "Create an event" tap opens sign-in gate sheet.
//   8. TRI-72 Brief C: authenticated "Create an event" tap navigates to /events/new.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/core/widgets/secondary_button.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/sign_in_gate_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_gate_state.dart';
import 'package:tribely/src/features/discover/presentation/widgets/empty_state.dart';
import 'package:tribely/src/features/discover/presentation/state/discover_state.dart';

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

/// Must extend [SessionController] because [sessionControllerProvider]'s
/// `overrideWith` expects the exact notifier type.
class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);
  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

/// Fixed [SignInGateController] that returns [SignInGateIdle] without touching
/// GetIt. Required whenever the sign-in gate sheet is opened in tests.
///
/// Used with [signInGateControllerProvider.overrideWith2] — Riverpod 3.3.x
/// delivers the family arg through the `overrideWith2` factory lambda, so this
/// class receives it via the normal super constructor parameter.
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

/// Destination recorded when the CTA navigates.
String? _lastNavigatedRoute;

Future<void> _pumpEmptyState(
  WidgetTester tester,
  DiscoverEmptyReason reason, {
  SessionState sessionState = const SessionUnauthenticated(),
}) async {
  _lastNavigatedRoute = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        // overrideWith2 is the Riverpod 3.3.x API for whole-family NotifierProvider
        // overrides; the factory receives the family arg (SignInIntent) directly.
        signInGateControllerProvider.overrideWith2(
          (intent) => _FixedSignInGateController(intent),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/test',
          routes: [
            GoRoute(
              path: '/test',
              builder: (_, _) => Scaffold(body: EmptyState(reason: reason)),
            ),
            GoRoute(
              path: '/events/new',
              builder: (_, _) {
                _lastNavigatedRoute = '/events/new';
                return const Scaffold(body: Text('create-event-stub'));
              },
            ),
            GoRoute(
              path: '/sign-up',
              builder: (_, _) => const Scaffold(body: Text('sign-up-stub')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EmptyState', () {
    group('noEventsMatchFilters', () {
      testWidgets('1. renders headline "Nothing here yet"', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsMatchFilters);
        expect(find.text('Nothing here yet'), findsOneWidget);
      });

      testWidgets('2. renders SecondaryButton "Reset filters"', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsMatchFilters);
        expect(find.byType(SecondaryButton), findsOneWidget);
        expect(find.text('Reset filters'), findsOneWidget);
      });

      testWidgets('3. renders body copy', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsMatchFilters);
        expect(find.text('Try a different time or category.'), findsOneWidget);
      });
    });

    group('noEventsInArea', () {
      testWidgets('4. renders headline "No events in Singapore yet"', (
        tester,
      ) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.text('No events in Singapore yet'), findsOneWidget);
      });

      testWidgets('5. renders PrimaryButton "Create an event"', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(find.text('Create an event'), findsOneWidget);
      });

      testWidgets('6. renders body copy', (tester) async {
        await _pumpEmptyState(tester, DiscoverEmptyReason.noEventsInArea);
        expect(find.text('Be the first to host something.'), findsOneWidget);
      });

      // -----------------------------------------------------------------------
      // 7. TRI-72 Brief C: signed-out tap opens sign-in gate sheet (Tier 1).
      //
      // The Discover feed is public (signed-out reachable), so the empty-state
      // "Create an event" CTA needs the same gate as the sticky CTA.
      // -----------------------------------------------------------------------
      testWidgets(
        '7. Signed-out: "Create an event" tap opens sign-in gate sheet',
        (tester) async {
          await _pumpEmptyState(
            tester,
            DiscoverEmptyReason.noEventsInArea,
            sessionState: const SessionUnauthenticated(),
          );

          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();

          // Gate sheet headline confirms create-event intent.
          expect(find.text('Sign in to create an event'), findsOneWidget);
          // Navigation to /events/new must NOT have occurred.
          expect(_lastNavigatedRoute, isNull);
          expect(find.text('create-event-stub'), findsNothing);
        },
      );

      // -----------------------------------------------------------------------
      // 8. TRI-72 Brief C: authenticated tap navigates directly to /events/new.
      // -----------------------------------------------------------------------
      testWidgets(
        '8. Authenticated: "Create an event" tap navigates to /events/new',
        (tester) async {
          await _pumpEmptyState(
            tester,
            DiscoverEmptyReason.noEventsInArea,
            sessionState: _authenticatedState,
          );

          await tester.tap(find.byType(PrimaryButton));
          await tester.pumpAndSettle();

          // No gate sheet opened.
          expect(find.text('Sign in to create an event'), findsNothing);
          // Navigated to create-event page.
          expect(_lastNavigatedRoute, '/events/new');
          expect(find.text('create-event-stub'), findsOneWidget);
        },
      );
    });
  });
}
