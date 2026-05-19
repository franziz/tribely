import 'review.dart';

/// Discriminated union describing how a review appears to the caller.
///
/// The API applies server-side projections (mutual-window, block filter) so
/// the same review record can surface in three different ways:
///
/// - [ReviewVisible]          — full content; display normally.
/// - [ReviewBlindMutualPending] — the caller has submitted a review but the
///   counterparty has not yet; content is withheld until both parties have
///   written or 14 days have elapsed.
/// - [ReviewHidden]           — Tribely moderation suppressed this review;
///   visible only to the author on their "Reviews I wrote" list.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod.
sealed class ReviewVisibility {
  const ReviewVisibility();
}

/// The review is fully visible; [review] contains all fields.
final class ReviewVisible extends ReviewVisibility {
  const ReviewVisible({required this.review});

  final Review review;
}

/// The mutual-window projection is active: the caller has submitted a review
/// but the other party has not yet, so the content is withheld.
///
/// [eventId] and [ratedUserId] are retained so the UI can display context
/// (which event, which person) without exposing the review content.
final class ReviewBlindMutualPending extends ReviewVisibility {
  const ReviewBlindMutualPending({
    required this.eventId,
    required this.ratedUserId,
  });

  final String eventId;
  final String ratedUserId;
}

/// The review was hidden by Tribely moderation. Only the author sees this
/// in their "Reviews I wrote" list; [authorViewOnly] is always true here.
final class ReviewHidden extends ReviewVisibility {
  const ReviewHidden({required this.review, this.authorViewOnly = true});

  final Review review;

  /// Invariant: always true. Retained as an explicit signal to the UI that
  /// this visibility state is author-only and must never be shown publicly.
  final bool authorViewOnly;
}
