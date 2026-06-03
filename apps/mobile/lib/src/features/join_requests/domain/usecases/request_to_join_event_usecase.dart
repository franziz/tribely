import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request.dart';
import '../repositories/join_request_repository.dart';

class RequestToJoinEventParams extends Equatable {
  const RequestToJoinEventParams({
    required this.eventId,
    this.acknowledgedSafetyReminder = false,
  });

  final String eventId;

  /// When true, the user has acknowledged the pre-event safety reminder.
  /// Sent as `acknowledgedSafetyReminder` in the POST body (TRI-34 Brief D).
  final bool acknowledgedSafetyReminder;

  @override
  List<Object?> get props => [eventId, acknowledgedSafetyReminder];
}

/// Request to join an event as a participant.
/// POST /events/:eventId/join-requests
class RequestToJoinEventUseCase
    implements UseCase<JoinRequest, RequestToJoinEventParams> {
  const RequestToJoinEventUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, JoinRequest>> call(RequestToJoinEventParams params) =>
      _repository.requestToJoin(
        eventId: params.eventId,
        acknowledgedSafetyReminder: params.acknowledgedSafetyReminder,
      );
}
