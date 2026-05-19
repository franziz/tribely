import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../domain/value_objects/selfie_failure_category.dart';
import '../state/selfie_gating_state.dart';
import 'capability_providers.dart';

// ---------------------------------------------------------------------------
// Internal "shown for" tracker
// ---------------------------------------------------------------------------

/// Tracks which (userId, attemptCount) key pairs have already had the
/// rejection sheet auto-shown in this app session.
///
/// Intentionally NOT persisted — once per session per transition is sufficient.
/// A cold restart resets the set, but by then the state is stable and the
/// guard will not re-fire on first read.
class _ShownForNotifier extends Notifier<Set<(String, int)>> {
  @override
  Set<(String, int)> build() => const <(String, int)>{};

  void markShown(String userId, int sentinelAttemptCount) {
    state = <(String, int)>{...state, (userId, sentinelAttemptCount)};
  }
}

final _shownForProvider =
    NotifierProvider<_ShownForNotifier, Set<(String, int)>>(
      _ShownForNotifier.new,
    );

// ---------------------------------------------------------------------------
// Public trigger provider
// ---------------------------------------------------------------------------

/// One-shot listener that auto-presents [VerificationRejectedSheet] when
/// [selfieGatingStateProvider] transitions from [SelfieGatingPending] to
/// [SelfieGatingFailed] or [SelfieGatingLocked].
///
/// The sheet must be presented from the ROOT navigator — callers listen to
/// this provider inside a widget that is above the
/// [StatefulShellRoute.indexedStack] shell so the modal survives tab switches
/// (per CLAUDE.md root-navigator gotcha).
///
/// Returns a [SelfieRejectionTrigger] when a new one-shot presentation is
/// needed, or `null` when no action is required.
///
/// Usage:
/// ```dart
/// final trigger = ref.watch(selfieRejectionListenerProvider);
/// if (trigger != null) {
///   trigger.markShown();
///   showModalBottomSheet(...); // VerificationRejectedSheet
/// }
/// ```
final selfieRejectionListenerProvider =
    Provider.autoDispose<SelfieRejectionTrigger?>((ref) {
      final gatingState = ref.watch(selfieGatingStateProvider);
      final shownFor = ref.watch(_shownForProvider);

      final session = ref.watch(sessionControllerProvider);
      final userId = switch (session) {
        SessionAuthenticated(:final session) => session.user.id,
        _ => null,
      };

      if (userId == null) return null;

      switch (gatingState) {
        case SelfieGatingFailed(:final attemptCount, :final category):
          final key = (userId, attemptCount);
          if (shownFor.contains(key)) return null;
          return SelfieRejectionTrigger(
            category: category,
            attemptCount: attemptCount,
            isLocked: false,
            markShown: () {
              ref
                  .read(_shownForProvider.notifier)
                  .markShown(userId, attemptCount);
            },
          );

        case SelfieGatingLocked(:final category):
          // Locked = attempt 3. Use sentinel attemptCount -1 to key the locked
          // transition distinctly from a failed-at-3 state.
          const lockedSentinel = -1;
          final key = (userId, lockedSentinel);
          if (shownFor.contains(key)) return null;
          return SelfieRejectionTrigger(
            category: category,
            attemptCount: 3,
            isLocked: true,
            markShown: () {
              ref
                  .read(_shownForProvider.notifier)
                  .markShown(userId, lockedSentinel);
            },
          );

        default:
          return null;
      }
    });

// ---------------------------------------------------------------------------
// Trigger value type
// ---------------------------------------------------------------------------

/// Data class returned by [selfieRejectionListenerProvider] when a new
/// one-shot rejection sheet presentation is required.
///
/// [markShown] MUST be called after presenting the sheet to prevent
/// re-presentation on subsequent rebuilds.
class SelfieRejectionTrigger {
  const SelfieRejectionTrigger({
    required this.category,
    required this.attemptCount,
    required this.isLocked,
    required this.markShown,
  });

  final SelfieFailureCategory? category;
  final int attemptCount;

  /// True when the user is in the locked state (appeal lock active).
  final bool isLocked;

  /// Call after [showModalBottomSheet] is invoked — prevents re-presentation
  /// on subsequent rebuilds.
  final VoidCallback markShown;
}
