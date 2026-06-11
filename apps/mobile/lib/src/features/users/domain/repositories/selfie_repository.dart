import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

// Selfie-specific failures are defined in core/error/failures.dart alongside
// the other project-wide Failure subclasses (SelfieIntakeDisabledFailure,
// SelfieNotVerifiedFailure). They are re-exported here via the failures import
// so callers can import either path.
export '../../../../core/error/failures.dart'
    show SelfieIntakeDisabledFailure, SelfieNotVerifiedFailure;

/// Domain port for the selfie verification intake flow.
///
/// Two-step contract:
///   1. [requestUploadUrl] — obtain a pre-signed (uploadUrl, storageKey) pair.
///   2. [submitSelfie] — PUT the JPEG bytes to uploadUrl, then signal
///      the backend that the upload is complete.
///
/// The repository encapsulates both the direct-storage PUT and the backend
/// submit call so the use case layer remains unaware of the two-phase upload
/// detail.
abstract class SelfieRepository {
  /// POST /auth/selfie — requests a pre-signed upload URL.
  ///
  /// Returns (uploadUrl, storageKey) on success.
  /// Returns [SelfieIntakeDisabledFailure] when the backend is in maintenance
  /// mode (503 SELFIE_INTAKE_DISABLED).
  Future<Either<Failure, ({String uploadUrl, String storageKey})>>
  requestUploadUrl();

  /// PUT jpegBytes to uploadUrl, then POST /auth/selfie/submit.
  ///
  /// Returns [Unit] on success.
  /// Returns [SelfieIntakeDisabledFailure] when the backend rejects mid-flow.
  Future<Either<Failure, Unit>> submitSelfie({
    required String uploadUrl,
    required String storageKey,
    required List<int> jpegBytes,
  });
}
