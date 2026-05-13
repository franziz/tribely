import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request_with_requester.dart';
import '../repositories/join_request_repository.dart';

class ListPendingForEventParams extends Equatable {
  const ListPendingForEventParams({required this.eventId});

  final String eventId;

  @override
  List<Object?> get props => [eventId];
}

/// List pending join requests for an event (host view).
/// GET /events/:eventId/join-requests
class ListPendingForEventUseCase
    implements
        UseCase<List<JoinRequestWithRequester>, ListPendingForEventParams> {
  const ListPendingForEventUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, List<JoinRequestWithRequester>>> call(
    ListPendingForEventParams params,
  ) => _repository.listPendingForEvent(eventId: params.eventId);
}
