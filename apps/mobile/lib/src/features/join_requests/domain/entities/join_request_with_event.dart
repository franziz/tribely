import 'package:equatable/equatable.dart';

import 'join_request.dart';

/// Minimal event summary embedded in [JoinRequestWithEvent].
/// Carries only the fields the joiner's "My Requests" list needs.
class JoinRequestEventSummary extends Equatable {
  const JoinRequestEventSummary({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.venueAddress,
    required this.venueCity,
    required this.status,
    required this.capacity,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String venueAddress;
  final String venueCity;

  /// Wire value: 'draft' | 'published' | 'cancelled' | 'completed'.
  final String status;
  final int capacity;

  @override
  List<Object?> get props => [
    id,
    title,
    startsAt,
    endsAt,
    venueAddress,
    venueCity,
    status,
    capacity,
  ];
}

/// Composite: a [JoinRequest] together with an embedded [JoinRequestEventSummary].
/// Used by the joiner's "My Requests" list ([ListMyJoinRequestsUseCase]).
class JoinRequestWithEvent extends Equatable {
  const JoinRequestWithEvent({required this.joinRequest, required this.event});

  final JoinRequest joinRequest;
  final JoinRequestEventSummary event;

  @override
  List<Object?> get props => [joinRequest, event];
}
