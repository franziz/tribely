import 'package:dio/dio.dart';

import '../models/review_list_page_model.dart';
import '../models/review_model.dart';

/// Driving-adapter interface for the reviews remote API.
///
/// Throws [DioException] on network or server errors — does NOT return Either.
/// The repository ([ReviewRepositoryImpl]) maps DioExceptions to domain
/// [Failure] types, following the pattern established by other feature datasources.
abstract class ReviewRemoteDatasource {
  /// POST /events/:eventId/reviews
  Future<ReviewModel> submitReview({
    required String eventId,
    required String ratedUserId,
    required int rating,
    String? comment,
  });

  /// PATCH /reviews/:reviewId — returns 204 No Content on success.
  Future<void> editReview({
    required String reviewId,
    required int rating,
    String? comment,
  });

  /// GET /users/:userId/reviews?cursor=&limit=
  Future<ReviewListPageModel> listReviewsForUser({
    required String userId,
    String? cursor,
    int limit = 20,
  });

  /// GET /me/reviews/written?cursor=&limit=
  Future<ReviewListPageModel> listReviewsWrittenByMe({
    String? cursor,
    int limit = 20,
  });
}

class ReviewRemoteDatasourceImpl implements ReviewRemoteDatasource {
  ReviewRemoteDatasourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ReviewModel> submitReview({
    required String eventId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'ratedUserId': ratedUserId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/$eventId/reviews',
      data: body,
    );
    return ReviewModel.fromJson(
      response.data!['review'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> editReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'rating': rating,
      if (comment != null) 'comment': comment,
    };
    await _dio.patch<void>('/reviews/$reviewId', data: body);
  }

  @override
  Future<ReviewListPageModel> listReviewsForUser({
    required String userId,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/reviews',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return ReviewListPageModel.fromJson(response.data!);
  }

  @override
  Future<ReviewListPageModel> listReviewsWrittenByMe({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/reviews/written',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return ReviewListPageModel.fromJson(response.data!);
  }
}
