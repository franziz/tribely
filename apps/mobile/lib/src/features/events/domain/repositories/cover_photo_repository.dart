import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

/// Callback for tracking upload byte progress.
///
/// Mirrors Dio's [ProgressCallback] shape: [sent] bytes written so far,
/// [total] bytes in the body (may be -1 if unknown).
typedef CoverPhotoProgressCallback = void Function(int sent, int total);

/// Abstract repository for the cover photo upload flow.
///
/// Orchestrates the two-step presign → direct-PUT pipeline and returns the
/// `storageKey` on success. There is no confirm call — the creation wizard
/// fuses the key into the event body.
///
/// Failure paths:
///   - [ValidationFailure]: bytes are too large (pre-pick size cap exceeded).
///   - [ServerFailure]: presign API error or storage PUT failure.
///   - [NetworkFailure]: device is offline or PUT network error.
///   - [AuthFailure]: 401 on presign — session expired.
abstract class CoverPhotoRepository {
  /// Downscales [croppedBytes], presigns an upload URL, and PUTs the bytes
  /// directly to storage. Returns the `storageKey` on success.
  ///
  /// [onProgress] is an optional callback that fires as bytes are sent —
  /// callers can use it to drive a determinate [LinearProgressIndicator].
  Future<Either<Failure, String>> uploadCoverPhoto(
    Uint8List croppedBytes, {
    CoverPhotoProgressCallback? onProgress,
  });
}
