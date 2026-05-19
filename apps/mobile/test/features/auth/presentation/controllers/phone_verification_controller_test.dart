// Controller-level unit tests for PhoneVerificationController.
//
// Covers (TRI-126 regression):
//   - verify('000000') propagates the code verbatim to VerifyPhoneUseCase.
//     Widget tests cannot exercise the AutofillHints platform effect; this
//     test is the unit-level anchor for the code-propagation contract.
//
// Note: widget-level coverage (autofill gating, OtpCodeInput.onCompleted path,
// banner rendering) lives in verify_phone_page_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/features/auth/domain/usecases/start_phone_verification_usecase.dart';
import 'package:tribely/src/features/auth/domain/usecases/verify_phone_usecase.dart';
import 'package:tribely/src/features/auth/presentation/controllers/phone_verification_controller.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';

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

final _now = DateTime.utc(2026, 5, 19);

User _makeUser() => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: _now,
  phoneVerifiedAt: _now,
);

AuthSession _makeSession() => AuthSession(
  user: _makeUser(),
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

/// Extends [PhoneVerificationController] to start in [PhoneVerificationCodeSent]
/// state with a fixed phone number, simulating a user who has already passed
/// the start-verification step.
class _SeededController extends PhoneVerificationController {
  _SeededController(this._phone);
  final String _phone;

  @override
  PhoneVerificationState build() =>
      PhoneVerificationCodeSent(phone: _phone, resendCooldownSeconds: 0);
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
    registerFallbackValue(_FakeVerifyPhoneParams());
    registerFallbackValue(_FakeStartPhoneParams());
  });

  late _MockVerifyPhoneUseCase mockVerify;
  late _MockStartPhoneUseCase mockStart;

  setUp(() {
    mockVerify = _MockVerifyPhoneUseCase();
    mockStart = _MockStartPhoneUseCase();
  });

  const phone = '+6591234567';

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      verifyPhoneUseCaseProvider.overrideWithValue(mockVerify),
      startPhoneVerificationUseCaseProvider.overrideWithValue(mockStart),
      phoneVerificationControllerProvider.overrideWith(
        () => _SeededController(phone),
      ),
      sessionControllerProvider.overrideWith(() => _StubSessionController()),
    ],
  );

  test(
    'verify("000000") invokes VerifyPhoneUseCase with code="000000" verbatim '
    '(TRI-126 regression: autofill must not overwrite magic code)',
    () async {
      when(() => mockVerify(any())).thenAnswer((_) async => Right(_makeUser()));

      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(phoneVerificationControllerProvider.notifier)
          .verify('000000');

      final captured = verify(() => mockVerify(captureAny())).captured;
      expect(captured, hasLength(1));
      final params = captured.first as VerifyPhoneParams;
      expect(params.code, equals('000000'));
      expect(params.phone, equals(phone));
    },
  );

  test(
    'verify("000000") transitions to PhoneVerificationSuccess on success',
    () async {
      when(() => mockVerify(any())).thenAnswer((_) async => Right(_makeUser()));

      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(phoneVerificationControllerProvider.notifier)
          .verify('000000');

      expect(
        container.read(phoneVerificationControllerProvider),
        isA<PhoneVerificationSuccess>(),
      );
    },
  );
}
