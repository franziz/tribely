import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

/// Uploads a new avatar for the current user.
///
/// Delegates to [UserProfileRepository.uploadAvatar] which orchestrates the
/// presign → direct-PUT → confirm three-step flow. Returns the confirmed
/// [UserProfile] (with the new signed avatarUrl) on success.
///
/// Failure paths:
///   - [ServerFailure]: presign or confirm API error.
///   - [NetworkFailure]: device is offline, or storage PUT network error.
///   - [AuthFailure]: 401 on presign/confirm — session expired.
class UploadAvatarUseCase implements UseCase<UserProfile, Uint8List> {
  const UploadAvatarUseCase(this._repository);
  final UserProfileRepository _repository;

  @override
  Future<Either<Failure, UserProfile>> call(Uint8List params) =>
      _repository.uploadAvatar(params);
}
