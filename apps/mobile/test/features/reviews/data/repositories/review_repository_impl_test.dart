import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tribely/src/core/error/exceptions.dart';
import 'package:tribely/src/core/error/failures.dart';
import 'package:tribely/src/features/reviews/data/datasources/review_remote_datasource.dart';
import 'package:tribely/src/features/reviews/data/models/review_list_page_model.dart';
import 'package:tribely/src/features/reviews/data/models/review_model.dart';
import 'package:tribely/src/features/reviews/data/repositories/review_repository_impl.dart';
import 'package:tribely/src/features/reviews/domain/entities/review.dart';
import 'package:tribely/src/features/reviews/domain/entities/review_list_page.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockReviewRemoteDatasource extends Mock
    implements ReviewRemoteDatasource {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ReviewModel _fakeReviewModel() => ReviewModel(
  id: 'rev-1',
  eventId: 'evt-1',
  raterUserId: 'user-a',
  ratedUserId: 'user-b',
  rating: 4,
  hidden: false,
  createdAt: DateTime(2026, 5, 1),
);

DioException _serverDioException({
  required int statusCode,
  required String code,
  String message = 'Error',
  String? subcode,
}) {
  final data = <String, dynamic>{
    'error': <String, dynamic>{
      'code': code,
      'message': message,
      if (subcode != null) 'details': <String, dynamic>{'subcode': subcode},
    },
  };
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    error: ServerException(message, statusCode: statusCode, code: code),
    response: Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: statusCode,
      data: data,
    ),
  );
}

DioException _networkDioException() => DioException(
  requestOptions: RequestOptions(path: '/test'),
  error: const NetworkException('Connection refused'),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockReviewRemoteDatasource remote;
  late ReviewRepositoryImpl repo;

  setUp(() {
    remote = MockReviewRemoteDatasource();
    repo = ReviewRepositoryImpl(remote: remote);
  });

  // ---- submitReview ----

  group('submitReview', () {
    test('returns Right(review) on success', () async {
      when(
        () => remote.submitReview(
          eventId: any(named: 'eventId'),
          ratedUserId: any(named: 'ratedUserId'),
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenAnswer((_) async => _fakeReviewModel());

      final result = await repo.submitReview(
        eventId: 'evt-1',
        ratedUserId: 'user-b',
        rating: 4,
      );

      expect(result.isRight(), isTrue);
      final review = (result as Right<Failure, Review>).value;
      expect(review.id, 'rev-1');
    });

    test('returns Left(NetworkFailure) on network error', () async {
      when(
        () => remote.submitReview(
          eventId: any(named: 'eventId'),
          ratedUserId: any(named: 'ratedUserId'),
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenThrow(_networkDioException());

      final result = await repo.submitReview(
        eventId: 'evt-1',
        ratedUserId: 'user-b',
        rating: 3,
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });

    test('returns Left(ServerFailure) on 500', () async {
      when(
        () => remote.submitReview(
          eventId: any(named: 'eventId'),
          ratedUserId: any(named: 'ratedUserId'),
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenThrow(_serverDioException(statusCode: 500, code: 'INTERNAL_ERROR'));

      final result = await repo.submitReview(
        eventId: 'evt-1',
        ratedUserId: 'user-b',
        rating: 3,
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });
  });

  // ---- editReview ----

  group('editReview', () {
    test('returns Right(null) on success (204 no content)', () async {
      when(
        () => remote.editReview(
          reviewId: any(named: 'reviewId'),
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenAnswer((_) async {});

      final result = await repo.editReview(reviewId: 'rev-1', rating: 5);

      expect(result.isRight(), isTrue);
    });

    test(
      'returns Left(EditWindowExpiredFailure) on 409 reviews.editWindowExpired',
      () async {
        when(
          () => remote.editReview(
            reviewId: any(named: 'reviewId'),
            rating: any(named: 'rating'),
            comment: any(named: 'comment'),
          ),
        ).thenThrow(
          _serverDioException(
            statusCode: 409,
            code: 'CONFLICT',
            subcode: 'reviews.editWindowExpired',
          ),
        );

        final result = await repo.editReview(reviewId: 'rev-1', rating: 5);

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), isA<EditWindowExpiredFailure>());
      },
    );

    test(
      'returns Left(EditWindowExpiredFailure) on 409 with code reviews.editWindowExpired',
      () async {
        // Alternate shape where code is on the error object directly.
        when(
          () => remote.editReview(
            reviewId: any(named: 'reviewId'),
            rating: any(named: 'rating'),
            comment: any(named: 'comment'),
          ),
        ).thenThrow(
          _serverDioException(
            statusCode: 409,
            code: 'reviews.editWindowExpired',
            message: 'Edit window expired',
          ),
        );

        final result = await repo.editReview(reviewId: 'rev-1', rating: 5);

        expect(result.isLeft(), isTrue);
        expect(result.getLeft().toNullable(), isA<EditWindowExpiredFailure>());
      },
    );

    test('returns Left(NetworkFailure) on network timeout', () async {
      when(
        () => remote.editReview(
          reviewId: any(named: 'reviewId'),
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repo.editReview(reviewId: 'rev-1', rating: 5);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });
  });

  // ---- listReviewsForUser ----

  group('listReviewsForUser', () {
    test('returns Right(page) on success', () async {
      final model = ReviewListPageModel.fromJson(<String, dynamic>{
        'rows': <Map<String, dynamic>>[
          {
            'id': 'rev-1',
            'eventId': 'evt-1',
            'raterUserId': 'user-a',
            'ratedUserId': 'user-b',
            'rating': 4,
            'comment': 'Great!',
            'hidden': false,
            'hiddenForMutualWindow': false,
            'createdAt': '2026-05-01T10:00:00.000Z',
            'updatedAt': '2026-05-01T10:00:00.000Z',
          },
        ],
        'nextCursor': null,
      });

      when(
        () => remote.listReviewsForUser(
          userId: any(named: 'userId'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => model);

      final result = await repo.listReviewsForUser(userId: 'user-b');

      expect(result.isRight(), isTrue);
      final page = (result as Right<Failure, ReviewListPage>).value;
      expect(page.rows, hasLength(1));
    });

    test('returns Left(ServerFailure) on 404', () async {
      when(
        () => remote.listReviewsForUser(
          userId: any(named: 'userId'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(_serverDioException(statusCode: 404, code: 'NOT_FOUND'));

      final result = await repo.listReviewsForUser(userId: 'user-b');

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
    });
  });

  // ---- listReviewsWrittenByMe ----

  group('listReviewsWrittenByMe', () {
    test('returns Right(page) on success', () async {
      final model = ReviewListPageModel.fromJson(<String, dynamic>{
        'rows': <Map<String, dynamic>>[],
        'nextCursor': null,
      });

      when(
        () => remote.listReviewsWrittenByMe(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => model);

      final result = await repo.listReviewsWrittenByMe();

      expect(result.isRight(), isTrue);
      final page = (result as Right<Failure, ReviewListPage>).value;
      expect(page.rows, isEmpty);
    });

    test('returns Left(AuthFailure) on 401', () async {
      when(
        () => remote.listReviewsWrittenByMe(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(_serverDioException(statusCode: 401, code: 'UNAUTHORIZED'));

      final result = await repo.listReviewsWrittenByMe();

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<AuthFailure>());
    });
  });
}
