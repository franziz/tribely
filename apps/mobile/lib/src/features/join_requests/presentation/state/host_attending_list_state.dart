import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/join_request_with_requester.dart';

/// State machine for the host's per-event attending (approved) list.
/// Progression: Loading → (Loaded | Error).
sealed class HostAttendingListState extends Equatable {
  const HostAttendingListState();
}

/// Fetch is in progress.
final class HostAttendingListLoading extends HostAttendingListState {
  const HostAttendingListLoading();

  @override
  List<Object?> get props => [];
}

/// Fetch succeeded. [items] is the live attending list for this event.
final class HostAttendingListLoaded extends HostAttendingListState {
  const HostAttendingListLoaded({required this.items});

  final List<JoinRequestWithRequester> items;

  HostAttendingListLoaded copyWith({List<JoinRequestWithRequester>? items}) =>
      HostAttendingListLoaded(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}

/// Full fetch failed.
final class HostAttendingListError extends HostAttendingListState {
  const HostAttendingListError({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
