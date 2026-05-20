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
      DeleteAccountSuccess() => state, // suppress edits after success
      DeleteAccountFailure() => DeleteAccountIdle(token: value),
      _ => DeleteAccountIdle(token: value),
    };
  }

  /// Submits the deletion request.
  ///
  /// No-op if [state.isTokenValid] is false (guards against programmatic calls
  /// when the CTA should be disabled). Wraps the API call, handles failure
  /// classification, and on success attempts a best-effort sign-out before
  /// emitting [DeleteAccountSuccess].
  Future<void> submit() async {
    if (!state.isTokenValid) return;

    final token = switch (state) {
      DeleteAccountIdle(:final token) => token,
      DeleteAccountSubmitting(:final token) => token,
      DeleteAccountFailure(:final token) => token,
      DeleteAccountSuccess() => '',
    };
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
    // Account-deletion success → terminal-screen navigation depends on three
    // coupled invariants. Drift in any one will silently bounce the user away
    // from /account-deleted (AC4/AC5 break).
    //
    //   1. /account-deleted is in `publicRoutes` in app_router.dart, so the
    //      SessionUnauthenticated branch of the redirect returns null
    //      (allow-through) for that location.
    //   2. SessionController.signOut() does NOT throw. The auth repository
    //      (AuthRepositoryImpl.signOut) catches DioException + generic
    //      exceptions, always clears local token storage, and returns
    //      Either<Failure, void>. SessionController awaits the use case,
    //      ignores the Either, and unconditionally transitions state to
    //      SessionUnauthenticated. We rely on that contract here: by the time
    //      this await returns, the session has already become
    //      SessionUnauthenticated, so the page's subsequent
    //      context.go('/account-deleted') passes the redirect via invariant 1.
    //   3. The SessionAuthenticated branch of the redirect bounces public
    //      routes to /events (app_router.dart — `if (isSplash || isAuthFlow
    //      || isVerify) return '/events';`). This is correct in isolation
    //      (verified users shouldn't accidentally land on the terminal
    //      screen), but it ALSO means invariant 2 is load-bearing: if signOut
    //      ever throws or fails to transition state, the navigation lands
    //      while still authenticated → bounce to /events → terminal screen
    //      never rendered.
    //
    // No try/catch here on purpose. A catch would defend against an exception
    // the auth contract forbids and would hide a real bug if SessionController
    // .signOut() is ever refactored to surface failures. If that refactor
    // happens, this method MUST be revisited.
    await ref.read(sessionControllerProvider.notifier).signOut();
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
