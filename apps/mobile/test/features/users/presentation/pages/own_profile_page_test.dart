// Widget tests for OwnProfilePage — sign-out affordance (TRI-28 smoke unblock).
//
// Covers:
//   1. Sign-out IconButton is present in the AppBar.
//   2. Tapping it opens an AlertDialog with the correct title and action labels.
//   3. Tapping Cancel dismisses the dialog without calling SessionController.signOut.
//   4. Tapping "Sign out" calls SessionController.signOut() exactly once.
//
// Mocking strategy:
//   - `myProfileControllerProvider` is overridden with a fixed-state stub that
//     returns `UserProfileLoading` immediately, bypassing GetIt / use-case calls.
//   - `sessionControllerProvider` is overridden with a stub that tracks `signOut`
//     invocations via a counter — no real network call is made.
//   - GetIt / service locator is never initialised — all DI flows through
//     ProviderScope overrides.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/users/presentation/controllers/my_profile_controller.dart';
import 'package:tribely/src/features/users/presentation/pages/own_profile_page.dart';
import 'package:tribely/src/features/users/presentation/providers/users_providers.dart';
import 'package:tribely/src/features/users/presentation/state/user_profile_state.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

/// Returns `UserProfileLoading` without hitting the use case or GetIt graph.
class _FixedMyProfileController extends MyProfileController {
  @override
  UserProfileState build() => const UserProfileLoading();

  @override
  Future<void> retry() async {}
}

/// Tracks `signOut` call count; never calls the use case or mutates session.
class _SpySessionController extends SessionController {
  int signOutCallCount = 0;

  @override
  SessionState build() => const SessionUnauthenticated();

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pump [OwnProfilePage] under a [ProviderScope] with provider overrides and
/// return the spy controller so tests can assert on it.
Future<_SpySessionController> _pumpPage(WidgetTester tester) async {
  final spy = _SpySessionController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileControllerProvider.overrideWith(() => _FixedMyProfileController()),
        sessionControllerProvider.overrideWith(() => spy),
      ],
      child: const MaterialApp(home: OwnProfilePage()),
    ),
  );
  // Drain the Future(() => _load()) scheduled by _FixedMyProfileController.build.
  await tester.pump();

  return spy;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OwnProfilePage — sign-out affordance', () {
    // -----------------------------------------------------------------------
    // 1. Sign-out button is present
    // -----------------------------------------------------------------------
    testWidgets('sign-out IconButton is present in the AppBar', (tester) async {
      await _pumpPage(tester);

      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Tapping the button opens the confirmation dialog
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping sign-out button opens AlertDialog with correct title and actions',
      (tester) async {
        await _pumpPage(tester);

        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        // Dialog must be visible.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sign out of Tribely?'), findsOneWidget);

        // Both action labels must be present.
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Cancel dismisses without signing out
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping Cancel dismisses the dialog without calling signOut',
      (tester) async {
        final spy = await _pumpPage(tester);

        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog dismissed.
        expect(find.byType(AlertDialog), findsNothing);
        // signOut must NOT have been called.
        expect(spy.signOutCallCount, equals(0));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Confirming calls signOut exactly once
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping "Sign out" in the dialog calls SessionController.signOut once',
      (tester) async {
        final spy = await _pumpPage(tester);

        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(spy.signOutCallCount, equals(1));
      },
    );
  });
}
