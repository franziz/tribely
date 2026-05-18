// Tests for VerificationRequiredBanner.
//
// Covers:
//   1. type:email, unverified email → banner with email copy + /verify-email route.
//   2. type:email, verified email → SizedBox.shrink (no banner).
//   3. type:phone, unverified phone → banner with phone copy + /auth/phone/entry route.
//   4. type:phone, verified phone → SizedBox.shrink (no banner).
//   5. Unauthenticated session → no banner for either type.
//   6. Both unverified → both banners stackable (email above phone).
//   7. EmailNotVerifiedBanner (deprecated shim) delegates to VerificationRequiredBanner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/core/widgets/verification_required_banner.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/presentation/widgets/email_not_verified_banner.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

User _makeUser({bool emailVerified = false, bool phoneVerified = false}) {
  final now = DateTime.utc(2026, 5, 18);
  return User(
    id: 'usr-1',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: now,
    updatedAt: now,
    emailVerifiedAt: emailVerified ? now : null,
    phoneVerifiedAt: phoneVerified ? now : null,
  );
}

AuthSession _makeSession(User user) => AuthSession(
  user: user,
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

/// Wraps [widget] in a ProviderScope with [sessionState] overriding
/// [sessionControllerProvider]. Uses a minimal MaterialApp with no router
/// (the banner uses context.go — we verify by checking the widget tree, not
/// navigation, because wiring go_router in a test adds noise).
Widget _wrap(Widget widget, SessionState sessionState) {
  return ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(
        () => _StubSessionController(sessionState),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: widget)),
  );
}

/// Stub controller that returns a fixed state and ignores mutations.
/// Must extend [SessionController] (not `Notifier<SessionState>`) because
/// [sessionControllerProvider]'s `overrideWith` expects the exact notifier type.
class _StubSessionController extends SessionController {
  _StubSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VerificationRequiredBanner — email type', () {
    testWidgets('renders email banner when email is unverified', (
      tester,
    ) async {
      final session = SessionAuthenticated(
        _makeSession(_makeUser(emailVerified: false)),
      );
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.email),
          session,
        ),
      );
      expect(
        find.textContaining('Verify your email'),
        findsOneWidget,
      );
      expect(find.text('Verify now →'), findsOneWidget);
    });

    testWidgets('renders nothing when email is verified', (tester) async {
      final session = SessionAuthenticated(
        _makeSession(_makeUser(emailVerified: true)),
      );
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.email),
          session,
        ),
      );
      expect(find.textContaining('Verify your email'), findsNothing);
    });
  });

  group('VerificationRequiredBanner — phone type', () {
    testWidgets('renders phone banner when phone is unverified', (
      tester,
    ) async {
      final session = SessionAuthenticated(
        _makeSession(_makeUser(phoneVerified: false)),
      );
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.phone),
          session,
        ),
      );
      expect(
        find.textContaining('Verify your phone'),
        findsOneWidget,
      );
      expect(find.text('Verify now →'), findsOneWidget);
    });

    testWidgets('renders nothing when phone is verified', (tester) async {
      final session = SessionAuthenticated(
        _makeSession(_makeUser(phoneVerified: true)),
      );
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.phone),
          session,
        ),
      );
      expect(find.textContaining('Verify your phone'), findsNothing);
    });
  });

  group('VerificationRequiredBanner — unauthenticated', () {
    testWidgets('renders nothing when session is unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.email),
          const SessionUnauthenticated(),
        ),
      );
      expect(find.textContaining('Verify'), findsNothing);
    });

    testWidgets('renders nothing for phone when session is unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const VerificationRequiredBanner(type: VerificationType.phone),
          const SessionUnauthenticated(),
        ),
      );
      expect(find.textContaining('Verify'), findsNothing);
    });
  });

  group('VerificationRequiredBanner — stacked (both banners)', () {
    testWidgets('email above phone when both unverified', (tester) async {
      final session = SessionAuthenticated(
        _makeSession(
          _makeUser(emailVerified: false, phoneVerified: false),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              VerificationRequiredBanner(type: VerificationType.email),
              VerificationRequiredBanner(type: VerificationType.phone),
            ],
          ),
          session,
        ),
      );
      expect(find.textContaining('Verify your email'), findsOneWidget);
      expect(find.textContaining('Verify your phone'), findsOneWidget);

      // Verify ordering: email banner's text appears before phone banner's text.
      final emailOffset = tester
          .getTopLeft(
            find.textContaining('Verify your email'),
          )
          .dy;
      final phoneOffset = tester
          .getTopLeft(
            find.textContaining('Verify your phone'),
          )
          .dy;
      expect(emailOffset, lessThan(phoneOffset));
    });

    testWidgets('only phone banner renders when email is verified', (
      tester,
    ) async {
      final session = SessionAuthenticated(
        _makeSession(
          _makeUser(emailVerified: true, phoneVerified: false),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              VerificationRequiredBanner(type: VerificationType.email),
              VerificationRequiredBanner(type: VerificationType.phone),
            ],
          ),
          session,
        ),
      );
      expect(find.textContaining('Verify your email'), findsNothing);
      expect(find.textContaining('Verify your phone'), findsOneWidget);
    });
  });

  group('EmailNotVerifiedBanner — deprecated shim', () {
    testWidgets('shim delegates to VerificationRequiredBanner email type', (
      tester,
    ) async {
      final session = SessionAuthenticated(
        _makeSession(_makeUser(emailVerified: false)),
      );
      await tester.pumpWidget(
        _wrap(
          // ignore: deprecated_member_use_from_same_package
          const EmailNotVerifiedBanner(),
          session,
        ),
      );
      // Should render the email banner via the delegate.
      expect(find.textContaining('Verify your email'), findsOneWidget);
    });
  });
}
