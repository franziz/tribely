import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/ports/session_reader.dart';
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

/// Fetches the authenticated user's own profile.
///
/// Resolves the current user ID via [SessionReader] so callers never need to
/// thread an ID through the call stack. Returns [AuthFailure] when called
/// without an active session.
class GetMyProfileUseCase implements UseCase<UserProfile, NoParams> {
  const GetMyProfileUseCase(this._repository, this._sessionReader);

  final UserProfileRepository _repository;
  final SessionReader _sessionReader;

  @override
  Future<Either<Failure, UserProfile>> call(NoParams params) {
    final userId = _sessionReader.currentUserId;
    if (userId == null) {
      return Future.value(const Left(AuthFailure('Not authenticated')));
    }
    return _repository.getUserProfile(userId);
  }
}
