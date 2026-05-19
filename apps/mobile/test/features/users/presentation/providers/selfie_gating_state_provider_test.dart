// Tests for selfieGatingStateProvider.
//
// Covers all five mapping combinations from the AC:
//   1. selfieStatus == 'notStarted' → SelfieGatingNotStarted
//   2. selfieStatus == 'pending'    → SelfieGatingPending
//   3. selfieStatus == 'rejected' && selfieAppealLockedAt == null → SelfieGatingFailed
//   4. selfieStatus == 'rejected' && selfieAppealLockedAt != null → SelfieGatingLocked
//   5. selfieStatus == 'approved'   → SelfieGatingApproved
//
// Also covers:
//   6. Unauthenticated session → SelfieGatingNotStarted (safe default)
//   7. Provider rebuilds when a selfie field changes, not on unrelated changes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/auth/domain/entities/auth_session.dart';
import 'package:tribely/src/features/auth/domain/entities/user.dart';
import 'package:tribely/src/features/auth/domain/usecases/refresh_session_usecase.dart';
import 'package:tribely/src/features/auth/presentation/providers/auth_providers.dart';
import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockRefreshSessionUseCase extends Mock
    implements RefreshSessionUseCase {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 19);

User _makeUser({
  String selfieStatus = 'notStarted',
  int selfieAttemptCount = 0,
  SelfieFailureCategory? selfieLastFailureCategory,
  DateTime? selfieAppealLockedAt,
}) => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: _now,
  selfieStatus: selfieStatus,
  selfieAttemptCount: selfieAttemptCount,
  selfieLastFailureCategory: selfieLastFailureCategory,
  selfieAppealLockedAt: selfieAppealLockedAt,
);

