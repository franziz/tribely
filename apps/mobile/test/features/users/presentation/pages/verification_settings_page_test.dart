// Widget tests for VerificationSettingsPage.
//
// Covers:
//   1. All three verified → green banner + "You're verified" copy; all rows show "Verified" state, no CTAs.
//   2. Email verified only, phone + selfie not started → neutral banner + locked copy; phone shows "Verify now" CTA; selfie chip hidden.
//   3. Selfie pending → row shows "Photo under review" + "Check status" CTA; tap → spinner appears; after delay spinner clears.
//   4. Selfie failed → "Retry" CTA; tap → navigates to /verification/failure.
//   5. Phone not verified → tap "Verify now" on phone row → navigates to /auth/phone/entry.
//   6. Email not verified → tap "Verify now" on email row → navigates to /verify-email.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/core/widgets/skeleton_loader.dart';
import 'package:tribely/src/features/users/presentation/pages/verification_settings_page.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';
import 'package:tribely/src/features/users/presentation/string_assets/verification_settings_copy.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2020);
final _epochVerified = DateTime.utc(2021);

AuthSession _session(User user) => AuthSession(
  user: user,
  accessToken: 'tok',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'ref',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

User _user({
  bool emailVerified = false,
  bool phoneVerified = false,
  String selfieStatus = 'notStarted',
}) => User(
  id: 'u1',
  email: 'test@example.com',
  displayName: 'Test',
  createdAt: _epoch,
  updatedAt: _epoch,
  emailVerifiedAt: emailVerified ? _epochVerified : null,
  phoneVerifiedAt: phoneVerified ? _epochVerified : null,
  selfieStatus: selfieStatus,
);

// ---------------------------------------------------------------------------
// Stub SessionController
// ---------------------------------------------------------------------------

class _StubSessionController extends SessionController {
  _StubSessionController(this._sessionState);
  final SessionState _sessionState;

  @override
  SessionState build() => _sessionState;
}

// ---------------------------------------------------------------------------
// Pump helpers
// ---------------------------------------------------------------------------

/// Pumps the page inside a real GoRouter so context.push() works. Routes
/// for all three navigation targets are registered as stubs.
Future<void> _pumpPage(
  WidgetTester tester, {
  required SessionState sessionState,
  required SelfieGatingState selfieState,
}) async {
  final router = GoRouter(
    initialLocation: '/settings/verification',
    routes: [
      GoRoute(
        path: '/settings/verification',
        builder: (context, state) => const VerificationSettingsPage(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            const Scaffold(body: Text('verify-email page')),
      ),
      GoRoute(
        path: '/auth/phone/entry',
        builder: (context, state) =>
            const Scaffold(body: Text('phone entry page')),
      ),
      GoRoute(
        path: '/verification/failure',
        builder: (context, state) =>
            const Scaffold(body: Text('verification failure page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          () => _StubSessionController(sessionState),
        ),
        selfieGatingStateProvider.overrideWithValue(selfieState),
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
  group('VerificationSettingsPage — fully verified', () {
    testWidgets(
      '1. All three verified → green banner copy + all rows show "Verified" with no CTAs',
      (tester) async {
        final user = _user(
          emailVerified: true,
          phoneVerified: true,
          selfieStatus: 'approved',
        );

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingApproved(),
        );

        // Banner shows the fully-verified copy.
        expect(find.text(kVerificationBannerFullyVerified), findsOneWidget);

        // All three rows show "Verified" state.
        expect(find.text(kVerificationStateVerified), findsNWidgets(3));

        // No CTA labels present.
        expect(find.text(kVerificationCtaVerifyNow), findsNothing);
        expect(find.text(kVerificationCtaRetry), findsNothing);
        expect(find.text(kVerificationCtaCheckStatus), findsNothing);
      },
    );
  });

  group('VerificationSettingsPage — partial verification', () {
    testWidgets(
      '2. Email verified, phone + selfie not started → neutral banner; phone + selfie show "Verify now"',
      (tester) async {
        final user = _user(emailVerified: true);

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingNotStarted(),
        );

        // Banner shows the locked / partial copy.
        expect(find.text(kVerificationBannerPartial), findsOneWidget);

        // Only one "Verify now" CTA — phone row.
        // Selfie row hides the chip on NotStarted (route not yet registered; Brief C wires it).
        expect(find.text(kVerificationCtaVerifyNow), findsOneWidget);

        // Email row shows "Verified" (no CTA for email).
        expect(find.text(kVerificationStateVerified), findsOneWidget);

        // Phone and selfie rows show "Not started".
        expect(find.text(kVerificationStateNotStarted), findsNWidgets(2));
      },
    );
  });

  group('VerificationSettingsPage — selfie pending', () {
    testWidgets(
      '3. Selfie pending → "Photo under review" + "Check status" CTA; tap → spinner; after 600ms+ spinner clears',
      (tester) async {
        final user = _user(
          emailVerified: true,
          phoneVerified: true,
          selfieStatus: 'pending',
        );

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingPending(),
        );

        // Selfie row shows the pending-specific label override.
        expect(find.text(kVerificationStateSelfiePending), findsOneWidget);

        // "Check status" CTA is present.
        expect(find.text(kVerificationCtaCheckStatus), findsOneWidget);

        // No spinner before tap.
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Tap the "Check status" row (the full row is the tap target).
        await tester.tap(find.text(kVerificationCtaCheckStatus));
        // pump once — setState(() => _isCheckingSelfie = true) fires.
        await tester.pump();

        // Spinner appears.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Advance past the 600ms delay.
        await tester.pump(const Duration(milliseconds: 700));

        // Spinner is gone.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('VerificationSettingsPage — selfie failed / locked', () {
    testWidgets(
      '4a. Selfie failed → "Retry" CTA; tap → navigates to /verification/failure',
      (tester) async {
        final user = _user(selfieStatus: 'rejected');

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingFailed(
            category: null,
            attemptCount: 1,
          ),
        );

        expect(find.text(kVerificationCtaRetry), findsOneWidget);

        await tester.tap(find.text(kVerificationCtaRetry));
        await tester.pumpAndSettle();

        expect(find.text('verification failure page'), findsOneWidget);
      },
    );

    testWidgets(
      '4b. Selfie locked → "Retry" CTA; tap → navigates to /verification/failure',
      (tester) async {
        final user = _user(selfieStatus: 'rejected');

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingLocked(category: null),
        );

        expect(find.text(kVerificationCtaRetry), findsOneWidget);

        await tester.tap(find.text(kVerificationCtaRetry));
        await tester.pumpAndSettle();

        expect(find.text('verification failure page'), findsOneWidget);
      },
    );
  });

  group('VerificationSettingsPage — phone navigation', () {
    testWidgets(
      '5. Phone not verified → tap "Verify now" on phone row → navigates to /auth/phone/entry',
      (tester) async {
        // Email verified so only ONE "Verify now" CTA is visible (phone),
        // making the tap target unambiguous.
        final user = _user(emailVerified: true);

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingApproved(),
        );

        // Only phone row has "Verify now" — selfie is approved.
        expect(find.text(kVerificationCtaVerifyNow), findsOneWidget);

        await tester.tap(find.text(kVerificationCtaVerifyNow));
        await tester.pumpAndSettle();

        expect(find.text('phone entry page'), findsOneWidget);
      },
    );
  });

  group('VerificationSettingsPage — email navigation', () {
    testWidgets(
      '6. Email not verified → tap "Verify now" on email row → navigates to /verify-email',
      (tester) async {
        // Phone verified + selfie approved so only ONE "Verify now" CTA is
        // visible (email), making the tap target unambiguous.
        final user = _user(phoneVerified: true, selfieStatus: 'approved');

        await _pumpPage(
          tester,
          sessionState: SessionAuthenticated(_session(user)),
          selfieState: const SelfieGatingApproved(),
        );

        // Only email row has "Verify now".
        expect(find.text(kVerificationCtaVerifyNow), findsOneWidget);

        await tester.tap(find.text(kVerificationCtaVerifyNow));
        await tester.pumpAndSettle();

        expect(find.text('verify-email page'), findsOneWidget);
      },
    );
  });

  group('VerificationSettingsPage — skeleton', () {
    testWidgets('Shows skeleton when session is not yet authenticated', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        sessionState: const SessionRestoring(),
        selfieState: const SelfieGatingNotStarted(),
      );

      // Banner and rows are absent when unauthenticated.
      expect(find.text(kVerificationBannerPartial), findsNothing);
      expect(find.text(kVerificationBannerFullyVerified), findsNothing);
      expect(find.text(kVerificationLabelEmail), findsNothing);
      // SkeletonLoader widgets are present.
      expect(find.byType(SkeletonLoader), findsWidgets);
    });
  });
}
