/// Verbatim copy constants for the pending-review banner.
///
/// Single source of truth — all copy rendered in [PendingReviewBanner] must
/// come from this file. Designer-approved strings per TRI-30 Brief 2D spec.
abstract final class PendingReviewBannerCopy {
  PendingReviewBannerCopy._();

  /// Headline displayed on the banner card.
  ///
  /// Substitute [name] with the counterpart's display name at render time.
  static String headline(String name) => 'Write a review for $name';

  /// Caption displayed below the headline.
  ///
  /// Substitute [eventTitle] and [formattedDate] at render time.
  /// [formattedDate] should be formatted as `DD MMM` (e.g. "14 Jun").
  static String caption(String eventTitle, String formattedDate) =>
      '$eventTitle, $formattedDate';

  /// Label for the primary action button.
  static const String buttonLabel = 'Write review';
}
