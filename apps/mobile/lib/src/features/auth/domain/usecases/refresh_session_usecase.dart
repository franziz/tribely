import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class RefreshSessionUseCase implements UseCase<AuthSession, NoParams> {
  const RefreshSessionUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession>> call(NoParams params) =>
      _repository.refresh();
}
