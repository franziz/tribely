// Tests for the phone-revoked detection in SessionController.
//
// Covers:
//   1. phoneVerifiedAt !null → null transition sets phoneRevokedSinceLastSeen.
//   2. phoneVerifiedAt null → null (stays null) does NOT set the flag.
//   3. phoneVerifiedAt null → !null (verification) does NOT set the flag.
//   4. dismissPhoneRevokedBanner() resets the flag to false.
//   5. Cold-start (fresh build()) yields phoneRevokedSinceLastSeen = false.

import 'package:fake_async/fake_async.dart';
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
import 'package:tribely/src/features/auth/presentation/state/auth_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockRefreshSessionUseCase extends Mock
    implements RefreshSessionUseCase {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 18);

User _makeUser({DateTime? phoneVerifiedAt}) => User(
  id: 'usr-1',
  email: 'test@example.com',
  displayName: 'Test User',
  createdAt: _now,
  updatedAt: _now,
  emailVerifiedAt: _now,
  phoneVerifiedAt: phoneVerifiedAt,
);

AuthSession _makeSession(User user) => AuthSession(
  user: user,
  accessToken: 'at',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshToken: 'rt',
  refreshTokenExpiresAt: DateTime.utc(2099),
);

/// Builds a container with SessionController wired to a mock refresh use case
/// that returns [refreshResult]. If [refreshResult] is null, the refresh hangs
/// (returns a Completer that never completes) — useful for keeping state in
/// SessionRestoring so we can call setUser directly.
ProviderContainer _makeContainer(
  _MockRefreshSessionUseCase mockRefresh, {
  SessionState? initialAuthState,
}) {
  final container = ProviderContainer(
    overrides: [refreshSessionUseCaseProvider.overrideWithValue(mockRefresh)],
  );
  addTearDown(container.dispose);

  // Trigger build (async — don't pump yet).
  container.read(sessionControllerProvider);

  // If we want an authenticated starting state, set it directly.
  if (initialAuthState != null) {
    container
        .read(sessionControllerProvider.notifier)
        .setAuthenticated((initialAuthState as SessionAuthenticated).session);
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
    // Default: refresh never returns (keeps state in Restoring during pump).
    when(() => mockRefresh(any())).thenAnswer(
      (_) async => const Left(AuthFailure('No stored refresh token')),
    );
  });

  group('SessionController — phoneRevokedSinceLastSeen derivation', () {
    test('cold-start: phoneRevokedSinceLastSeen defaults to false', () {
      // SessionController._runInitialRestore awaits Future.wait([refresh, minHold])
      // where minHold = Duration(seconds: 1). We must advance fake time past 1s
      // to let the state transition from SessionRestoring → SessionUnauthenticated.
      fakeAsync((clock) {
        final container = _makeContainer(mockRefresh);
        // Flush the microtasks (refresh result resolves immediately).
        clock.flushMicrotasks();
        // State is still SessionRestoring — minSplashHold (1s) hasn't elapsed yet.
        expect(
          container.read(sessionControllerProvider),
          isA<SessionRestoring>(),
        );
        // Advance past the splash hold.
        clock.elapse(const Duration(seconds: 2));
        final state = container.read(sessionControllerProvider);
        // After refresh returns "no token" → SessionUnauthenticated.
        // There is no phoneRevokedSinceLastSeen on unauthenticated states.
        // The flag is only on SessionAuthenticated.
        expect(state, isA<SessionUnauthenticated>());
      });
    });

    test(
      'setAuthenticated produces phoneRevokedSinceLastSeen = false by default',
      () async {
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        final user = _makeUser(phoneVerifiedAt: _now);
        container
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(user));

        final state = container.read(sessionControllerProvider);
        expect(state, isA<SessionAuthenticated>());
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isFalse,
        );
      },
    );

    test(
      'setUser with phoneVerifiedAt null→null does NOT set revoked flag',
      () async {
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        // Start with phone already null (unverified from the start).
        final user = _makeUser(phoneVerifiedAt: null);
        container
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(user));

        // Update with another user where phone is still null.
        final updatedUser = _makeUser(phoneVerifiedAt: null);
        container.read(sessionControllerProvider.notifier).setUser(updatedUser);

        final state = container.read(sessionControllerProvider);
        expect(state, isA<SessionAuthenticated>());
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isFalse,
        );
      },
    );

    test(
      'setUser with phoneVerifiedAt !null → null sets phoneRevokedSinceLastSeen',
      () async {
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        // Start with phone verified.
        final user = _makeUser(phoneVerifiedAt: _now);
        container
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(user));

        // Server revokes the phone — phoneVerifiedAt becomes null.
        final revokedUser = _makeUser(phoneVerifiedAt: null);
        container.read(sessionControllerProvider.notifier).setUser(revokedUser);

        final state = container.read(sessionControllerProvider);
        expect(state, isA<SessionAuthenticated>());
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isTrue,
        );
      },
    );

    test(
      'setUser with phoneVerifiedAt null → !null does NOT set revoked flag',
      () async {
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        // Start with phone unverified.
        final user = _makeUser(phoneVerifiedAt: null);
        container
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(user));

        // User verifies their phone.
        final verifiedUser = _makeUser(phoneVerifiedAt: _now);
        container
            .read(sessionControllerProvider.notifier)
            .setUser(verifiedUser);

        final state = container.read(sessionControllerProvider);
        expect(state, isA<SessionAuthenticated>());
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isFalse,
        );
      },
    );

    test('dismissPhoneRevokedBanner() resets flag to false', () async {
      final container = _makeContainer(mockRefresh);
      await Future<void>.microtask(() {});

      // Set up revoked state.
      final user = _makeUser(phoneVerifiedAt: _now);
      container
          .read(sessionControllerProvider.notifier)
          .setAuthenticated(_makeSession(user));
      container
          .read(sessionControllerProvider.notifier)
          .setUser(_makeUser(phoneVerifiedAt: null));

      // Verify flag is set.
      final stateBefore = container.read(sessionControllerProvider);
      expect(
        (stateBefore as SessionAuthenticated).phoneRevokedSinceLastSeen,
        isTrue,
      );

      // Dismiss.
      container
          .read(sessionControllerProvider.notifier)
          .dismissPhoneRevokedBanner();

      final stateAfter = container.read(sessionControllerProvider);
      expect(
        (stateAfter as SessionAuthenticated).phoneRevokedSinceLastSeen,
        isFalse,
      );
    });

    test(
      'dismissPhoneRevokedBanner() is a no-op when flag is already false',
      () async {
        final container = _makeContainer(mockRefresh);
        await Future<void>.microtask(() {});

        final user = _makeUser(phoneVerifiedAt: _now);
        container
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(user));

        // Flag is false — dismiss should not throw or change state.
        container
            .read(sessionControllerProvider.notifier)
            .dismissPhoneRevokedBanner();

        final state = container.read(sessionControllerProvider);
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isFalse,
        );
      },
    );

    test(
      'app cold-start: flag resets to false (transient — not persisted)',
      () {
        // Cold-start = brand new container / provider. Since the flag is in
        // transient in-memory state (not SecureStorage or SharedPreferences),
        // a new ProviderContainer produces fresh state with flag = false.
        // We call setAuthenticated directly to bypass the async restore path.
        final container2 = ProviderContainer(
          overrides: [
            refreshSessionUseCaseProvider.overrideWithValue(mockRefresh),
          ],
        );
        addTearDown(container2.dispose);

        // Trigger build first (synchronous read).
        container2.read(sessionControllerProvider);

        // Override with a direct authenticated state — this bypasses the
        // 1-second splash hold timer.
        container2
            .read(sessionControllerProvider.notifier)
            .setAuthenticated(_makeSession(_makeUser(phoneVerifiedAt: _now)));

        // The flag has never been set in this container.
        final state = container2.read(sessionControllerProvider);
        expect(
          (state as SessionAuthenticated).phoneRevokedSinceLastSeen,
          isFalse,
        );
      },
    );
  });
}
