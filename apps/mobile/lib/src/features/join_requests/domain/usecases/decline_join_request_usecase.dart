import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request.dart';
import '../repositories/join_request_repository.dart';

class DeclineJoinRequestParams extends Equatable {
  const DeclineJoinRequestParams({required this.joinRequestId, this.reason});

  final String joinRequestId;

  /// Optional reason shown to the requester. Maps to the backend body `{ reason }`.
  final String? reason;

  @override
  List<Object?> get props => [joinRequestId, reason];
}

/// Decline a pending join request (host action).
/// UI calls this "decline"; the endpoint verb is POST /join-requests/:id/reject.
class DeclineJoinRequestUseCase
    implements UseCase<JoinRequest, DeclineJoinRequestParams> {
  const DeclineJoinRequestUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, JoinRequest>> call(DeclineJoinRequestParams params) =>
      _repository.decline(
        joinRequestId: params.joinRequestId,
        reason: params.reason,
      );
}
