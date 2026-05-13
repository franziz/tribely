import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/join_request_repository.dart';

class WithdrawJoinRequestParams extends Equatable {
  const WithdrawJoinRequestParams({required this.joinRequestId});

  final String joinRequestId;

  @override
  List<Object?> get props => [joinRequestId];
}

/// Withdraw a join request (joiner action).
/// DELETE /join-requests/:id
class WithdrawJoinRequestUseCase
    implements UseCase<void, WithdrawJoinRequestParams> {
  const WithdrawJoinRequestUseCase(this._repository);
  final JoinRequestRepository _repository;

  @override
  Future<Either<Failure, void>> call(WithdrawJoinRequestParams params) =>
      _repository.withdraw(joinRequestId: params.joinRequestId);
}
