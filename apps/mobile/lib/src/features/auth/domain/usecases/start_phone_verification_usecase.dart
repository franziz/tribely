import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class StartPhoneParams extends Equatable {
  const StartPhoneParams({required this.phone});

  /// E.164 phone number, e.g. "+6591234567".
  final String phone;

  @override
  List<Object?> get props => [phone];
}

/// Initiates the SMS OTP flow. Sends a 6-digit code to [StartPhoneParams.phone].
///
/// Returns [Right(null)] on success. On the server-side rate cap (5/hr per
/// number), returns [Left(SmsRateLimitedFailure)].
class StartPhoneVerificationUseCase
    implements UseCase<void, StartPhoneParams> {
  const StartPhoneVerificationUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(StartPhoneParams params) {
    return _repository.startPhoneVerification(phone: params.phone);
  }
}
