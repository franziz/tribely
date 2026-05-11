import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class GetUserProfileParams extends Equatable {
  const GetUserProfileParams({required this.userId});
  final String userId;

  @override
  List<Object?> get props => [userId];
}

class GetUserProfileUseCase
    implements UseCase<UserProfile, GetUserProfileParams> {
  const GetUserProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  @override
  Future<Either<Failure, UserProfile>> call(GetUserProfileParams params) =>
      _repository.getUserProfile(params.userId);
}
