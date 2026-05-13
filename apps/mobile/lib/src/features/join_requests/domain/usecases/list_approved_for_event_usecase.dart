import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request_with_requester.dart';
import '../repositories/join_request_repository.dart';

class ListApprovedForEventParams extends Equatable {
  const ListApprovedForEventParams({required this.eventId});

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// List approved (attending) join requests for an event (host view).
/// GET /events/:eventId/join-requests?status=approved
class ListApprovedForEventUseCase
    implements
        UseCase<List<JoinRequestWithRequester>, ListApprovedForEventParams> {
  const ListApprovedForEventUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, List<JoinRequestWithRequester>>> call(
    ListApprovedForEventParams params,
  ) => _repository.listApprovedForEvent(eventId: params.eventId);
}
