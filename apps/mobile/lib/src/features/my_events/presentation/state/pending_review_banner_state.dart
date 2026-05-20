import 'package:equatable/equatable.dart';

import '../../../reviews/domain/entities/pending_review_prompt.dart';

/// State for [PendingReviewBannerController].
///
/// Sealed class — all subclasses must be handled in switch exhaustiveness.
sealed class PendingReviewBannerState extends Equatable {
  const PendingReviewBannerState();
}

/// Initial load in flight.
final class PendingReviewBannerLoading extends PendingReviewBannerState {
  const PendingReviewBannerLoading();

  @override
  List<Object?> get props => const [];
}

/// Server returned a prompt — banner should be visible.
final class PendingReviewBannerVisible extends PendingReviewBannerState {
  const PendingReviewBannerVisible({required this.prompt});

  final PendingReviewPrompt prompt;

  @override
  List<Object?> get props => [prompt];
}

/// User dismissed the banner this session, or the composer was navigated to.
/// Session-only — no persistence across app restarts.
final class PendingReviewBannerDismissed extends PendingReviewBannerState {
  const PendingReviewBannerDismissed();

  @override
  List<Object?> get props => const [];
}

/// Server returned null prompt — nothing to show.
final class PendingReviewBannerNone extends PendingReviewBannerState {
  const PendingReviewBannerNone();

  @override
  List<Object?> get props => const [];
}
