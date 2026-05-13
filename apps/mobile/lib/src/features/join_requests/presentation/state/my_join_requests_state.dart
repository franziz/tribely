import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/join_request_with_event.dart';

/// State machine for the joiner's "My Requests" tab.
sealed class MyJoinRequestsState extends Equatable {
  const MyJoinRequestsState();
}

/// No fetch has been triggered yet.
final class MyJoinRequestsInitial extends MyJoinRequestsState {
  const MyJoinRequestsInitial();

  @override
  List<Object?> get props => [];
}

/// Fetch is in progress.
final class MyJoinRequestsLoading extends MyJoinRequestsState {
  const MyJoinRequestsLoading();

  @override
  List<Object?> get props => [];
}

/// Fetch succeeded. [items] is the current user's join-request list,
/// optionally filtered by eventId.
final class MyJoinRequestsLoaded extends MyJoinRequestsState {
  const MyJoinRequestsLoaded({required this.items});

  final List<JoinRequestWithEvent> items;

  @override
  List<Object?> get props => [items];
}

/// Fetch failed.
final class MyJoinRequestsError extends MyJoinRequestsState {
  const MyJoinRequestsError({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
