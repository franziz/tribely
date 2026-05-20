import 'package:equatable/equatable.dart';

/// The exact token the user must type to confirm account deletion.
const String _kDeleteToken = 'DELETE';

/// Failure kinds the [DeleteAccountController] can surface.
///
/// - [network] — no connectivity or request timeout.
/// - [sessionExpired] — 4xx auth failure; session was invalidated before the
///   call resolved.
/// - [server] — 5xx or any other unexpected error.
enum DeleteAccountFailureKind { network, sessionExpired, server }

/// State for [DeleteAccountController].
///
/// Sealed so callers switch exhaustively. Pattern follows [AuthFormState] in
/// the auth feature — one file per feature-controller state graph.
sealed class DeleteAccountState extends Equatable {
  const DeleteAccountState();

  /// Whether the typed-confirmation gate is satisfied. True iff
  /// the user has typed 'DELETE' exactly (case-sensitive). The
  /// CTA enable state and the mismatch hint both derive from
  /// this value.
  bool get isTokenValid;

  @override
  List<Object?> get props => [];
}

/// Waiting for user input. [token] holds the current value of the typed
/// confirmation input (may be empty, partial, or equal to 'DELETE').
class DeleteAccountIdle extends DeleteAccountState {
  const DeleteAccountIdle({this.token = ''});

  final String token;

  @override
  bool get isTokenValid => token == _kDeleteToken;

  @override
  List<Object?> get props => [token];
}

/// API call is in flight. [token] is retained so the controller can restore
/// state on failure without losing the typed value.
class DeleteAccountSubmitting extends DeleteAccountState {
  const DeleteAccountSubmitting({required this.token});

  final String token;

  @override
  bool get isTokenValid => token == _kDeleteToken;

  @override
  List<Object?> get props => [token];
}

/// API call returned a non-2xx response or a network error. [token] is
/// retained across retries (Decision #4 in design spec — token must not be
/// cleared on recoverable failures). [kind] drives the banner copy selection.
class DeleteAccountFailure extends DeleteAccountState {
  const DeleteAccountFailure({required this.token, required this.kind});

  final String token;
  final DeleteAccountFailureKind kind;

  @override
  bool get isTokenValid => token == _kDeleteToken;

  @override
  List<Object?> get props => [token, kind];
}

/// Terminal success state. Emitted after the server confirmed deletion AND
/// the best-effort [SessionController.signOut] was attempted. The page
/// consumer reacts via [ref.listen] and calls [context.go('/account-deleted')].
class DeleteAccountSuccess extends DeleteAccountState {
  const DeleteAccountSuccess();

  @override
  bool get isTokenValid => false;
}
