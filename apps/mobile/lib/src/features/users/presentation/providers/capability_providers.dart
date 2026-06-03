import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../domain/entities/user_capabilities.dart';
import '../../domain/repositories/user_capabilities_repository.dart';
import '../state/selfie_gating_state.dart';

// ---------------------------------------------------------------------------
// Infrastructure bridge
// ---------------------------------------------------------------------------

/// Lifts [UserCapabilitiesRepository] (registered in get_it) into the Riverpod
/// graph so capability consumers can resolve it uniformly via [ref].
final _userCapabilitiesRepositoryProvider =
    Provider<UserCapabilitiesRepository>(
      (_) => sl<UserCapabilitiesRepository>(),
    );

// ---------------------------------------------------------------------------
// Capability provider
// ---------------------------------------------------------------------------

/// Fetches and caches the authenticated user's capability flags for the
/// current session.
///
/// **Failure path returns `canPostPrivateVenue: false`** — the safer default.
/// If the server is unreachable, first-time-host warnings are shown rather
/// than silently bypassed. This prevents a capability-API outage from
/// accidentally granting new users the private-venue permission.
///
/// Uses [AsyncNotifierProvider] (rather than plain [FutureProvider]) so that
/// callers can perform local cache mutations (e.g. [markSafetyReminderSeen])
/// without invalidating the provider and triggering an extra network call.
/// The consumer API (`ref.watch(myCapabilitiesProvider)`) is unchanged — it
/// still returns `AsyncValue<UserCapabilities>`.
final myCapabilitiesProvider =
    AsyncNotifierProvider<MyCapabilitiesNotifier, UserCapabilities>(
      MyCapabilitiesNotifier.new,
    );

/// Notifier backing [myCapabilitiesProvider].
class MyCapabilitiesNotifier extends AsyncNotifier<UserCapabilities> {
  @override
  Future<UserCapabilities> build() async {
    final repo = ref.watch(_userCapabilitiesRepositoryProvider);
    final result = await repo.getMyCapabilities();
    return result.fold(
      (failure) => const UserCapabilities.restricted(),
      (caps) => caps,
    );
  }

  /// Locally flips [UserCapabilities.safetyReminderSeen] to `true` in the
  /// cached state without triggering a network re-fetch (TRI-34 Brief G).
  ///
  /// No-op when the current state is not [AsyncData] (e.g. still loading
  /// or in error — the reminder will re-appear, which is the safe default).
  void markSafetyReminderSeen() {
    final current = state;
    if (current is AsyncData<UserCapabilities>) {
      final caps = current.value;
      if (caps.safetyReminderSeen) return; // already true — skip no-op write
      state = AsyncData(caps.copyWith(safetyReminderSeen: true));
    }
  }
}

// ---------------------------------------------------------------------------
// Selfie gating state provider
// ---------------------------------------------------------------------------

/// Pure derivation of the authenticated user's selfie verification gate state.
///
/// Rebuilds ONLY when one of the four selfie-related fields on [User] changes —
/// achieved by selecting a record tuple from [sessionControllerProvider] so
/// Riverpod's equality check skips rebuilds on unrelated session changes (e.g.
/// phone verification, displayName edits).
///
/// Returns [SelfieGatingNotStarted] when the user is not authenticated, as a
/// safe default (widget tree should not be visible pre-auth, but guard anyway).
///
/// Mapping rules (per AC):
///   - selfieStatus == 'notStarted'                             → [SelfieGatingNotStarted]
///   - selfieStatus == 'pending'                                → [SelfieGatingPending]
///   - selfieStatus == 'rejected' && selfieAppealLockedAt == null → [SelfieGatingFailed]
///   - selfieStatus == 'rejected' && selfieAppealLockedAt != null → [SelfieGatingLocked]
///   - selfieStatus == 'approved'                               → [SelfieGatingApproved]
final selfieGatingStateProvider = Provider<SelfieGatingState>((ref) {
  // Select only the four selfie fields — avoids rebuilds on other User changes.
  final fields = ref.watch(
    sessionControllerProvider.select((sessionState) {
      if (sessionState is! SessionAuthenticated) return null;
      final user = sessionState.session.user;
      return (
        user.selfieStatus,
        user.selfieAttemptCount,
        user.selfieLastFailureCategory,
        user.selfieAppealLockedAt,
      );
    }),
  );

  if (fields == null) return const SelfieGatingNotStarted();

  final (status, attemptCount, category, appealLockedAt) = fields;

  return switch (status) {
    'pending' => const SelfieGatingPending(),
    'rejected' when appealLockedAt != null => SelfieGatingLocked(
      category: category,
    ),
    'rejected' => SelfieGatingFailed(
      category: category,
      attemptCount: attemptCount,
    ),
    'approved' => const SelfieGatingApproved(),
    _ => const SelfieGatingNotStarted(), // covers 'notStarted' + any unknown
  };
});
