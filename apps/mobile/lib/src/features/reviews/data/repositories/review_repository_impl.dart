import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/pending_review_prompt.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_list_page.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_datasource.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl({required ReviewRemoteDatasource remote})
    : _remote = remote;

  final ReviewRemoteDatasource _remote;

  @override
  Future<Either<Failure, Review>> submitReview({
    required String eventId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) async {
    try {
      final model = await _remote.submitReview(
        eventId: eventId,
        ratedUserId: ratedUserId,
        rating: rating,
        comment: comment,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> editReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _remote.editReview(
        reviewId: reviewId,
        rating: rating,
        comment: comment,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReviewListPage>> listReviewsForUser({
    required String userId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final model = await _remote.listReviewsForUser(
        userId: userId,
        cursor: cursor,
        limit: limit,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReviewListPage>> listReviewsWrittenByMe({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final model = await _remote.listReviewsWrittenByMe(
        cursor: cursor,
        limit: limit,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PendingReviewPrompt?>> getPendingReviewPrompt() async {
    try {
      final model = await _remote.getPendingReviewPrompt();
      return Right(model?.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Dio → Failure mapping
  //
  // The _ErrorInterceptor in ApiClient wraps the response in ServerException
  // carrying the top-level error.code. The subcode lives in
  // error.details.subcode on the wire; we read it from e.response?.data.
  // ---------------------------------------------------------------------------

  Failure _mapDioError(DioException e) {
    final inner = e.error;

    if (inner is NetworkException) {
      return NetworkFailure(inner.message);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Request timed out');
    }

    if (inner is ServerException) {
      final statusCode = inner.statusCode;
      final code = inner.code;
      final message = inner.message;

      switch (statusCode) {
        case 401:
          return AuthFailure(message, code: code);

        case 403:
          if (code == 'EMAIL_NOT_VERIFIED') {
            return EmailNotVerifiedFailure(message, code: code);
          }
          return ServerFailure(message, statusCode: 403, code: code);

        case 404:
          return NotFoundFailure(message, code: code);

        case 409:
          // reviews.editWindowExpired — the 24h edit window has elapsed.
          final subcode = _extractSubcode(e);
          if (subcode == 'reviews.editWindowExpired' ||
              code == 'reviews.editWindowExpired') {
            return EditWindowExpiredFailure(message, code: code);
          }
          return ServerFailure(message, statusCode: 409, code: code);

        case 422:
          return ValidationFailure(message, code: code);

        default:
          return ServerFailure(message, statusCode: statusCode, code: code);
      }
    }

    return UnknownFailure(e.message ?? 'Unknown error');
  }

  /// Extracts `error.details.subcode` from the raw Dio response body.
  String _extractSubcode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          final details = error['details'];
          if (details is Map<String, dynamic>) {
            return (details['subcode'] as String?) ?? '';
          }
          // Some error shapes carry the code directly on the error object.
          return (error['code'] as String?) ?? '';
        }
      }
    } catch (_) {
      // Defensive: malformed response — fall through to empty string.
    }
    return '';
  }
}
