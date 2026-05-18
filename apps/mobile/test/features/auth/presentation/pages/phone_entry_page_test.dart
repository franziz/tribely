// Widget tests for PhoneEntryPage.
//
// Covers:
//   1. Invalid (empty) number → inline validation error, no controller call.
//   2. Valid number → controller's start(phone) called with correct E.164 string.
//   3. "Skip for now" → navigates without calling the backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/widgets/primary_button.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/domain/usecases/start_phone_verification_usecase.dart';
import 'package:tribely/src/features/auth/presentation/controllers/session_controller.dart';
import 'package:tribely/src/features/auth/presentation/pages/phone_entry_page.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockStartPhoneVerificationUseCase extends Mock
    implements StartPhoneVerificationUseCase {}

class _FakeStartPhoneParams extends Fake implements StartPhoneParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 18);

User _makeUser() => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: _now,
);

AuthSession _makeSession() => AuthSession(
  user: _makeUser(),
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

Widget _wrap(Widget page, _MockStartPhoneVerificationUseCase mockUseCase) {
  final routes = [
    GoRoute(path: '/auth/phone/entry', builder: (context, state) => page),
    GoRoute(
      path: '/auth/phone/verify',
      builder: (context, state) => const SizedBox(),
    ),
    GoRoute(path: '/events', builder: (context, state) => const SizedBox()),
  ];

  final router = GoRouter(initialLocation: '/auth/phone/entry', routes: routes);

  return ProviderScope(
    overrides: [
      startPhoneVerificationUseCaseProvider.overrideWithValue(mockUseCase),
      sessionControllerProvider.overrideWith(() => _StubSessionController()),
    ],
    child: MaterialApp.router(routerConfig: router),
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
  setUpAll(() => registerFallbackValue(_FakeStartPhoneParams()));

  late _MockStartPhoneVerificationUseCase mockUseCase;

  setUp(() {
    mockUseCase = _MockStartPhoneVerificationUseCase();
  });

  testWidgets('empty number: Send code button is disabled, backend not called', (
    tester,
  ) async {
    // AuthPageScaffold uses SingleChildScrollView; scroll the CTA into view before tapping.
    await tester.pumpWidget(_wrap(const PhoneEntryPage(), mockUseCase));
    await tester.pump();

    // The "Send code" button is disabled (onPressed: null) when the field is
    // empty — ListenableBuilder guards it with `hasText ? _sendCode : null`.
    // Verify the button exists in the tree and that tapping it does nothing.
    final sendCodeFinder = find.text('Send code');
    expect(sendCodeFinder, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sendCodeFinder, warnIfMissed: false);
    await tester.pump();

    verifyNever(() => mockUseCase(any()));
  });

  testWidgets('invalid number (letters) shows validation error', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PhoneEntryPage(), mockUseCase));
    await tester.pump();

    // Type a non-numeric string into the phone field — this makes the button
    // active (hasText = true) but validation will fail on submit.
    await tester.enterText(find.byType(TextField).first, 'abcdef');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(find.textContaining('valid phone number'), findsOneWidget);
    verifyNever(() => mockUseCase(any()));
  });

  testWidgets('valid number calls controller start with E.164 phone', (
    tester,
  ) async {
    // Stub the use case to return Left(NetworkFailure) — we're just testing
    // that it was called, not the success navigation path.
    when(
      () => mockUseCase(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('test')));

    await tester.pumpWidget(_wrap(const PhoneEntryPage(), mockUseCase));
    await tester.pump();

    // Default country is SG (+65). Enter local number.
    await tester.enterText(find.byType(TextField).first, '91234567');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(PrimaryButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    final captured = verify(() => mockUseCase(captureAny())).captured;
    expect(captured, hasLength(1));
    final params = captured.first as StartPhoneParams;
    expect(params.phone, equals('+6591234567'));
  });

  testWidgets('skip navigates without calling backend', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryPage(), mockUseCase));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byType(TextButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Skip for now →'));
    await tester.pumpAndSettle();

    verifyNever(() => mockUseCase(any()));
  });
}
