import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// State machine for the per-event "Replace Cover Photo" action.
///
/// Transitions:
///   Idle ─────────── replaceCoverPhoto(bytes) ──────────► Uploading(0.0)
///   Uploading ─────── progress callback ─────────────────► Uploading(N)
///   Uploading ─────── upload success + mutate success ───► Success
///   Uploading ─────── any failure ───────────────────────► Failed(failure)
///   Failed ──────────── (retry) ─────────────────────────► Uploading(0.0)
sealed class ReplaceCoverPhotoState extends Equatable {
  const ReplaceCoverPhotoState();
}

/// Default state — no replace action in progress.
final class ReplaceCoverPhotoIdle extends ReplaceCoverPhotoState {
  const ReplaceCoverPhotoIdle();

  @override
  List<Object?> get props => [];
}

/// Upload is in progress. [progress] is a 0.0–1.0 determinate value derived
/// from [UploadCoverPhotoUseCase]'s `onProgress` callback.
///
/// Null while awaiting the first progress callback (indeterminate phase).
final class ReplaceCoverPhotoUploading extends ReplaceCoverPhotoState {
  const ReplaceCoverPhotoUploading({required this.progress});

  /// 0.0–1.0 determinate progress; null = indeterminate (first callback not yet received).
  final double? progress;

  @override
  List<Object?> get props => [progress];
}

/// Both the upload and the PUT /cover-photo mutation succeeded.
///
/// The page observes this state and invalidates the event-detail + discover-feed
/// providers to trigger a data refresh.
final class ReplaceCoverPhotoSuccess extends ReplaceCoverPhotoState {
  const ReplaceCoverPhotoSuccess();

  @override
  List<Object?> get props => [];
}

/// The upload or mutation failed. [failure] carries the typed domain failure so
/// the UI can render a [BannerMessage] with a Retry action.
final class ReplaceCoverPhotoFailed extends ReplaceCoverPhotoState {
  const ReplaceCoverPhotoFailed({required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
