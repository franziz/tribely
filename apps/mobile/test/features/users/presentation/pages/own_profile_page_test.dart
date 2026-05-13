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

/// Calls [onSignOut] when signOut is invoked; never calls the use case or
/// mutates session state.
class _SpySessionController extends SessionController {
  _SpySessionController({this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  SessionState build() => const SessionUnauthenticated();

  @override
  Future<void> signOut() async {
    onSignOut?.call();
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pump [OwnProfilePage] under a [ProviderScope] with provider overrides.
///
/// [onSignOut] is forwarded to [_SpySessionController] so callers can assert
/// on sign-out invocations via a local counter.
Future<void> _pumpPage(WidgetTester tester, {VoidCallback? onSignOut}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileControllerProvider.overrideWith(
          () => _FixedMyProfileController(),
        ),
        sessionControllerProvider.overrideWith(
          () => _SpySessionController(onSignOut: onSignOut),
        ),
      ],
      child: const MaterialApp(home: OwnProfilePage()),
    ),
  );
  // Drain the initial pump so the page layout settles.
  await tester.pump();
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

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sign out of Tribely?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Cancel dismisses without signing out
    // -----------------------------------------------------------------------
    testWidgets('tapping Cancel dismisses the dialog without calling signOut', (
      tester,
    ) async {
      var signOutCalls = 0;
      await _pumpPage(tester, onSignOut: () => signOutCalls++);
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(signOutCalls, equals(0));
    });

    // -----------------------------------------------------------------------
    // 4. Confirming calls signOut exactly once
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping "Sign out" in the dialog calls SessionController.signOut once',
      (tester) async {
        var signOutCalls = 0;
        await _pumpPage(tester, onSignOut: () => signOutCalls++);
        await tester.tap(find.byIcon(Icons.logout));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(signOutCalls, equals(1));
      },
    );
  });
}
