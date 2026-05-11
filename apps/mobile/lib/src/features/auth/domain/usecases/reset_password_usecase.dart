import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({
    required this.email,
    required this.code,
    required this.newPassword,
  });
  final String email;
  final String code;
  final String newPassword;

  @override
  List<Object?> get props => [email, code, newPassword];
}

class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  const ResetPasswordUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    return _repository.resetPassword(
      email: params.email,
      code: params.code,
      newPassword: params.newPassword,
    );
  }
}
