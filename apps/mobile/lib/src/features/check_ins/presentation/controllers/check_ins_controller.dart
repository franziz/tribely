import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/acknowledge_check_in_usecase.dart';
import '../../domain/usecases/flag_check_in_usecase.dart';
import '../providers/check_ins_providers.dart';
import '../state/check_ins_state.dart';

/// Owns the global check-in surface/acknowledge/flag state machine.
///
/// Uses [Notifier<CheckInsState>] (not AutoDisposeNotifier — not exported in
/// our Riverpod 3.x version per CLAUDE.md). Auto-dispose is configured on the
/// provider via [NotifierProvider.autoDispose] in [checkInsControllerProvider].
///
/// Lifecycle:
///   - [refresh()] is called on every app-foreground event (app_router.dart wires
///     this via AppLifecycleListener.onResumed).
///   - [acknowledged()] / [flagged()] call the API and then re-surface to pick
///     up the next pending item (or transition to Empty).
///   - [dismissShown()] is a client-only dismiss — the record stays `pending`
///     server-side; the user chose to act later.
class CheckInsController extends Notifier<CheckInsState> {
  @override
  CheckInsState build() => const CheckInsIdle();

  /// Surfaces the next pending check-in. Transitions:
  ///   * → Loading → Showing(first item)
  ///   * → Loading → Empty
  ///   * → Loading → Error(failure)
  Future<void> refresh() async {
    state = const CheckInsLoading();

    final useCase = ref.read(surfacePendingCheckInsUseCaseProvider);
    final result = await useCase(const NoParams());

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => CheckInsError(failure: failure),
      (items) => items.isNotEmpty
          ? CheckInsShowing(item: items.first)
          : const CheckInsEmpty(),
    );
  }

  /// Acknowledge the currently-shown check-in. No-op if state is not [CheckInsShowing].
  ///
  /// Transitions: Showing → Loading (in-flight) → Showing(next) | Empty | Error.
  Future<void> acknowledged() async {
    final current = state;
    if (current is! CheckInsShowing) return;

    final checkInId = current.item.id;
    state = const CheckInsLoading();

    final useCase = ref.read(acknowledgeCheckInUseCaseProvider);
    final params = AcknowledgeCheckInParams(checkInId: checkInId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    await result.fold(
      (failure) async {
        state = CheckInsError(failure: failure);
      },
      (_) async {
        // Surface the next pending item (or Empty) after successful acknowledgement.
        await refresh();
      },
    );
  }

  /// Flag the currently-shown check-in with a report. No-op if not [CheckInsShowing].
  ///
  /// Transitions: Showing → Loading (in-flight) → Showing(next) | Empty | Error.
  Future<void> flagged(String reportBody) async {
    final current = state;
    if (current is! CheckInsShowing) return;

    final checkInId = current.item.id;
    state = const CheckInsLoading();

    final useCase = ref.read(flagCheckInUseCaseProvider);
    final params = FlagCheckInParams(
      checkInId: checkInId,
      reportBody: reportBody,
    );
    final result = await useCase(params);

    if (!ref.mounted) return;
    await result.fold(
      (failure) async {
        state = CheckInsError(failure: failure);
      },
      (_) async {
        // Surface the next pending item (or Empty) after successful flag.
        await refresh();
      },
    );
  }

  /// Dismiss the currently-shown check-in without acting on it.
  ///
  /// This is a client-only transition — the server record stays `pending`.
  /// The user will be prompted again on the next foreground resume.
  /// Transitions: Showing → Idle.
  void dismissShown() {
    if (state is! CheckInsShowing) return;
    state = const CheckInsIdle();
  }
}
