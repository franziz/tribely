import 'package:equatable/equatable.dart';

/// State machine for the hosted-event-IDs load in [MyEventsPage].
///
/// Drives the [HostingPendingCountController] family key — the page needs a
/// sorted comma-joined list of hosted event IDs to watch the pending-count
/// badge. The controller owns fetching those IDs via
/// [ListMyHostedEventsUseCase]; the page only reads the result.
///
/// State progression:
///   SignedOut (session unauthenticated — no fetch fires)
///   Loading   (session restoring or authed fetch in progress)
///   Loaded    (authed fetch succeeded)
///   Error     (authed fetch failed)
sealed class MyEventsState extends Equatable {
  const MyEventsState();
}

/// Session is unauthenticated — no fetch fires.
///
/// The controller returns this immediately when [SessionUnauthenticated] is
/// observed; the page renders the signed-out empty state.
final class MyEventsSignedOut extends MyEventsState {
  const MyEventsSignedOut();

  @override
  List<Object?> get props => const [];
}

/// Fetch is in progress (or session is restoring — silent hold).
final class MyEventsLoading extends MyEventsState {
  const MyEventsLoading();

  @override
  List<Object?> get props => const [];
}

/// Fetch succeeded. [hostedEventIds] is the current user's hosted event ID list.
final class MyEventsLoaded extends MyEventsState {
  const MyEventsLoaded({required this.hostedEventIds});

  final List<String> hostedEventIds;

  @override
  List<Object?> get props => [hostedEventIds];
}

/// Fetch failed. [message] is user-facing copy (never a raw API error string).
final class MyEventsError extends MyEventsState {
  const MyEventsError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
