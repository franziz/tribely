import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/join_request_repository.dart';

class RemoveAttendeeParams extends Equatable {
  const RemoveAttendeeParams({
    required this.eventId,
    required this.joinRequestId,
    required this.reason,
  });

  final String eventId;
  final String joinRequestId;

  /// Mandatory reason shown to the removed attendee.
  /// Maps to the backend body `{ reason }`.
  final String reason;

  @override
  List<Object?> get props => [eventId, joinRequestId, reason];
}

/// Remove an approved attendee from an event (host action).
/// POST /events/:eventId/join-requests/:joinRequestId/remove
class RemoveAttendeeUseCase implements UseCase<Unit, RemoveAttendeeParams> {
  const RemoveAttendeeUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RemoveAttendeeParams params) =>
      _repository.removeAttendee(
        eventId: params.eventId,
        joinRequestId: params.joinRequestId,
        reason: params.reason,
      );
}
