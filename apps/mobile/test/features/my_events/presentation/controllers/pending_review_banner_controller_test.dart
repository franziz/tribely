// Unit tests for PendingReviewBannerController.
//
// Covers:
//   1. Init → fetches → Visible(prompt) when the use case returns a prompt.
//   2. Init → fetches → None when the use case returns null.
//   3. dismiss() → Dismissed.
//   4. onComposerNavigated() → Dismissed.
//   5. App lifecycle resume → re-fetches when not Dismissed.
//   6. App lifecycle resume → skipped when already Dismissed.
//   7. Failure → None (silent degradation so the page body isn't blocked).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/core/lifecycle/app_lifecycle_provider.dart';
import 'package:tribely/src/core/usecase/usecase.dart';
import 'package:tribely/src/features/my_events/presentation/controllers/pending_review_banner_controller.dart';
import 'package:tribely/src/features/my_events/presentation/state/pending_review_banner_state.dart';
import 'package:tribely/src/features/reviews/domain/entities/pending_review_prompt.dart';
import 'package:tribely/src/features/reviews/domain/usecases/get_pending_review_prompt_usecase.dart';
import 'package:tribely/src/features/reviews/presentation/providers/review_providers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockGetPendingReviewPromptUseCase extends Mock
    implements GetPendingReviewPromptUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations
// ---------------------------------------------------------------------------

class FakeNoParams extends Fake implements NoParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _kPrompt = PendingReviewPrompt(
  eventId: 'evt-1',
  eventTitle: 'Dinner at Lau Pa Sat',
  eventEndedAt: DateTime.utc(2026, 5, 10, 19),
  ratedUserId: 'user-b',
  ratedUserDisplayName: 'Mei',
  ratedUserAvatarUrl: null,
);

/// Pump microtasks: flushes the Future(() => ...) in build() and any
/// subsequent state transitions.
Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Builds a container with [PendingReviewBannerController] wired to [mockUseCase]
/// and a controllable lifecycle stream via [lifecycleController].
ProviderContainer _makeContainer({
  required MockGetPendingReviewPromptUseCase mockUseCase,
  StreamController<AppLifecycleState>? lifecycleController,
}) {
  final container = ProviderContainer(
    overrides: [
      getPendingReviewPromptUseCaseProvider.overrideWithValue(mockUseCase),
      if (lifecycleController != null)
        appLifecycleProvider.overrideWith((ref) => lifecycleController.stream),
    ],
  );
  addTearDown(container.dispose);
  // Add a listener to prevent autoDispose from firing during the test.
  // Without a listener, autoDispose can evict the provider before the
  // scheduled microtask in build() completes.
  final subscription = container.listen(
    pendingReviewBannerControllerProvider,
    (prev, next) {},
  );
  addTearDown(subscription.close);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNoParams());
  });

  // -------------------------------------------------------------------------
  // 1. Init → Visible when use case returns a prompt
  // -------------------------------------------------------------------------
  test('init → Visible(prompt) when use case returns a prompt', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(() => mock(any())).thenAnswer((_) async => Right(_kPrompt));

    final container = _makeContainer(mockUseCase: mock);
    await _pump();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerVisible>());
    expect((state as PendingReviewBannerVisible).prompt, equals(_kPrompt));
  });

  // -------------------------------------------------------------------------
  // 2. Init → None when use case returns null
  // -------------------------------------------------------------------------
  test('init → None when use case returns null', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(() => mock(any())).thenAnswer((_) async => const Right(null));

    final container = _makeContainer(mockUseCase: mock);
    await _pump();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerNone>());
  });

  // -------------------------------------------------------------------------
  // 3. dismiss() → Dismissed
  // -------------------------------------------------------------------------
  test('dismiss() → Dismissed', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(() => mock(any())).thenAnswer((_) async => Right(_kPrompt));

    final container = _makeContainer(mockUseCase: mock);
    await _pump();

    container.read(pendingReviewBannerControllerProvider.notifier).dismiss();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerDismissed>());
  });

  // -------------------------------------------------------------------------
  // 4. onComposerNavigated() → Dismissed
  // -------------------------------------------------------------------------
  test('onComposerNavigated() → Dismissed', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(() => mock(any())).thenAnswer((_) async => Right(_kPrompt));

    final container = _makeContainer(mockUseCase: mock);
    await _pump();

    container
        .read(pendingReviewBannerControllerProvider.notifier)
        .onComposerNavigated();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerDismissed>());
  });

  // -------------------------------------------------------------------------
  // 5. App lifecycle resume → re-fetches when not Dismissed
  // -------------------------------------------------------------------------
  test('app lifecycle resume → re-fetches when not Dismissed', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    // First call returns null, second returns prompt — tests the re-fetch path.
    var callCount = 0;
    when(() => mock(any())).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) return const Right(null);
      return Right(_kPrompt);
    });

    final lifecycleController = StreamController<AppLifecycleState>.broadcast();

    final container = _makeContainer(
      mockUseCase: mock,
      lifecycleController: lifecycleController,
    );
    await _pump();
    expect(
      container.read(pendingReviewBannerControllerProvider),
      isA<PendingReviewBannerNone>(),
    );

    // Simulate app returning to foreground.
    lifecycleController.add(AppLifecycleState.resumed);
    await _pump();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerVisible>());
    await lifecycleController.close();
  });

  // -------------------------------------------------------------------------
  // 6. App lifecycle resume → skipped when already Dismissed
  // -------------------------------------------------------------------------
  test('app lifecycle resume → skipped when already Dismissed', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(() => mock(any())).thenAnswer((_) async => Right(_kPrompt));

    final lifecycleController = StreamController<AppLifecycleState>.broadcast();

    final container = _makeContainer(
      mockUseCase: mock,
      lifecycleController: lifecycleController,
    );
    await _pump();

    container.read(pendingReviewBannerControllerProvider.notifier).dismiss();

    // Simulate resume — should not trigger a new fetch.
    lifecycleController.add(AppLifecycleState.resumed);
    await _pump();

    // Still Dismissed, not Visible/Loading/None.
    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerDismissed>());

    // Use case was called exactly once (initial build), not again on resume.
    verify(() => mock(any())).called(1);
    await lifecycleController.close();
  });

  // -------------------------------------------------------------------------
  // 7. Failure → None (silent degradation)
  // -------------------------------------------------------------------------
  test('failure → None so the page body is not blocked', () async {
    final mock = MockGetPendingReviewPromptUseCase();
    when(
      () => mock(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('connection refused')));

    final container = _makeContainer(mockUseCase: mock);
    await _pump();

    final state = container.read(pendingReviewBannerControllerProvider);
    expect(state, isA<PendingReviewBannerNone>());
  });
}
