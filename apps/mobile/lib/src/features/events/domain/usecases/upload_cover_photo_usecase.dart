import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/cover_photo_repository.dart';

/// Uploads a cropped cover photo for an event.
///
/// Delegates to [CoverPhotoRepository.uploadCoverPhoto] which orchestrates
/// the downscale → presign(`image/jpeg`) → direct-PUT two-step flow. Returns
/// the `storageKey` on success; the caller fuses the key into the create-event
/// body — there is no separate confirm call.
///
/// Failure paths:
///   - [ValidationFailure] (code 'COVER_PHOTO_TOO_LARGE'): input bytes exceed
///     the 15 MB pre-pick size cap.
///   - [ServerFailure]: presign API error or storage PUT failure.
///   - [NetworkFailure]: device is offline or PUT network error.
///   - [AuthFailure]: 401 on presign — session expired.
class UploadCoverPhotoUseCase implements UseCase<String, Uint8List> {
  const UploadCoverPhotoUseCase(this._repository);
  final CoverPhotoRepository _repository;

  @override
  Future<Either<Failure, String>> call(Uint8List params) =>
      _repository.uploadCoverPhoto(params);
}
