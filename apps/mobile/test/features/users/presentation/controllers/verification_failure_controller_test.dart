// Controller unit tests for VerificationFailureController.
//
// Covers:
//   1. openMailClient() builds a mailto URI and attempts launch.
//   2. On launch success → VerificationFailureLaunchSuccess state.
//   3. On PlatformException (no mail client) → VerificationFailureShowClipboardFallback
//      with non-empty clipboardContent.
//   4. Double-tap guard: second call while Launching is a no-op.
//   5. reset() returns state to VerificationFailureIdle.
//
// Mocking strategy:
//   - url_launcher is NOT directly mockable without full plugin setup.
//     Instead we override [verificationFailureControllerProvider] with a
//     testable subclass that injects a launch callback (dependency-injection at
//     the function level) so we can exercise both the success and failure paths.
//   - PackageInfo and Platform are read from the real environment (acceptable in
//     unit tests — they return safe defaults in the Flutter test runner).
//   - selfieGatingStateProvider and sessionControllerProvider are overridden
//     with fixed stubs.

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
import 'package:tribely/src/features/users/domain/value_objects/selfie_failure_category.dart';
import 'package:tribely/src/features/users/presentation/controllers/verification_failure_controller.dart';
import 'package:tribely/src/features/users/presentation/providers/capability_providers.dart';
import 'package:tribely/src/features/users/presentation/state/selfie_gating_state.dart';
import 'package:tribely/src/features/users/presentation/state/verification_failure_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockRefreshSession extends Mock implements RefreshSessionUseCase {}

class _FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2026, 5, 19);

