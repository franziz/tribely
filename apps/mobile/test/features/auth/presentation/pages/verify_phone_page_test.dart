// Widget tests for VerifyPhonePage.
//
// Covers:
//   1. 6 digits entered → OtpCodeInput fires onCompleted → controller.verify.
//   2. Wrong-code response (ValidationFailure) → BannerMessage rendered.
//   3. Rate-limited response (SmsRateLimitedFailure) → 5/hr cap message.
//   4. Cooldown countdown ticks (fake_async clock).

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/otp_code_input.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/domain/usecases/start_phone_verification_usecase.dart';
import 'package:tribely/src/features/auth/domain/usecases/verify_phone_usecase.dart';
import 'package:tribely/src/features/auth/presentation/controllers/phone_verification_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/pages/verify_phone_page.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockVerifyPhoneUseCase extends Mock implements VerifyPhoneUseCase {}

class _MockStartPhoneUseCase extends Mock
    implements StartPhoneVerificationUseCase {}

class _FakeVerifyPhoneParams extends Fake implements VerifyPhoneParams {}

class _FakeStartPhoneParams extends Fake implements StartPhoneParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 18);

User _makeUser({bool phoneVerified = false}) => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: _now,
  phoneVerifiedAt: phoneVerified ? _now : null,
);

AuthSession _makeSession({bool phoneVerified = false}) => AuthSession(
  user: _makeUser(phoneVerified: phoneVerified),
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

Widget _wrap(
  Widget page,
  _MockVerifyPhoneUseCase mockVerify,
  _MockStartPhoneUseCase mockStart, {
  String initialPhone = '+6591234567',
}) {
  final router = GoRouter(
    initialLocation: '/auth/phone/verify',
    routes: [
      GoRoute(
        path: '/auth/phone/entry',
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(path: '/auth/phone/verify', builder: (context, state) => page),
      GoRoute(path: '/profile', builder: (context, state) => const SizedBox()),
    ],
  );

  return ProviderScope(
    overrides: [
      verifyPhoneUseCaseProvider.overrideWithValue(mockVerify),
      startPhoneVerificationUseCaseProvider.overrideWithValue(mockStart),
      // Seed the controller with CodeSent(phone) so VerifyPhonePage has a
      // non-null _currentPhone and verify() can call the use case.
      phoneVerificationControllerProvider.overrideWith(
        () => _SeededPhoneController(initialPhone),
      ),
      sessionControllerProvider.overrideWith(() => _StubSessionController()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _StubSessionController extends SessionController {
  @override
  SessionState build() => SessionAuthenticated(_makeSession());
}

/// Extends [PhoneVerificationController] to start in [PhoneVerificationCodeSent]
/// state with a fixed phone number. This bypasses the need to call `start()`
/// from inside the test (which would require the start use case to complete
/// before `verify()` can run with a non-null `_currentPhone`).
class _SeededPhoneController extends PhoneVerificationController {
  _SeededPhoneController(this._phone);
  final String _phone;

  @override
  PhoneVerificationState build() {
    return PhoneVerificationCodeSent(phone: _phone, resendCooldownSeconds: 0);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVerifyPhoneParams());
    registerFallbackValue(_FakeStartPhoneParams());
  });

  late _MockVerifyPhoneUseCase mockVerify;
  late _MockStartPhoneUseCase mockStart;

  setUp(() {
    mockVerify = _MockVerifyPhoneUseCase();
    mockStart = _MockStartPhoneUseCase();
  });

  testWidgets('entering 6 digits fires controller.verify', (tester) async {
    when(() => mockVerify(any())).thenAnswer(
      (_) async =>
          const Left(ValidationFailure('Invalid code', code: 'INVALID_CODE')),
    );

    await tester.pumpWidget(
      _wrap(const VerifyPhonePage(), mockVerify, mockStart),
    );
    await tester.pump();

    // Enter 6 digits into the OtpCodeInput hidden TextField.
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
          const Left(ValidationFailure('Wrong code.', code: 'INVALID_CODE')),
    );

    await tester.pumpWidget(
      _wrap(const VerifyPhonePage(), mockVerify, mockStart),
    );
    await tester.pump();

    final textField = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    await tester.tap(find.byType(OtpCodeInput));
    await tester.pump();
    await tester.enterText(textField, '000000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Wrong code'), findsOneWidget);
  });

  testWidgets('rate-limited response shows 5/hr cap message', (tester) async {
    when(() => mockVerify(any())).thenAnswer(
      (_) async => const Left(
        SmsRateLimitedFailure('Rate limited', code: 'sms_rate_limited'),
      ),
    );

    await tester.pumpWidget(
      _wrap(const VerifyPhonePage(), mockVerify, mockStart),
    );
    await tester.pump();

    final textField = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    await tester.tap(find.byType(OtpCodeInput));
    await tester.pump();
    await tester.enterText(textField, '000000');
    await tester.pumpAndSettle();

    expect(find.textContaining('5 codes per hour'), findsOneWidget);
  });

  test('cooldown countdown decrements every second', () {
    fakeAsync((clock) {
      // Directly test the PhoneVerificationController countdown logic.
      final container = ProviderContainer(
        overrides: [
          verifyPhoneUseCaseProvider.overrideWithValue(mockVerify),
          startPhoneVerificationUseCaseProvider.overrideWithValue(mockStart),
        ],
      );
      addTearDown(container.dispose);

      // Simulate CodeSent state with cooldown by checking the timer behavior.
      // We can access internal state transitions by listening to the provider.
      final states = <PhoneVerificationState>[];
      final sub = container.listen<PhoneVerificationState>(
        phoneVerificationControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Trigger the timer via a direct start mock.
      when(() => mockStart(any())).thenAnswer((_) async => const Right(null));

      container
          .read(phoneVerificationControllerProvider.notifier)
          .start('+6591234567');
      clock.flushMicrotasks();

      // After start the controller should be in CodeSent(cooldown=60).
      expect(states.last, isA<PhoneVerificationCodeSent>());
      expect(states.last.resendCooldownSeconds, equals(60));

      // Advance 5 seconds.
      clock.elapse(const Duration(seconds: 5));
      expect(states.last.resendCooldownSeconds, equals(55));

      // Advance to 0.
      clock.elapse(const Duration(seconds: 55));
      expect(states.last.resendCooldownSeconds, equals(0));
    });
  });
}
