import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/account_providers.dart';
import '../state/delete_account_state.dart';

/// Owns the typed-confirmation gate and deletion submission flow for the
/// [DeleteAccountPage].
///
/// Convention: `Notifier<T>` + `NotifierProvider.autoDispose` per CLAUDE.md
/// (do NOT use `AutoDisposeNotifier<T>` — not exported in this Riverpod version).
class DeleteAccountController extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountIdle();

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// The token string held by the current state, regardless of which variant
  /// the state is in.
  String get _currentToken => switch (state) {
    DeleteAccountIdle(:final token) => token,
    DeleteAccountSubmitting(:final token) => token,
    DeleteAccountFailure(:final token) => token,
    DeleteAccountSuccess() => '',
  };

  /// Returns true iff the typed token exactly matches 'DELETE' (case-sensitive).
  bool get isTokenValid => _currentToken == 'DELETE';

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Called on every keystroke in the confirmation input.
  ///
  /// Preserves any in-progress state on edits. If the state is
  /// [DeleteAccountFailure], editing transitions back to [DeleteAccountIdle]
  /// to clear the error banner — the user is actively correcting the situation.
  void updateToken(String value) {
    state = switch (state) {
      DeleteAccountSubmitting() => state, // suppress edits during API call
      DeleteAccountSuccess() => state,    // suppress edits after success
      DeleteAccountFailure() => DeleteAccountIdle(token: value),
      _ => DeleteAccountIdle(token: value),
    };
  }

  /// Submits the deletion request.
  ///
  /// No-op if [isTokenValid] is false (guards against programmatic calls
  /// when the CTA should be disabled). Wraps the API call, handles failure
  /// classification, and on success attempts a best-effort sign-out before
  /// emitting [DeleteAccountSuccess].
  Future<void> submit() async {
    if (!isTokenValid) return;

    final token = _currentToken;
    state = DeleteAccountSubmitting(token: token);

    final result = await ref
        .read(deleteAccountUseCaseProvider)
        .call(const NoParams());

    if (!ref.mounted) return;

    // Use fold to allow awaiting the async success path. match() doesn't allow
    // awaiting the right callback's Future cleanly — fold with explicit await
    // avoids the unawaited_futures lint.
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      state = DeleteAccountFailure(token: token, kind: _classify(failure));
    } else {
      await _onSuccess(token);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _onSuccess(String token) async {
    // Best-effort sign-out: the server already deleted the account and cascaded
    // the credentials. If signOut fails (e.g. network unavailable), the session
    // will be invalidated on the next refresh anyway — we still proceed to the
    // terminal screen.
    try {
      await ref.read(sessionControllerProvider.notifier).signOut();
    } catch (_) {
      // Intentionally swallowed — server delete already succeeded; clearance
      // is best-effort only.
    }
    if (!ref.mounted) return;
    state = const DeleteAccountSuccess();
  }

  /// Maps a [Failure] to the appropriate [DeleteAccountFailureKind].
  ///
  /// - [AuthFailure] → sessionExpired (user will need to sign in again)
  /// - [NetworkFailure] → network (connectivity / timeout)
  /// - everything else → server (5xx or unexpected)
  DeleteAccountFailureKind _classify(Failure failure) => switch (failure) {
    AuthFailure() => DeleteAccountFailureKind.sessionExpired,
    NetworkFailure() => DeleteAccountFailureKind.network,
    _ => DeleteAccountFailureKind.server,
  };
}
