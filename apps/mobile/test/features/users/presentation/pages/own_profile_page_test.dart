// Widget tests for OwnProfilePage — Settings entry point (updated in Brief 2C).
//
// Prior to Brief 2C, the OwnProfilePage had a sign-out IconButton directly in
// the AppBar. Brief 2C moved sign-out to the Settings page (Settings → Sign out).
// OwnProfilePage now shows a gear icon that navigates to /settings instead.
//
// Covers:
//   1. Settings gear IconButton is present in the AppBar.
//   2. Tapping it navigates to /settings.
//
// Mocking strategy:
//   - `myProfileControllerProvider` is overridden with a fixed-state stub that
//     returns `UserProfileLoaded` immediately, bypassing GetIt / use-case calls.
//   - `sessionControllerProvider` is overridden with a stub session.
//   - GoRouter is wired with a test config to verify navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/users/domain/entities/user_profile.dart';
import 'package:tribely/src/features/users/presentation/controllers/my_profile_controller.dart';
import 'package:tribely/src/features/users/presentation/pages/own_profile_page.dart';
import 'package:tribely/src/features/users/presentation/providers/users_providers.dart';
import 'package:tribely/src/features/users/presentation/state/user_profile_state.dart';

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

final _fakeProfile = UserProfile(
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
// Stubs
// ---------------------------------------------------------------------------

class _FixedMyProfileController extends MyProfileController {
  @override
  UserProfileState build() => UserProfileLoaded(_fakeProfile);

  @override
  Future<void> retry() async {}
}

class _SpySessionController extends SessionController {
  @override
  SessionState build() => SessionAuthenticated(_fakeSession);

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Pump helper (with GoRouter so context.push('/settings') works)
// ---------------------------------------------------------------------------

Future<void> _pumpPage(WidgetTester tester) async {
  // Minimal router: OwnProfilePage at /, a stub settings page at /settings.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const OwnProfilePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Text('Settings page')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const Scaffold(body: Text('Edit profile')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myProfileControllerProvider.overrideWith(
          () => _FixedMyProfileController(),
        ),
        sessionControllerProvider.overrideWith(() => _SpySessionController()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
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
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.logout),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Sign out'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. Tapping the button opens the confirmation dialog
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping sign-out button opens AlertDialog with correct title and actions',
      (tester) async {
        await _pumpPage(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.logout),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sign out of Tribely?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Sign out'),
          ),
          findsOneWidget,
        );
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
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.logout),
        ),
      );
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
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.logout),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Sign out'),
          ),
        );
        await tester.pumpAndSettle();

        expect(signOutCalls, equals(1));
      },
    );
  });

  group('OwnProfilePage — Settings entry point', () {
    testWidgets('Settings gear IconButton is present in the AppBar', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('tapping gear icon navigates to /settings', (tester) async {
      await _pumpPage(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // The stub settings page is now visible.
      expect(find.text('Settings page'), findsOneWidget);
    });
  });
}
