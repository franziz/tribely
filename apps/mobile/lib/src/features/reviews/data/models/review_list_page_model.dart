import '../../domain/entities/review_list_page.dart';
import '../../domain/entities/review_visibility.dart';
import 'review_visibility_model.dart';

/// JSON model for paginated list responses from:
///   GET /users/:userId/reviews
///   GET /me/reviews/written
class ReviewListPageModel {
  const ReviewListPageModel({required this.rows, this.nextCursor});

  factory ReviewListPageModel.fromJson(Map<String, dynamic> json) {
    final rawRows = (json['rows'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return ReviewListPageModel(
      rows: rawRows.map(ReviewVisibilityModel.fromJson).toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  final List<ReviewVisibility> rows;
  final String? nextCursor;

  ReviewListPage toEntity() =>
      ReviewListPage(rows: rows, nextCursor: nextCursor);
}
