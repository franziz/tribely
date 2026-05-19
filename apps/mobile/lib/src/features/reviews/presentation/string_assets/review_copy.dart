/// Verbatim copy SoT for the reviews feature.
///
/// ALL user-facing strings in the reviews UI must reference this file.
/// Do NOT paraphrase — these strings were approved by the designer and must
/// remain byte-for-byte accurate through all refactors.
///
/// Sourcing: Brief 2A designer spec.
class ReviewCopy {
  const ReviewCopy._();

  // ---- Composer ----

  /// Guidance notice shown above the comment field in the review composer.
  static const String composerNotice =
      'Be respectful and specific. Share what happened — not personal attacks '
      'or private information. Reviews are public on the other person\'s profile '
      'and can be reported.';

  /// Privacy/policy link shown below the submit button.
  static const String composerPrivacyLink =
      "By submitting you agree to Tribely's Review Content Policy.";

  // ---- Mutual-window blind state ----

  /// Shown on a My Events review-prompt card when the user has submitted
  /// but the counterparty has not yet.
  static const String mutualWindowPending =
      'Your review is in. You\'ll see their review of you once they\'ve '
      'submitted theirs, or after 14 days — whichever comes first.';

  // ---- Edit window expiry ----

  /// Banner rendered on the user's own submitted review when past the 24h window.
  static const String editWindowExpired =
      'This review is locked. You can no longer edit it.';

  // ---- Hidden review author notice ----

  /// Rendered in the author's outbound review list when hidden=true.
  static const String hiddenReviewAuthorNotice =
      'This review was hidden by Tribely for breaching our Community Standards. '
      'It is no longer visible on the other person\'s profile. Contact '
      'support@gotribely.com if you\'d like to appeal.';

  // ---- Star rating labels ----

  /// Maps a whole-star rating (1–5) to its display label.
  static String ratingLabel(int rating) => switch (rating) {
    1 => 'Not great',
    2 => 'Could be better',
    3 => 'It was okay',
    4 => 'Really good',
    5 => 'Excellent',
    _ => '',
  };

  // ---- Empty / generic states ----

  static const String noReviewsYet = 'No reviews yet';
  static const String reviewsPending = 'Reviews pending';
  static const String seeAll = 'See all';
}
