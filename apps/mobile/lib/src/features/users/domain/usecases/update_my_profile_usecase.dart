import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class UpdateMyProfileUseCase
    implements UseCase<UserProfile, UpdateProfileParams> {
  const UpdateMyProfileUseCase(this._repository);
  final UserProfileRepository _repository;

  @override
  Future<Either<Failure, UserProfile>> call(UpdateProfileParams params) =>
      _repository.updateMyProfile(params);
}
