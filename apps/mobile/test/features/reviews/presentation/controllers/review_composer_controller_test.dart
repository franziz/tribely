import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/reviews/domain/entities/review.dart';
import 'package:tribely/src/features/reviews/domain/usecases/edit_review_usecase.dart';
import 'package:tribely/src/features/reviews/domain/usecases/submit_review_usecase.dart';
import 'package:tribely/src/features/reviews/presentation/providers/review_providers.dart';
import 'package:tribely/src/features/reviews/presentation/state/review_composer_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSubmitReviewUseCase extends Mock implements SubmitReviewUseCase {}

class MockEditReviewUseCase extends Mock implements EditReviewUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations
// ---------------------------------------------------------------------------

class FakeSubmitReviewParams extends Fake implements SubmitReviewParams {}

class FakeEditReviewParams extends Fake implements EditReviewParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Review _fakeReview({int rating = 4}) => Review(
  id: 'rev-1',
  eventId: 'evt-1',
  raterUserId: 'user-a',
  ratedUserId: 'user-b',
  rating: rating,
  hidden: false,
  createdAt: DateTime(2026, 5, 1),
);

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _makeContainer({
  required MockSubmitReviewUseCase submitUseCase,
  required MockEditReviewUseCase editUseCase,
}) {
  final container = ProviderContainer(
    overrides: [
      submitReviewUseCaseProvider.overrideWithValue(submitUseCase),
      editReviewUseCaseProvider.overrideWithValue(editUseCase),
    ],
  );
  // Keep the autoDispose provider alive for the duration of the test so
  // ref.mounted stays true while async methods are in-flight.
  container.listen(reviewComposerControllerProvider, (_, __) {});
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSubmitReviewParams());
    registerFallbackValue(FakeEditReviewParams());
  });

  late MockSubmitReviewUseCase submitUseCase;
  late MockEditReviewUseCase editUseCase;

  setUp(() {
    submitUseCase = MockSubmitReviewUseCase();
    editUseCase = MockEditReviewUseCase();
  });

  group('submit — Idle → Submitting → Success', () {
    test('transitions Idle → Success on successful submit', () async {
      when(
        () => submitUseCase(any()),
      ).thenAnswer((_) async => Right(_fakeReview()));

      final container = _makeContainer(
        submitUseCase: submitUseCase,
        editUseCase: editUseCase,
      );

      expect(
        container.read(reviewComposerControllerProvider),
        isA<ReviewComposerIdle>(),
      );

      await container
          .read(reviewComposerControllerProvider.notifier)
          .submit(eventId: 'evt-1', ratedUserId: 'user-b', rating: 4);

      await _pump();

      final state = container.read(reviewComposerControllerProvider);
      expect(state, isA<ReviewComposerSuccess>());
      expect((state as ReviewComposerSuccess).review.id, 'rev-1');
    });

    test('transitions Idle → Failure on error', () async {
      when(
        () => submitUseCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('no network')));

      final container = _makeContainer(
        submitUseCase: submitUseCase,
        editUseCase: editUseCase,
      );

      await container
          .read(reviewComposerControllerProvider.notifier)
          .submit(eventId: 'evt-1', ratedUserId: 'user-b', rating: 3);

      await _pump();

      final state = container.read(reviewComposerControllerProvider);
      expect(state, isA<ReviewComposerFailure>());
      expect((state as ReviewComposerFailure).message, isNotEmpty);
    });

    test('is a no-op when already Submitting', () async {
      // Use a Completer so the first submit stays in-flight indefinitely,
      // giving us a reliable window to observe the Submitting state.
      final completer = Completer<Either<Failure, Review>>();
      when(() => submitUseCase(any())).thenAnswer((_) => completer.future);

      final container = _makeContainer(
        submitUseCase: submitUseCase,
        editUseCase: editUseCase,
      );

      // Fire first submit without awaiting.
      // ignore: unawaited_futures
      container
          .read(reviewComposerControllerProvider.notifier)
          .submit(eventId: 'evt-1', ratedUserId: 'user-b', rating: 4);
      // Allow state to reach Submitting before the completer resolves.
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(reviewComposerControllerProvider),
        isA<ReviewComposerSubmitting>(),
      );

      // Second submit call must be a no-op.
      await container
          .read(reviewComposerControllerProvider.notifier)
          .submit(eventId: 'evt-1', ratedUserId: 'user-b', rating: 4);

      // Use case called exactly once.
      verify(() => submitUseCase(any())).called(1);

      // Complete so the container teardown doesn't hang.
      completer.complete(Right(_fakeReview()));
    });
  });

  group('edit — Idle → Submitting → Success', () {
    test('transitions to Success on 204', () async {
      when(() => editUseCase(any())).thenAnswer((_) async => const Right(null));

      final container = _makeContainer(
        submitUseCase: submitUseCase,
        editUseCase: editUseCase,
      );

      final original = _fakeReview(rating: 3);
      await container
          .read(reviewComposerControllerProvider.notifier)
          .edit(reviewId: 'rev-1', rating: 5, originalReview: original);

      await _pump();

      final state = container.read(reviewComposerControllerProvider);
      expect(state, isA<ReviewComposerSuccess>());
      // Rating should be updated locally.
      expect((state as ReviewComposerSuccess).review.rating, 5);
    });

    test(
      'transitions to Failure(editWindowExpired) on EditWindowExpiredFailure',
      () async {
        when(() => editUseCase(any())).thenAnswer(
          (_) async =>
              const Left(EditWindowExpiredFailure('Edit window expired')),
        );

        final container = _makeContainer(
          submitUseCase: submitUseCase,
          editUseCase: editUseCase,
        );

        final original = _fakeReview();
        await container
            .read(reviewComposerControllerProvider.notifier)
            .edit(reviewId: 'rev-1', rating: 5, originalReview: original);

        await _pump();

        final state = container.read(reviewComposerControllerProvider);
        expect(state, isA<ReviewComposerFailure>());
      },
    );
  });

  group('reset', () {
    test('returns to Idle from Failure', () async {
      when(
        () => submitUseCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('error')));

      final container = _makeContainer(
        submitUseCase: submitUseCase,
        editUseCase: editUseCase,
      );

      await container
          .read(reviewComposerControllerProvider.notifier)
          .submit(eventId: 'evt-1', ratedUserId: 'user-b', rating: 2);
      await _pump();

      expect(
        container.read(reviewComposerControllerProvider),
        isA<ReviewComposerFailure>(),
      );

      container.read(reviewComposerControllerProvider.notifier).reset();

      expect(
        container.read(reviewComposerControllerProvider),
        isA<ReviewComposerIdle>(),
      );
    });
  });
}
