import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignInParams extends Equatable {
  const SignInParams({required this.email, required this.password});
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class SignInUseCase implements UseCase<AuthSession, SignInParams> {
  const SignInUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, AuthSession>> call(SignInParams params) {
    return _repository.signIn(email: params.email, password: params.password);
  }
}
