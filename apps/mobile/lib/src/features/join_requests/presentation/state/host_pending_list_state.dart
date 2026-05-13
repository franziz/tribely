import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/join_request_with_requester.dart';

/// State machine for the host's per-event pending-requests list.
sealed class HostPendingListState extends Equatable {
  const HostPendingListState();
}

/// No fetch has been triggered yet.
final class HostPendingListInitial extends HostPendingListState {
  const HostPendingListInitial();

  @override
  List<Object?> get props => [];
}

/// Fetch is in progress.
final class HostPendingListLoading extends HostPendingListState {
  const HostPendingListLoading();

  @override
  List<Object?> get props => [];
}

/// Fetch succeeded. [items] is the live pending list for this event.
///
/// [sectionError] is an inline error shown at the top of the pending-requests
/// section — used for per-action failures (network error, 409 capacity-full)
/// while keeping the list rows intact. Null = no section banner.
///
/// [raceConflictId] is set transiently when a 409 ALREADY_APPROVED /
/// ALREADY_REJECTED response is received — indicates the request was handled
/// by another actor. The UI observes this via `ref.listen`, shows a toast,
/// then calls [HostPendingListController.clearRaceConflict] to null it out.
///
/// [actionInFlightId] is the ID of the row currently being acted on; both
/// buttons in that row are disabled while it is set.
final class HostPendingListLoaded extends HostPendingListState {
  const HostPendingListLoaded({
    required this.items,
    this.sectionError,
    this.actionInFlightId,
    this.raceConflictId,
  });

  final List<JoinRequestWithRequester> items;

  /// Inline section-level error message. Non-null when an approve/decline
  /// action failed with a surfaceable error (network, capacity-full). The UI
  /// renders a [BannerMessage] at the top of the section.
  final String? sectionError;

  /// ID of the join-request row currently undergoing an approve or decline
  /// action. Used to disable that row's buttons during the in-flight request.
  final String? actionInFlightId;

  /// Transient signal: the join-request ID that caused a race-condition 409.
  /// The UI reads this via `ref.listen` to show a toast, then clears it.
  final String? raceConflictId;

  @override
  List<Object?> get props => [
    items,
    sectionError,
    actionInFlightId,
    raceConflictId,
  ];

  HostPendingListLoaded copyWith({
    List<JoinRequestWithRequester>? items,
    Object? sectionError = _sentinel,
    Object? actionInFlightId = _sentinel,
    Object? raceConflictId = _sentinel,
  }) {
    return HostPendingListLoaded(
      items: items ?? this.items,
      sectionError: sectionError == _sentinel
          ? this.sectionError
          : sectionError as String?,
      actionInFlightId: actionInFlightId == _sentinel
          ? this.actionInFlightId
          : actionInFlightId as String?,
      raceConflictId: raceConflictId == _sentinel
          ? this.raceConflictId
          : raceConflictId as String?,
    );
  }
}

/// Full fetch failed. Distinct from the inline section error used for actions.
final class HostPendingListError extends HostPendingListState {
  const HostPendingListError({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

// Sentinel for copyWith nullable-field overrides.
const Object _sentinel = Object();
