import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetMeUseCase implements UseCase<User, NoParams> {
  const GetMeUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(NoParams params) => _repository.me();
}
