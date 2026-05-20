import 'package:equatable/equatable.dart';

import 'recent_review_comment.dart';

/// Summary of a user's reviews for display on their profile.
///
/// The server computes [averageRating] and [reviewCount] server-side after
/// applying the mutual-window and block filters. [recentVisibleComments]
/// carries the three most recent non-hidden public comments.
///
/// When [reviewCount] is 0, [averageRating] is null.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
class ProfileReviewAggregate extends Equatable {
  const ProfileReviewAggregate({
    required this.reviewCount,
    required this.recentVisibleComments,
    this.averageRating,
  });

  /// Null when [reviewCount] is 0 — no reviews yet.
  final double? averageRating;

  final int reviewCount;

  /// At most 3 items. Empty list when there are no public comments.
  final List<RecentReviewComment> recentVisibleComments;

  bool get isEmpty => reviewCount == 0;

  @override
  List<Object?> get props => [
    averageRating,
    reviewCount,
    recentVisibleComments,
  ];
}