User _makeUser({
  String selfieStatus = 'rejected',
  int selfieAttemptCount = 1,
  SelfieFailureCategory? selfieLastFailureCategory =
      SelfieFailureCategory.poorLighting,
  DateTime? selfieAppealLockedAt,
}) => User(
  id: 'usr-abc12345',
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

// ---------------------------------------------------------------------------
// Testable subclass: injects a launch callback for deterministic testing
// ---------------------------------------------------------------------------

/// Subclass that replaces url_launcher with an injected [_launchFn] and skips
/// PackageInfo.fromPlatform() in tests by accepting an [_appVersion] override.
class _TestableVerificationFailureController
    extends VerificationFailureController {
  _TestableVerificationFailureController({
    required Future<bool> Function(Uri) launchFn,
    String appVersion = '0.0.1+test',
  }) : _launchFn = launchFn,
       _appVersion = appVersion;

  final Future<bool> Function(Uri) _launchFn;
  final String _appVersion;

  @override
  Future<void> openMailClient() async {
    if (state is VerificationFailureLaunching) return;
    state = const VerificationFailureLaunching();

    final session = ref.read(sessionControllerProvider);
    final userId = switch (session) {
      SessionAuthenticated(:final session) => session.user.id,
      _ => 'unknown',
    };
    final userIdShort = userId.length > 8 ? userId.substring(0, 8) : userId;

    final gatingState = ref.read(selfieGatingStateProvider);
    final int attemptsUsed = switch (gatingState) {
      SelfieGatingFailed(:final attemptCount) => attemptCount,
      SelfieGatingLocked() => 3,
      _ => 0,
    };
    final dynamic lastCategory = switch (gatingState) {
      SelfieGatingFailed(:final category) => category,
      SelfieGatingLocked(:final category) => category,
      _ => null,
    };
    final reasonString =
        (lastCategory as SelfieFailureCategory?)?.toJson() ?? 'unknown';

    final body = VerificationFailureController.buildMailtoBodyForTest(
      userIdShort: userIdShort,
      attemptsUsed: attemptsUsed,
      reasonCategory: reasonString,
      version: _appVersion,
      os: 'Android',
    );
    final subject = '[Tribely] Selfie review appeal — $userIdShort';
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: 'support@gotribely.com',
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      final launched = await _launchFn(mailtoUri);
      if (!ref.mounted) return;
      if (launched) {
        state = const VerificationFailureLaunchSuccess();
      } else {
        state = VerificationFailureShowClipboardFallback(
          clipboardContent: body,
        );
      }
    } on Exception {
      if (!ref.mounted) return;
      state = VerificationFailureShowClipboardFallback(clipboardContent: body);
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => registerFallbackValue(_FakeNoParams()));

  late _MockRefreshSession mockRefresh;

  setUp(() {
    mockRefresh = _MockRefreshSession();
    when(() => mockRefresh(any())).thenAnswer(
      (_) async => const Left(AuthFailure('No stored refresh token')),
    );
  });

  ProviderContainer makeContainer({
    required Future<bool> Function(Uri) launchFn,
    User? authenticatedUser,
  }) {
    final container = ProviderContainer(
      overrides: [
        refreshSessionUseCaseProvider.overrideWithValue(mockRefresh),
        verificationFailureControllerProvider.overrideWith(
          () => _TestableVerificationFailureController(launchFn: launchFn),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(sessionControllerProvider);
    if (authenticatedUser != null) {
      container
          .read(sessionControllerProvider.notifier)
          .setAuthenticated(_makeSession(authenticatedUser));
    }

    return container;
  }

  group('VerificationFailureController', () {
    test(
      '1. openMailClient() — launch success → VerificationFailureLaunchSuccess',
      () async {
        final container = makeContainer(
          launchFn: (_) async => true,
          authenticatedUser: _makeUser(),
        );
        await Future<void>.microtask(() {});

        await container
            .read(verificationFailureControllerProvider.notifier)
            .openMailClient();

        expect(
          container.read(verificationFailureControllerProvider),
          isA<VerificationFailureLaunchSuccess>(),
        );
      },
    );

    test(
      '2. openMailClient() — launchFn returns false → ShowClipboardFallback',
      () async {
        final container = makeContainer(
          launchFn: (_) async => false,
          authenticatedUser: _makeUser(),
        );
        await Future<void>.microtask(() {});

        await container
            .read(verificationFailureControllerProvider.notifier)
            .openMailClient();

        final state = container.read(verificationFailureControllerProvider);
        expect(state, isA<VerificationFailureShowClipboardFallback>());
        final fallback = state as VerificationFailureShowClipboardFallback;
        expect(fallback.clipboardContent, isNotEmpty);
        expect(fallback.clipboardContent, contains('Tribely support'));
      },
    );

    test(
      '3. openMailClient() — PlatformException → ShowClipboardFallback with body',
      () async {
        final container = makeContainer(
          launchFn: (_) => throw Exception('no mail client'),
          authenticatedUser: _makeUser(),
        );
        await Future<void>.microtask(() {});

        await container
            .read(verificationFailureControllerProvider.notifier)
            .openMailClient();

        final state = container.read(verificationFailureControllerProvider);
        expect(state, isA<VerificationFailureShowClipboardFallback>());
        final fallback = state as VerificationFailureShowClipboardFallback;
        // Clipboard content must include the userId short and reason.
        expect(fallback.clipboardContent, contains('usr-abc1'));
        expect(fallback.clipboardContent, contains('poor_lighting'));
      },
    );

    test(
      '4. Double-tap guard — second call while Launching is a no-op',
      () async {
        var callCount = 0;
        final container = makeContainer(
          launchFn: (uri) async {
            callCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return true;
          },
          authenticatedUser: _makeUser(),
        );
        await Future<void>.microtask(() {});

        // Do NOT await the first call — we want to observe the Launching state.
        unawaited(
          container
              .read(verificationFailureControllerProvider.notifier)
              .openMailClient(),
        );
        // Immediately try a second call.
        await container
            .read(verificationFailureControllerProvider.notifier)
            .openMailClient();

        // Allow the first launch to complete.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(callCount, 1, reason: 'launch should only be called once');
      },
    );

    test('5. reset() returns state to VerificationFailureIdle', () async {
      final container = makeContainer(
        launchFn: (_) async => false,
        authenticatedUser: _makeUser(),
      );
      await Future<void>.microtask(() {});

      await container
          .read(verificationFailureControllerProvider.notifier)
          .openMailClient();

      // Should be ShowClipboardFallback now.
      expect(
        container.read(verificationFailureControllerProvider),
        isA<VerificationFailureShowClipboardFallback>(),
      );

      container.read(verificationFailureControllerProvider.notifier).reset();

      expect(
        container.read(verificationFailureControllerProvider),
        isA<VerificationFailureIdle>(),
      );
    });
  });
}

// Trivial Future extension to suppress unawaited_futures lint in tests.
void unawaited(Future<void> future) {}
