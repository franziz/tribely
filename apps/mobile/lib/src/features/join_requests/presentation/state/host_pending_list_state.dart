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
final class HostPendingListLoaded extends HostPendingListState {
  const HostPendingListLoaded({required this.items});

  final List<JoinRequestWithRequester> items;

  @override
  List<Object?> get props => [items];
}

/// Fetch (or a subsequent approve/decline action) failed.
final class HostPendingListError extends HostPendingListState {
  const HostPendingListError({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
