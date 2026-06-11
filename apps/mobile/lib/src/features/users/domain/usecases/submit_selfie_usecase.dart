import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/selfie_repository.dart';

/// Step 2 of the selfie intake flow.
///
/// Uploads the JPEG bytes to the pre-signed URL obtained from
/// [RequestSelfieUploadUseCase], then POSTs /auth/selfie/submit to signal
/// the backend that the upload is complete. The backend transitions the
/// selfie record to `pending` review status.
///
/// Failure paths:
///   - [SelfieIntakeDisabledFailure]: intake was disabled between presign and
///     submit (race condition handled gracefully).
///   - [NetworkFailure]: device went offline mid-upload.
///   - [ServerFailure]: unexpected backend error.
class SubmitSelfieUseCase implements UseCase<Unit, SubmitSelfieParams> {
  const SubmitSelfieUseCase(this._repository);
  final SelfieRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SubmitSelfieParams params) =>
      _repository.submitSelfie(
        uploadUrl: params.uploadUrl,
        storageKey: params.storageKey,
        jpegBytes: params.jpegBytes,
      );
}

class SubmitSelfieParams extends Equatable {
  const SubmitSelfieParams({
    required this.uploadUrl,
    required this.storageKey,
    required this.jpegBytes,
  });

  final String uploadUrl;
  final String storageKey;
  final List<int> jpegBytes;

  @override
  List<Object?> get props => [uploadUrl, storageKey, jpegBytes];
}
