import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class VerifyPhoneParams extends Equatable {
  const VerifyPhoneParams({required this.phone, required this.code});

  /// E.164 phone number, e.g. "+6591234567".
  final String phone;

  /// 6-digit OTP received via SMS.
  final String code;

  @override
  List<Object?> get props => [phone, code];
}

/// Verifies the SMS OTP. On success the server marks the phone as verified
/// and returns the updated [User] with [User.phoneVerifiedAt] populated.
///
/// The controller calls [SessionController.setUser] with the returned user so
/// the session state reflects verification without a follow-up /auth/me call.
class VerifyPhoneUseCase implements UseCase<User, VerifyPhoneParams> {
  const VerifyPhoneUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(VerifyPhoneParams params) {
    return _repository.verifyPhone(phone: params.phone, code: params.code);
  }
}
