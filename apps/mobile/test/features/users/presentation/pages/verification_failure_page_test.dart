// Widget tests for VerificationFailurePage.
//
// Covers:
//   1. Category copy: poorLighting body rendered correctly.
//   2. Category copy: faceNotVisible body rendered correctly.
//   3. Category copy: qualityTooLow body rendered correctly.
//   4. Category copy: other body rendered correctly.
//   5. Locked state: "Attempt 3 of 3 — locked for now" shown with lock icon.
//   6. Locked state: "Contact support" CTA shown.
//   7. Locked state: SLA line "We'll respond within 3 business days." shown.
//   8. Non-locked state: "Try again" CTA shown.
//   9. Non-locked state: attempt counter shows attempt N of 3.
//  10. "View verification settings" tertiary link is present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/auth/domain/usecases/refresh_session_usecase.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';
import 'package:tribely/src/features/users/presentation/controllers/verification_failure_controller.dart';
import 'package:tribely/src/features/users/presentation/pages/verification_failure_page.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';
import 'package:tribely/src/features/users/presentation/state/verification_failure_state.dart';
import 'package:tribely/src/features/users/presentation/string_assets/verification_failure_copy.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockRefreshSession extends Mock implements RefreshSessionUseCase {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Stable no-op controller override
// ---------------------------------------------------------------------------

class _NoopVerificationFailureController extends VerificationFailureController {
  @override
  VerificationFailureState build() => const VerificationFailureIdle();

  @override
  Future<void> openMailClient() async {}
}

// ---------------------------------------------------------------------------
// Test wrapper
// ---------------------------------------------------------------------------

Widget _buildApp({
  required SelfieGatingState gatingState,
  _MockRefreshSession? mockRefresh,
}) {
  final mock = mockRefresh ?? _MockRefreshSession();
  when(
    () => mock(any()),
  ).thenAnswer((_) async => const Left(AuthFailure('No stored refresh token')));

  return ProviderScope(
    overrides: [
      refreshSessionUseCaseProvider.overrideWithValue(mock),
      selfieGatingStateProvider.overrideWithValue(gatingState),
      verificationFailureControllerProvider.overrideWith(
        _NoopVerificationFailureController.new,
      ),
    ],
    child: const MaterialApp(home: VerificationFailurePage()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => registerFallbackValue(_FakeNoParams()));

  group('VerificationFailurePage — category copy', () {
    testWidgets('1. poorLighting body copy', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.poorLighting,
            attemptCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('dark'), findsWidgets);
    });

    testWidgets('2. faceNotVisible body copy', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.faceNotVisible,
            attemptCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining("couldn't clearly see your face"),
        findsWidgets,
      );
    });

    testWidgets('3. qualityTooLow body copy', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.qualityTooLow,
            attemptCount: 2,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('blurry'), findsWidgets);
    });

    testWidgets('4. other body copy', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.other,
            attemptCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining("wasn't quite right"), findsWidgets);
    });
  });

  group('VerificationFailurePage — locked state', () {
    testWidgets('5. Locked: "locked for now" counter with lock icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingLocked(
            category: SelfieFailureCategory.poorLighting,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('locked for now'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    });

    testWidgets('6. Locked: "Contact support" CTA', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingLocked(
            category: SelfieFailureCategory.faceNotVisible,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Contact support'), findsOneWidget);
    });

    testWidgets('7. Locked: SLA line shown', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingLocked(
            category: SelfieFailureCategory.other,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(kSlaLine), findsOneWidget);
    });
  });

  group('VerificationFailurePage — non-locked state', () {
    testWidgets('8. Non-locked: "Try again" CTA', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.poorLighting,
            attemptCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('9. Non-locked: attempt counter shows "Attempt N of 3"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.qualityTooLow,
            attemptCount: 2,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Attempt 2 of 3'), findsOneWidget);
    });
  });

  group('VerificationFailurePage — common', () {
    testWidgets('10. "View verification settings" tertiary link present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          gatingState: const SelfieGatingFailed(
            category: SelfieFailureCategory.poorLighting,
            attemptCount: 1,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('View verification settings'), findsOneWidget);
    });
  });
}
