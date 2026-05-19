import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/pending_check_in.dart';
import '../repositories/check_ins_repository.dart';

/// Fetches pending post-event check-ins for the current user.
///
/// Takes no parameters — the server scopes results to the authenticated user
/// via the bearer token. Returns an empty list (not a failure) when there are
/// no pending check-ins.
class SurfacePendingCheckInsUseCase
    implements UseCase<List<PendingCheckIn>, NoParams> {
  const SurfacePendingCheckInsUseCase(this._repository);

  final CheckInsRepository _repository;

  @override
  Future<Either<Failure, List<PendingCheckIn>>> call(NoParams params) =>
      _repository.surfacePending();
}
