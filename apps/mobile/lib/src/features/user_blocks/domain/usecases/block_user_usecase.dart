import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_block.dart';
import '../repositories/user_block_repository.dart';

class BlockUserParams extends Equatable {
  const BlockUserParams({required this.blockedUserId});

  final String blockedUserId;

  @override
  List<Object?> get props => [blockedUserId];
}

/// Block another user.
///
/// POST /me/blocks — delegates to [UserBlockRepository.blockUser].
/// Returns [SelfBlockFailure] when the caller tries to block themselves.
class BlockUserUseCase implements UseCase<UserBlock, BlockUserParams> {
  const BlockUserUseCase(this._repository);
  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, UserBlock>> call(BlockUserParams params) =>
      _repository.blockUser(blockedUserId: params.blockedUserId);
}
