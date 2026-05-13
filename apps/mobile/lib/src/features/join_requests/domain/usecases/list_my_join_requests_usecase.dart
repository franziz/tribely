import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request_with_event.dart';
import '../repositories/join_request_repository.dart';

class ListMyJoinRequestsParams extends Equatable {
  const ListMyJoinRequestsParams({this.eventId});

  /// When set, filters results to requests for a specific event.
  final String? eventId;

  @override
  List<Object?> get props => [eventId];
}

/// List the current user's join requests (joiner view).
/// GET /me/join-requests?eventId=...  (eventId is optional)
class ListMyJoinRequestsUseCase
    implements UseCase<List<JoinRequestWithEvent>, ListMyJoinRequestsParams> {
  const ListMyJoinRequestsUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, List<JoinRequestWithEvent>>> call(
    ListMyJoinRequestsParams params,
  ) => _repository.listMyJoinRequests(eventId: params.eventId);
}
