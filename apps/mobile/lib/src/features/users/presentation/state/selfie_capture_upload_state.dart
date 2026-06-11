import 'package:equatable/equatable.dart';

/// State for [SelfieCaptureController].
///
/// Tracks the upload-orchestration lifecycle:
///   idle → (user taps capture) → uploading → success
///                                           ↘ error(message)
///
/// Camera-hardware lifecycle (CameraController, ML-Kit guidance) is NOT
/// modelled here — it lives in _SelfieCapturePageState.
sealed class SelfieCaptureUploadState extends Equatable {
  const SelfieCaptureUploadState();

  @override
  List<Object?> get props => [];
}

/// Default idle state — no upload in flight.
class SelfieCaptureUploadIdle extends SelfieCaptureUploadState {
  const SelfieCaptureUploadIdle();
}

/// Presign request + S3 PUT + submit are in flight.
class SelfieCaptureUploadInProgress extends SelfieCaptureUploadState {
  const SelfieCaptureUploadInProgress();
}

/// Upload completed successfully — navigate away.
class SelfieCaptureUploadSuccess extends SelfieCaptureUploadState {
  const SelfieCaptureUploadSuccess();
}

/// Upload failed — surface [message] in the error banner.
class SelfieCaptureUploadError extends SelfieCaptureUploadState {
  const SelfieCaptureUploadError({required this.message});

  /// Human-readable banner text sourced from [selfie_capture_copy.dart].
  final String message;

  @override
  List<Object?> get props => [message];
}
