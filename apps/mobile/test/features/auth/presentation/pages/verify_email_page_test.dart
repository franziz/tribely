// Widget tests for VerifyEmailPage.
//
// Covers:
//   1. 6 digits entered → OtpCodeInput fires onCompleted → controller.submit.
//   2. Wrong-code response (ValidationFailure) → BannerMessage rendered.
//   3. TTL-expired response (AuthFailure) → BannerMessage rendered.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/otp_code_input.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/domain/usecases/verify_email_usecase.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/pages/verify_email_page.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockVerifyEmailUseCase extends Mock implements VerifyEmailUseCase {}

class _FakeVerifyEmailParams extends Fake implements VerifyEmailParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 19);

User _makeUser() => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: null,
  phoneVerifiedAt: null,
);

AuthSession _makeSession() => AuthSession(
  user: _makeUser(),
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

Widget _wrap(Widget page, _MockVerifyEmailUseCase mockVerify) {
  return ProviderScope(
    overrides: [
      verifyEmailUseCaseProvider.overrideWithValue(mockVerify),
      sessionControllerProvider.overrideWith(() => _StubSessionController()),
    ],
    child: MaterialApp(home: page),
  );
}

class _StubSessionController extends SessionController {
  @override
  SessionState build() => SessionAuthenticated(_makeSession());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVerifyEmailParams());
  });

  late _MockVerifyEmailUseCase mockVerify;

  setUp(() {
    mockVerify = _MockVerifyEmailUseCase();
  });

  testWidgets('entering 6 digits fires controller.submit', (tester) async {
    when(() => mockVerify(any())).thenAnswer(
      (_) async =>
          const Left(ValidationFailure('Invalid code', code: 'INVALID_CODE')),
    );

    await tester.pumpWidget(_wrap(const VerifyEmailPage(), mockVerify));
    await tester.pump();

    final textField = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    await tester.tap(find.byType(OtpCodeInput));
    await tester.pump();
    await tester.enterText(textField, '123456');
    await tester.pumpAndSettle();

    verify(() => mockVerify(any())).called(1);
  });

  testWidgets('wrong-code response renders BannerMessage', (tester) async {
    when(() => mockVerify(any())).thenAnswer(
      (_) async =>
          const Left(ValidationFailure('Invalid code', code: 'INVALID_CODE')),
    );

    await tester.pumpWidget(_wrap(const VerifyEmailPage(), mockVerify));
    await tester.pump();

    final textField = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    await tester.tap(find.byType(OtpCodeInput));
    await tester.pump();
    await tester.enterText(textField, '000000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Invalid code'), findsOneWidget);
  });

  testWidgets('TTL-expired response renders BannerMessage', (tester) async {
    // The controller maps AuthFailure → failure.message (see _bannerFor in
    // verify_email_controller.dart). The server returns AuthFailure for expired
    // verification tokens.
    when(() => mockVerify(any())).thenAnswer(
      (_) async => const Left(
        AuthFailure(
          'Verification code has expired. Please request a new one.',
          code: 'VERIFICATION_CODE_EXPIRED',
        ),
      ),
    );

    await tester.pumpWidget(_wrap(const VerifyEmailPage(), mockVerify));
    await tester.pump();

    final textField = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    await tester.tap(find.byType(OtpCodeInput));
    await tester.pump();
    await tester.enterText(textField, '000000');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Verification code has expired'),
      findsOneWidget,
    );
  });
}
