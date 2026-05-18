import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// SessionController — owns the global authenticated/unauthenticated state.
///
/// Self-initializing: when first read, [build] returns `SessionRestoring`
/// and kicks off a silent `/auth/refresh` from the stored refresh token.
/// This follows Riverpod 3's "providers manage their own initialization"
/// rule — widgets must NOT call `restore()` from `initState`.
///
/// Outcomes of the silent refresh:
///   - success → SessionAuthenticated(session)
///   - no stored refresh token → SessionUnauthenticated() (silent — first-run)
///   - refresh rejected (401) → SessionUnauthenticated(reason: 'Please sign in again.')
///   - network unreachable → SessionUnauthenticated(reason: gentle network copy)
///   - exceeded the timeout → SessionUnauthenticated with the network copy
///
/// The splash UI is also held for a minimum window (`_minSplashHold`) so the
/// brand moment doesn't flash by on a fast network.
class SessionController extends Notifier<SessionState> {
  /// Minimum time the splash stays visible before we transition. Even if the
  /// silent refresh resolves in 50ms, the user gets a calm brand presence.
  static const _minSplashHold = Duration(seconds: 1);

  /// Hard cap on the silent refresh — the splash must never hang forever.
  /// On unreachable networks the OS-level TCP timeout can be 30–75s even when
  /// Dio's connectTimeout is set to 10s. We cut it short and route to /welcome.
  static const _restoreTimeout = Duration(seconds: 5);

  @override
  SessionState build() {
    // Kick off async initialization. Scheduled via Future(...) so the actual
    // state mutation lands AFTER the synchronous build phase completes —
    // satisfying Riverpod 3's "no provider mutation during build" rule.
    Future<void>(_runInitialRestore);
    return const SessionRestoring();
  }

  Future<void> _runInitialRestore() async {
    final restoreWork = _attemptRefresh();
    final minHold = Future<void>.delayed(_minSplashHold);
    final results = await Future.wait<dynamic>([restoreWork, minHold]);
    if (!ref.mounted) return;
    state = results.first as SessionState;
  }

  Future<SessionState> _attemptRefresh() async {
    final useCase = ref.read(refreshSessionUseCaseProvider);
    try {
      final result = await useCase(const NoParams()).timeout(_restoreTimeout);
      return result.match(
        (failure) => _unauthenticatedFor(failure),
        (session) => SessionAuthenticated(session),
      );
    } on TimeoutException {
      return const SessionUnauthenticated(
        reason:
            "We couldn't check your session. You can sign in once you're online.",
      );
    }
  }

  /// Called by SignInController / SignUpController on successful auth.
  /// Always resets [phoneRevokedSinceLastSeen] to false — a fresh sign-in
  /// represents a clean session.
  void setAuthenticated(AuthSession session) {
    state = SessionAuthenticated(session);
  }

  /// Replace the user inside the current session — e.g. after email/phone
  /// verification flips `*VerifiedAt` from null to a timestamp, or after
  /// a GET /me refresh. No-op if not currently authenticated.
  ///
  /// Detects the `phoneVerifiedAt: !null → null` transition and sets
  /// [SessionAuthenticated.phoneRevokedSinceLastSeen] = true so the UI can
  /// surface a neutral "contested phone" banner. The flag is purely transient
  /// (not persisted) and resets to false on cold-start.
  void setUser(User user) {
    final current = state;
    if (current is! SessionAuthenticated) return;

    final previousPhoneVerifiedAt = current.session.user.phoneVerifiedAt;
    final phoneRevoked =
        previousPhoneVerifiedAt != null && user.phoneVerifiedAt == null;

    state = SessionAuthenticated(
      current.session.copyWith(user: user),
      phoneRevokedSinceLastSeen:
          current.phoneRevokedSinceLastSeen || phoneRevoked,
    );
  }

  /// Dismisses the contested-phone neutral banner. Resets
  /// [SessionAuthenticated.phoneRevokedSinceLastSeen] to false.
  void dismissPhoneRevokedBanner() {
    final current = state;
    if (current is SessionAuthenticated && current.phoneRevokedSinceLastSeen) {
      state = SessionAuthenticated(current.session);
    }
  }

  Future<void> signOut() async {
    final useCase = ref.read(signOutUseCaseProvider);
    await useCase(const NoParams());
    if (!ref.mounted) return;
    state = const SessionUnauthenticated();
    // Reset form controllers so a returning user sees a clean form on the
    // next visit — without this, the SignInController state stays at
    // `AuthFormSuccess` from the previous session and the button still
    // reads "You're in." when the user returns to /sign-in.
    ref.invalidate(signInControllerProvider);
    ref.invalidate(signUpControllerProvider);
  }

  /// Clear the banner copy on the welcome page (after the user dismisses it).
  void dismissReason() {
    final current = state;
    if (current is SessionUnauthenticated && current.reason != null) {
      state = const SessionUnauthenticated();
    }
  }

  SessionUnauthenticated _unauthenticatedFor(Failure failure) {
    return switch (failure) {
      NetworkFailure() => const SessionUnauthenticated(
        reason:
            "We couldn't check your session. You can sign in once you're online.",
      ),
      AuthFailure(:final message) when message == 'No stored refresh token' =>
        const SessionUnauthenticated(),
      AuthFailure() => const SessionUnauthenticated(
        reason: 'Please sign in again.',
      ),
      _ => const SessionUnauthenticated(reason: 'Please sign in again.'),
    };
  }
}
