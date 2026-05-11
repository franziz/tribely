import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class RequestPasswordResetParams extends Equatable {
  const RequestPasswordResetParams({required this.email});
  final String email;

  @override
  List<Object?> get props => [email];
}

class RequestPasswordResetUseCase
    implements UseCase<void, RequestPasswordResetParams> {
  const RequestPasswordResetUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(RequestPasswordResetParams params) {
    return _repository.requestPasswordReset(email: params.email);
  }
}
