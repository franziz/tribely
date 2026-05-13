import 'package:equatable/equatable.dart';

import 'join_request.dart';

/// Minimal requester summary embedded in [JoinRequestWithRequester].
class JoinRequestRequesterSummary extends Equatable {
  const JoinRequestRequesterSummary({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;

  @override
  List<Object?> get props => [id, displayName];
}

/// Composite: a [JoinRequest] together with the requester's display name.
/// Used by the host's pending-list view ([ListPendingForEventUseCase]).
class JoinRequestWithRequester extends Equatable {
  const JoinRequestWithRequester({
    required this.joinRequest,
    required this.requester,
  });

  final JoinRequest joinRequest;
  final JoinRequestRequesterSummary requester;

  @override
  List<Object?> get props => [joinRequest, requester];
}
