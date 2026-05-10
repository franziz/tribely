import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class VerifyEmailParams extends Equatable {
  const VerifyEmailParams({required this.code});
  final String code;

  @override
  List<Object?> get props => [code];
}

class VerifyEmailUseCase implements UseCase<User, VerifyEmailParams> {
  const VerifyEmailUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(VerifyEmailParams params) {
    return _repository.verifyEmail(code: params.code);
  }
}
