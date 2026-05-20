// Widget tests for SettingsPage.
//
// Covers:
//   1. Renders "Settings" AppBar title.
//   2. ACCOUNT section header renders.
//   3. PRIVACY & SAFETY section header renders.
//   4. "Blocked users" tile is present.
//   5. "Sign out" button is present.
//   6. Tapping "Sign out" opens an AlertDialog with correct title and actions.
//   7. Tapping Cancel in the dialog dismisses without calling signOut.
//   8. Tapping "Sign out" in the dialog calls SessionController.signOut once.
//   9. Tapping "Blocked users" navigates to /settings/blocked-users.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/users/presentation/pages/settings_page.dart';

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
  accessToken: 'token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'refresh',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _SpySessionController extends SessionController {
  _SpySessionController({this.onSignOut});
  final VoidCallback? onSignOut;

  @override
  SessionState build() => SessionAuthenticated(_fakeSession);

  @override
  Future<void> signOut() async {
    onSignOut?.call();
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpPage(
  WidgetTester tester, {
  VoidCallback? onSignOut,
  GoRouter? router,
}) async {
  final testRouter =
      router ??
      GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/settings/blocked-users',
            builder: (context, state) =>
                const Scaffold(body: Text('Blocked users page')),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) =>
                const Scaffold(body: Text('Edit profile page')),
          ),
        ],
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _SpySessionController(onSignOut: onSignOut),
        ),
      ],
      child: MaterialApp.router(routerConfig: testRouter),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsPage — renders', () {
    testWidgets('renders "Settings" AppBar title', (tester) async {
      await _pumpPage(tester);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders ACCOUNT section header', (tester) async {
      await _pumpPage(tester);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });

    testWidgets('renders PRIVACY & SAFETY section header', (tester) async {
      await _pumpPage(tester);
      expect(find.text('PRIVACY & SAFETY'), findsOneWidget);
    });

    testWidgets('renders "Blocked users" tile', (tester) async {
      await _pumpPage(tester);
      expect(find.text('Blocked users'), findsOneWidget);
    });

    testWidgets('renders "Sign out" button', (tester) async {
      await _pumpPage(tester);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('SettingsPage — sign-out flow', () {
    testWidgets(
      'tapping "Sign out" opens AlertDialog with correct title and actions',
      (tester) async {
        await _pumpPage(tester);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sign out of Tribely?'), findsOneWidget);
        // "Cancel" and "Sign out" both appear in the dialog actions.
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Sign out'), findsNWidgets(2));
      },
    );

    testWidgets('tapping Cancel dismisses dialog without calling signOut', (
      tester,
    ) async {
      var signOutCalls = 0;
      await _pumpPage(tester, onSignOut: () => signOutCalls++);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(signOutCalls, 0);
    });

    testWidgets(
      'tapping "Sign out" in the dialog calls SessionController.signOut once',
      (tester) async {
        var signOutCalls = 0;
        await _pumpPage(tester, onSignOut: () => signOutCalls++);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        // The dialog has two "Sign out" texts — tap the one inside the dialog.
        // The dialog's action button text is the second occurrence.
        final signOutFinders = find.text('Sign out');
        // Tap the last one (inside the dialog actions).
        await tester.tap(signOutFinders.last);
        await tester.pumpAndSettle();

        expect(signOutCalls, 1);
      },
    );
  });

  group('SettingsPage — navigation', () {
    testWidgets(
      'tapping "Blocked users" navigates to /settings/blocked-users',
      (tester) async {
        await _pumpPage(tester);
        await tester.tap(find.text('Blocked users'));
        await tester.pumpAndSettle();

        expect(find.text('Blocked users page'), findsOneWidget);
      },
    );
  });
}
