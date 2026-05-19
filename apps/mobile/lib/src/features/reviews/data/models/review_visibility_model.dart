import '../../domain/entities/review.dart';
import '../../domain/entities/review_visibility.dart';

/// Handles the visibility discriminator in GET /users/:id/reviews responses.
///
/// The API returns a list of "review rows" where each row may be:
/// - A **blind mutual-pending** row: `hiddenForMutualWindow: true`, rating and
///   comment are null. The viewer has submitted a review but the counterparty
///   has not yet, so content is withheld.
/// - A **hidden** row: `hidden: true`. Only appears in the author's own
///   GET /me/reviews/written list; never in public profile lists.
/// - A **visible** row: full rating and comment are present.
///
/// Static factory [fromJson] maps a raw API row to the correct
/// [ReviewVisibility] subtype.
class ReviewVisibilityModel {
  const ReviewVisibilityModel._();

  static ReviewVisibility fromJson(Map<String, dynamic> json) {
    final hiddenForMutualWindow =
        (json['hiddenForMutualWindow'] as bool?) ?? false;
    final hidden = (json['hidden'] as bool?) ?? false;

    if (hiddenForMutualWindow) {
      return ReviewBlindMutualPending(
        eventId: json['eventId'] as String,
        ratedUserId: json['ratedUserId'] as String,
      );
    }

    // Build the full Review entity for both visible and hidden rows.
    // For hidden rows the rating is still present (author can see their own).
    final review = Review(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      raterUserId: json['raterUserId'] as String,
      ratedUserId: json['ratedUserId'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      hidden: hidden,
      hiddenAt: json['hiddenAt'] != null
          ? DateTime.parse(json['hiddenAt'] as String).toLocal()
          : null,
      hiddenReason: json['hiddenReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );

    if (hidden) {
      return ReviewHidden(review: review, authorViewOnly: true);
    }

    return ReviewVisible(review: review);
  }
}
