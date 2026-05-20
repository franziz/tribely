import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/lifecycle/app_lifecycle_provider.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../reviews/presentation/providers/review_providers.dart';
import '../state/pending_review_banner_state.dart';

/// Provider — autoDispose so session state is discarded when the
/// [MyEventsPage] leaves the widget tree.
final pendingReviewBannerControllerProvider =
    NotifierProvider.autoDispose<
      PendingReviewBannerController,
      PendingReviewBannerState
    >(PendingReviewBannerController.new);

/// Manages the foreground review-prompt banner shown at the top of My Events.
///
/// Responsibilities:
///   - Fetch `GET /me/pending-review-prompts` on mount and on app-foreground resume.
///   - Expose [dismiss] and [onComposerNavigated] to flip to [PendingReviewBannerDismissed].
///   - Once dismissed this session, skip all subsequent fetches.
///
/// Session-only dismissal — no server write, no local storage. The banner
/// reappears the next time [MyEventsPage] mounts (i.e. the next session).
class PendingReviewBannerController extends Notifier<PendingReviewBannerState> {
  @override
  PendingReviewBannerState build() {
    // Subscribe to app lifecycle events and re-fetch on resume.
    // The listen call is cancelled automatically when this provider disposes.
    ref.listen(appLifecycleProvider, (_, next) {
      next.whenData((lifecycle) {
        if (lifecycle == AppLifecycleState.resumed) {
          _fetchIfEligible();
        }
      });
    });

    // Initial fetch — scheduled as microtask so build() returns synchronously.
    Future(() => _fetchIfEligible());

    return const PendingReviewBannerLoading();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Session-dismiss: hides the banner for the remainder of this session.
  /// Called when the user taps the × button.
  void dismiss() {
    state = const PendingReviewBannerDismissed();
  }

  /// Called when the user taps the card body to navigate to the composer.
  /// Optimistically dismisses — the next session will re-check eligibility.
  void onComposerNavigated() {
    state = const PendingReviewBannerDismissed();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Fetches the pending prompt unless already dismissed this session.
  Future<void> _fetchIfEligible() async {
    // Once dismissed, skip all subsequent fetches this session.
    if (state is PendingReviewBannerDismissed) return;

    if (!ref.mounted) return;
    state = const PendingReviewBannerLoading();

    final useCase = ref.read(getPendingReviewPromptUseCaseProvider);
    final result = await useCase(const NoParams());

    if (!ref.mounted) return;

    result.fold(
      // On failure, fall back to None so the page body isn't blocked.
      (_) => state = const PendingReviewBannerNone(),
      (prompt) => state = prompt != null
          ? PendingReviewBannerVisible(prompt: prompt)
          : const PendingReviewBannerNone(),
    );
  }
}
