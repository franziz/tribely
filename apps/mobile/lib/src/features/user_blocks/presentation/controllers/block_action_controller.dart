import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/block_user_usecase.dart';
import '../providers/user_block_providers.dart';
import '../state/block_action_state.dart';

/// Owns the state for the one-shot block action (block confirm sheet).
///
/// Disposes when the confirm sheet is dismissed (autoDispose on the provider).
///
/// Responsibilities:
///   - [block]: POST /me/blocks — Idle → Blocking → Success | Failure
///   - [reset]: returns to Idle after the caller acknowledges an error
class BlockActionController extends Notifier<BlockActionState> {
  @override
  BlockActionState build() => const BlockActionIdle();

  /// Block [userId].
  ///
  /// Guards against double-submit by checking [BlockActionBlocking].
  Future<void> block(String userId) async {
    if (state is BlockActionBlocking) return;
    state = const BlockActionBlocking();

    final useCase = ref.read(blockUserUseCaseProvider);
    final params = BlockUserParams(blockedUserId: userId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => BlockActionFailure(message: _messageFor(failure)),
      (_) => const BlockActionSuccess(),
    );
  }

  /// Returns to [BlockActionIdle].
  void reset() {
    state = const BlockActionIdle();
  }
}

// ---------------------------------------------------------------------------
// Failure → user-visible message
// ---------------------------------------------------------------------------

String _messageFor(Failure failure) {
  return switch (failure) {
    SelfBlockFailure() => "You can't block yourself.",
    AuthFailure() => 'Please sign in to block users.',
    EmailNotVerifiedFailure() =>
      'Please verify your email before blocking users.',
    NetworkFailure() => "Couldn't reach Tribely. Check your connection.",
    _ => 'Something went wrong. Please try again.',
  };
}
