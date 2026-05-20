import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/account_repository.dart';

class DeleteAccountUseCase implements UseCase<void, NoParams> {
  const DeleteAccountUseCase(this._repository);

  final AccountRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) =>
      _repository.deleteAccount();
}