AuthSession _makeSession(User user) => AuthSession(
  user: user,
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

/// Builds a [ProviderContainer] with SessionController wired to a mock refresh
/// use case that returns "no stored token" (keeps the state flowing to
/// SessionUnauthenticated after splash hold).
///
/// Pass [authenticatedUser] to immediately set an authenticated session via
/// [SessionController.setAuthenticated] (synchronous, bypasses the async
/// restore path).
ProviderContainer _makeContainer(
  _MockRefreshSessionUseCase mockRefresh, {
  User? authenticatedUser,
}) {
  final container = ProviderContainer(
    overrides: [refreshSessionUseCaseProvider.overrideWithValue(mockRefresh)],
  );
  addTearDown(container.dispose);

  // Trigger build — async restore kicks off but we don't await it here.
  container.read(sessionControllerProvider);

  if (authenticatedUser != null) {
    container
        .read(sessionControllerProvider.notifier)
        .setAuthenticated(_makeSession(authenticatedUser));
  }

  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => registerFallbackValue(_FakeNoParams()));

  late _MockRefreshSessionUseCase mockRefresh;

  setUp(() {
    mockRefresh = _MockRefreshSessionUseCase();
    // Default: no stored token — refresh resolves immediately as unauthenticated.
    when(() => mockRefresh(any())).thenAnswer(
      (_) async => const Left(AuthFailure('No stored refresh token')),
    );
  });

  group('selfieGatingStateProvider', () {
    test('1. notStarted status → SelfieGatingNotStarted', () async {
      final container = _makeContainer(
        mockRefresh,
        authenticatedUser: _makeUser(selfieStatus: 'notStarted'),
      );
      await Future<void>.microtask(() {});

      expect(
        container.read(selfieGatingStateProvider),
        isA<SelfieGatingNotStarted>(),
      );
    });

    test('2. pending status → SelfieGatingPending', () async {
      final container = _makeContainer(
        mockRefresh,
        authenticatedUser: _makeUser(selfieStatus: 'pending'),
      );
      await Future<void>.microtask(() {});

      expect(
        container.read(selfieGatingStateProvider),
        isA<SelfieGatingPending>(),
      );
    });

    test(
      '3. rejected + no appeal lock → SelfieGatingFailed with correct fields',
      () async {
        final container = _makeContainer(
          mockRefresh,
          authenticatedUser: _makeUser(
            selfieStatus: 'rejected',
            selfieAttemptCount: 2,
            selfieLastFailureCategory: SelfieFailureCategory.poorLighting,
          ),
        );
        await Future<void>.microtask(() {});

        final state = container.read(selfieGatingStateProvider);
        expect(state, isA<SelfieGatingFailed>());
        final failed = state as SelfieGatingFailed;
        expect(failed.category, SelfieFailureCategory.poorLighting);
        expect(failed.attemptCount, 2);
      },
    );

    test(
      '4. rejected + appeal lock set → SelfieGatingLocked with correct category',
      () async {
        final container = _makeContainer(
          mockRefresh,
          authenticatedUser: _makeUser(
            selfieStatus: 'rejected',
            selfieAttemptCount: 3,
            selfieLastFailureCategory: SelfieFailureCategory.faceNotVisible,
            selfieAppealLockedAt: _now.add(const Duration(days: 7)),
          ),
        );
        await Future<void>.microtask(() {});

        final state = container.read(selfieGatingStateProvider);
        expect(state, isA<SelfieGatingLocked>());
        final locked = state as SelfieGatingLocked;
        expect(locked.category, SelfieFailureCategory.faceNotVisible);
      },
    );

    test('5. approved status → SelfieGatingApproved', () async {
      final container = _makeContainer(
        mockRefresh,
        authenticatedUser: _makeUser(selfieStatus: 'approved'),
      );
      await Future<void>.microtask(() {});

      expect(
        container.read(selfieGatingStateProvider),
        isA<SelfieGatingApproved>(),
      );
    });

    test(
      '6. unauthenticated session → SelfieGatingNotStarted (safe default)',
      () async {
        // Do NOT pass authenticatedUser — session stays unauthenticated.
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        // Session state is SessionRestoring or SessionUnauthenticated here —
        // provider must return the safe default either way.
        expect(
          container.read(selfieGatingStateProvider),
          isA<SelfieGatingNotStarted>(),
        );
      },
    );

    test(
      '7. provider rebuilds when selfie status changes, not on unrelated field change',
      () async {
        final user = _makeUser(selfieStatus: 'notStarted');
        final container = _makeContainer(mockRefresh, authenticatedUser: user);
        await Future<void>.microtask(() {});

        // Confirm initial state.
        expect(
          container.read(selfieGatingStateProvider),
          isA<SelfieGatingNotStarted>(),
        );

        // Change selfieStatus to 'pending' — provider SHOULD rebuild.
        container
            .read(sessionControllerProvider.notifier)
            .setUser(user.copyWith(selfieStatus: 'pending'));

        expect(
          container.read(selfieGatingStateProvider),
          isA<SelfieGatingPending>(),
        );

        // Change a non-selfie field (updatedAt) — state should remain Pending
        // and the select should still derive the same output.
        container
            .read(sessionControllerProvider.notifier)
            .setUser(
              user.copyWith(
                selfieStatus: 'pending',
                updatedAt: _now.add(const Duration(minutes: 5)),
              ),
            );

        expect(
          container.read(selfieGatingStateProvider),
          isA<SelfieGatingPending>(),
        );
      },
    );

    test(
      'SelfieGatingFailed with null category is valid (legacy/unknown rejection)',
      () async {
        final container = _makeContainer(
          mockRefresh,
          authenticatedUser: _makeUser(
            selfieStatus: 'rejected',
            selfieAttemptCount: 1,
          ),
        );
        await Future<void>.microtask(() {});

        final state = container.read(selfieGatingStateProvider);
        expect(state, isA<SelfieGatingFailed>());
        expect((state as SelfieGatingFailed).category, isNull);
      },
    );
  });
}
