import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/user_block_repository.dart';

class UnblockUserParams extends Equatable {
  const UnblockUserParams({required this.blockedUserId});

  final String blockedUserId;

  @override
  List<Object?> get props => [blockedUserId];
}

/// Remove a block against another user.
///
/// DELETE /me/blocks/:blockedUserId — idempotent; no error if not blocked.
class UnblockUserUseCase implements UseCase<void, UnblockUserParams> {
  const UnblockUserUseCase(this._repository);
  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, void>> call(UnblockUserParams params) =>
      _repository.unblockUser(blockedUserId: params.blockedUserId);
}
