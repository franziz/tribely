import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/reviews/domain/entities/review_eligibility.dart';
import 'package:tribely/src/features/reviews/domain/usecases/get_review_eligibility_usecase.dart';
import 'package:tribely/src/features/reviews/presentation/providers/review_providers.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockGetReviewEligibilityUseCase extends Mock
    implements GetReviewEligibilityUseCase {}

// ---------------------------------------------------------------------------
// Fake registrations
// ---------------------------------------------------------------------------

class FakeGetReviewEligibilityParams extends Fake
    implements GetReviewEligibilityParams {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(GetReviewEligibilityUseCase useCase) {
  final container = ProviderContainer(
    overrides: [getReviewEligibilityUseCaseProvider.overrideWithValue(useCase)],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGetReviewEligibilityParams());
  });

  late MockGetReviewEligibilityUseCase useCase;

  setUp(() {
    useCase = MockGetReviewEligibilityUseCase();
  });

  group('reviewEligibilityProvider', () {
    test(
      'resolves to ReviewEligibility(eligible: true) when use case returns Right',
      () async {
        const eligibility = ReviewEligibility(
          eligible: true,
          ratedUserId: 'host-1',
          hostDisplayName: 'Alice',
        );

        when(
          () => useCase(any()),
        ).thenAnswer((_) async => const Right(eligibility));

        final container = _makeContainer(useCase);

        final result = await container.read(
          reviewEligibilityProvider('evt-1').future,
        );

        expect(result.eligible, isTrue);
        expect(result.ratedUserId, 'host-1');
        expect(result.hostDisplayName, 'Alice');
      },
    );

    test(
      'resolves to ReviewEligibility(eligible: false) when server returns ineligible',
      () async {
        const eligibility = ReviewEligibility(
          eligible: false,
          ratedUserId: null,
          hostDisplayName: null,
        );

        when(
          () => useCase(any()),
        ).thenAnswer((_) async => const Right(eligibility));

        final container = _makeContainer(useCase);

        final result = await container.read(
          reviewEligibilityProvider('evt-1').future,
        );

        expect(result.eligible, isFalse);
        expect(result.ratedUserId, isNull);
      },
    );

    test('throws when use case returns Left(Failure)', () async {
      when(
        () => useCase(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('no network')));

      // Disable Riverpod 3's exponential-backoff retry so the first thrown
      // body is terminal and .future settles immediately under fake-async.
      // Without retry: null the provider re-queues indefinitely and .future
      // never resolves ("provider disposed during loading state", 30s timeout).
      // Pattern consistent with check_ins_controller_test / discover_controller_test.
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          getReviewEligibilityUseCaseProvider.overrideWithValue(useCase),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(reviewEligibilityProvider('evt-1').future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test(
      'uses eventId as family key — different eventIds get separate providers',
      () async {
        const eligibilityA = ReviewEligibility(
          eligible: true,
          ratedUserId: 'host-a',
          hostDisplayName: 'Alice',
        );
        const eligibilityB = ReviewEligibility(
          eligible: false,
          ratedUserId: null,
          hostDisplayName: null,
        );

        when(
          () => useCase(const GetReviewEligibilityParams(eventId: 'evt-a')),
        ).thenAnswer((_) async => const Right(eligibilityA));

        when(
          () => useCase(const GetReviewEligibilityParams(eventId: 'evt-b')),
        ).thenAnswer((_) async => const Right(eligibilityB));

        final container = _makeContainer(useCase);

        final resultA = await container.read(
          reviewEligibilityProvider('evt-a').future,
        );
        final resultB = await container.read(
          reviewEligibilityProvider('evt-b').future,
        );

        expect(resultA.eligible, isTrue);
        expect(resultB.eligible, isFalse);
      },
    );
  });
}
