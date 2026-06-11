import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/selfie_repository.dart';

/// Step 1 of the selfie intake flow.
///
/// Calls POST /auth/selfie and returns the (uploadUrl, storageKey) pair that
/// the capture page uses to upload the JPEG and then call
/// [SubmitSelfieUseCase].
///
/// Failure paths:
///   - [SelfieIntakeDisabledFailure]: backend is in maintenance mode (503).
///   - [NetworkFailure]: device is offline.
///   - [ServerFailure]: unexpected backend error.
class RequestSelfieUploadUseCase
    implements
        UseCase<({String uploadUrl, String storageKey}), NoParams> {
  const RequestSelfieUploadUseCase(this._repository);
  final SelfieRepository _repository;

  @override
  Future<Either<Failure, ({String uploadUrl, String storageKey})>> call(
    NoParams params,
  ) =>
      _repository.requestUploadUrl();
}
