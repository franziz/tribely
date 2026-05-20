import '../../../reviews/domain/entities/pending_review_prompt.dart';

/// State for [PendingReviewBannerController].
///
/// Sealed class — all subclasses must be handled in switch exhaustiveness.
sealed class PendingReviewBannerState {
  const PendingReviewBannerState();
}

/// Initial load in flight.
final class PendingReviewBannerLoading extends PendingReviewBannerState {
  const PendingReviewBannerLoading();
}

/// Server returned a prompt — banner should be visible.
final class PendingReviewBannerVisible extends PendingReviewBannerState {
  const PendingReviewBannerVisible({required this.prompt});

  final PendingReviewPrompt prompt;
}

/// User dismissed the banner this session, or the composer was navigated to.
/// Session-only — no persistence across app restarts.
final class PendingReviewBannerDismissed extends PendingReviewBannerState {
  const PendingReviewBannerDismissed();
}

/// Server returned null prompt — nothing to show.
final class PendingReviewBannerNone extends PendingReviewBannerState {
  const PendingReviewBannerNone();
}
