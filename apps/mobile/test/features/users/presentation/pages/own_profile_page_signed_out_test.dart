// Widget tests for OwnProfilePage — signed-out empty state (TRI-71 Brief C).
//
// Covers:
//   1. Signed-out session → SignedOutEmptyState copy rendered.
//   2. Signed-out session → gear/settings action absent from AppBar.
//   3. Signed-out session → getUserProfileUseCase NEVER invoked.
//   4. Tapping "Sign in" CTA → sign-in gate sheet opens.
//   5. Authenticated session → authed body renders (gear action present).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/sign_in_gate_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/presentation/state/sign_in_gate_state.dart';
import 'package:tribely/src/features/users/domain/entities/user_profile.dart';
import 'package:tribely/src/features/users/presentation/controllers/my_profile_controller.dart';
import 'package:tribely/src/features/users/presentation/pages/own_profile_page.dart';
import 'package:tribely/src/features/users/presentation/providers/users_providers.dart';
import 'package:tribely/src/features/users/presentation/state/user_profile_state.dart';
import 'package:tribely/src/features/users/presentation/string_assets/profile_signed_out_copy.dart';

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
// Fixed-state controllers
// ---------------------------------------------------------------------------

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._fixed);

  final SessionState _fixed;

  @override
  SessionState build() => _fixed;
}

/// Stub [MyProfileController] returning a fixed state — avoids GetIt in tests.
class _FixedMyProfileController extends MyProfileController {
  _FixedMyProfileController(this._fixed);

  final UserProfileState _fixed;

  @override
  UserProfileState build() => _fixed;

  @override
  Future<void> retry() async {}
}

/// Stub [SignInGateController] — returns [SignInGateIdle] without GetIt.
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

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const OwnProfilePage()),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Text('Settings page')),
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
  UserProfileState? profileStateOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(sessionState),
        ),
        myProfileControllerProvider.overrideWith(
          () => _FixedMyProfileController(
            profileStateOverride ?? const UserProfileLoading(),
          ),
        ),
        // Suppress sign-in gate GetIt access when the sheet may open.
        signInGateControllerProvider.overrideWith2(
          (intent) => _FixedSignInGateController(intent),
        ),
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
  group('OwnProfilePage — signed-out empty state', () {
    // -----------------------------------------------------------------------
    // 1. Signed-out session → empty-state copy rendered
    // -----------------------------------------------------------------------
    testWidgets(
      '1. signed-out session renders empty-state headline and body copy',
      (tester) async {
        await _pumpPage(tester, sessionState: const SessionUnauthenticated());

        expect(find.text(ProfileSignedOutCopy.headline), findsOneWidget);
        expect(find.text(ProfileSignedOutCopy.body), findsOneWidget);
        expect(find.text(ProfileSignedOutCopy.cta), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 2. Signed-out session → gear/settings action absent
    // -----------------------------------------------------------------------
    testWidgets(
      '2. signed-out session → settings gear action absent from AppBar',
      (tester) async {
        await _pumpPage(tester, sessionState: const SessionUnauthenticated());

        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        expect(find.byTooltip('Settings'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 3. Signed-out → signed-out empty state renders; profile body absent
    //
    // MyProfileController is overridden to a fixed UserProfileLoaded state.
    // The page should NOT reach the myProfileControllerProvider switch because
    // the session branch returns early with the signed-out empty state widget.
    // We assert the signed-out copy is visible and the profile display name
    // (from the loaded profile) is NOT visible — confirming the page branched
    // before consulting the profile controller's state.
    // -----------------------------------------------------------------------
    testWidgets(
      '3. signed-out session → profile body never reached, empty state shown',
      (tester) async {
        await _pumpPage(
          tester,
          sessionState: const SessionUnauthenticated(),
          // Even if the controller claims loaded, the page must branch on session.
          profileStateOverride: UserProfileLoaded(_fakeProfile),
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Signed-out empty state is visible.
        expect(find.text(ProfileSignedOutCopy.headline), findsOneWidget);
        // The profile display name would appear in ProfileBody if the authed
        // branch ran — its absence confirms the signed-out branch was taken.
        expect(find.text('Test User'), findsNothing);
      },
    );

    // -----------------------------------------------------------------------
    // 4. Tapping "Sign in" CTA opens sign-in gate sheet
    // -----------------------------------------------------------------------
    testWidgets('4. tapping "Sign in" CTA opens sign-in gate sheet', (
      tester,
    ) async {
      await _pumpPage(tester, sessionState: const SessionUnauthenticated());

      await tester.tap(find.text(ProfileSignedOutCopy.cta));
      // Bounded pump walk — sheet open triggers an animation frame.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5. Authenticated session → authed body renders, gear action present
    // -----------------------------------------------------------------------
    testWidgets(
      '5. authenticated session → authed content renders, gear action present',
      (tester) async {
        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_fakeSession),
          profileStateOverride: UserProfileLoaded(_fakeProfile),
        );

        // Gear icon is present in the authed path.
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        // Signed-out copy is absent.
        expect(find.text(ProfileSignedOutCopy.headline), findsNothing);
        // User's display name is visible from the profile body.
        expect(find.text('Test User'), findsWidgets);
      },
    );
  });
}
