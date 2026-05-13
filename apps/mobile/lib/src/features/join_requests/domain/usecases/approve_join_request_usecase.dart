import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/join_request.dart';
import '../repositories/join_request_repository.dart';

class ApproveJoinRequestParams extends Equatable {
  const ApproveJoinRequestParams({required this.joinRequestId});

  final String joinRequestId;

  @override
  List<Object?> get props => [joinRequestId];
}

/// Approve a pending join request (host action).
/// POST /join-requests/:id/approve
class ApproveJoinRequestUseCase
    implements UseCase<JoinRequest, ApproveJoinRequestParams> {
  const ApproveJoinRequestUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, JoinRequest>> call(ApproveJoinRequestParams params) =>
      _repository.approve(joinRequestId: params.joinRequestId);
}
