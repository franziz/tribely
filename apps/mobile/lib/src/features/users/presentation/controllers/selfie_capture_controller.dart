import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/repositories/selfie_repository.dart';
import '../../domain/usecases/request_selfie_upload_usecase.dart';
import '../../domain/usecases/submit_selfie_usecase.dart';
import '../state/selfie_capture_upload_state.dart';

// ---------------------------------------------------------------------------
// Repository bridge — lifts the GetIt singleton into the Riverpod graph so
// use-case providers can resolve it uniformly via ref (same pattern as
// users_providers.dart's _userProfileRepositoryProvider).
// ---------------------------------------------------------------------------

final _selfieRepositoryProvider = Provider<SelfieRepository>(
  (_) => sl<SelfieRepository>(),
);

// ---------------------------------------------------------------------------
// Use-case providers — thin wrappers so the controller uses ref.read for DI
// rather than GetIt directly.
// ---------------------------------------------------------------------------

/// Provider for [RequestSelfieUploadUseCase].
final requestSelfieUploadUseCaseProvider =
    Provider<RequestSelfieUploadUseCase>(
      (ref) => RequestSelfieUploadUseCase(
        ref.read(_selfieRepositoryProvider),
      ),
    );

/// Provider for [SubmitSelfieUseCase].
final submitSelfieUseCaseProvider = Provider<SubmitSelfieUseCase>(
  (ref) => SubmitSelfieUseCase(
    ref.read(_selfieRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Owns the upload-orchestration lifecycle for the selfie capture flow.
///
/// Responsibilities:
///   - Requests a presigned upload URL via [RequestSelfieUploadUseCase].
///   - Uploads the captured JPEG and submits the storage key via
///     [SubmitSelfieUseCase].
///   - Transitions [SelfieCaptureUploadState] so the page can render
///     spinner / error / navigate-on-success.
///
/// Camera-hardware lifecycle (CameraController, ML-Kit, guidance) lives in
/// the page's [State] — NOT here.
///
/// Usage: pair with [NotifierProvider.autoDispose] so state resets when the
/// capture screen leaves the widget tree.
class SelfieCaptureController extends Notifier<SelfieCaptureUploadState> {
  @override
  SelfieCaptureUploadState build() => const SelfieCaptureUploadIdle();

  /// Called by the page once the JPEG bytes are available.
  ///
  /// Steps:
  ///   1. Request presigned upload URL.
  ///   2. PUT JPEG to storage URL.
  ///   3. POST storage key to submit endpoint.
  ///
  /// On failure: transitions to [SelfieCaptureUploadError] with the
  /// appropriate banner message.
  ///
  /// On success: transitions to [SelfieCaptureUploadSuccess]; the page
  /// listens and calls `context.go('/settings/verification')`.
  Future<void> submit(List<int> jpegBytes) async {
    if (state is SelfieCaptureUploadInProgress) return; // prevent double-tap
    state = const SelfieCaptureUploadInProgress();

    // Step 1: request presign.
    final requestUseCase = ref.read(requestSelfieUploadUseCaseProvider);
    final presignResult = await requestUseCase(const NoParams());

    if (!ref.mounted) return;

    ({String uploadUrl, String storageKey})? presign;
    presignResult.fold(
      (failure) {
        state = SelfieCaptureUploadError(message: _messageFor(failure));
      },
      (value) {
        presign = value;
      },
    );

    final resolvedPresign = presign;
    if (resolvedPresign == null) return;

    // Step 2: upload JPEG + submit.
    final submitUseCase = ref.read(submitSelfieUseCaseProvider);
    final submitResult = await submitUseCase(
      SubmitSelfieParams(
        uploadUrl: resolvedPresign.uploadUrl,
        storageKey: resolvedPresign.storageKey,
        jpegBytes: jpegBytes,
      ),
    );

    if (!ref.mounted) return;

    submitResult.fold(
      (failure) => state = SelfieCaptureUploadError(message: _messageFor(failure)),
      (_) => state = const SelfieCaptureUploadSuccess(),
    );
  }

  /// Resets to idle — called by the page when the user taps the retry action.
  void reset() => state = const SelfieCaptureUploadIdle();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _messageFor(Failure failure) => switch (failure) {
        NetworkFailure() =>
          'You appear to be offline. Check your connection and try again.',
        SelfieIntakeDisabledFailure() =>
          'Verification is temporarily unavailable. Please try again later.',
        _ => 'Something went wrong uploading your photo. Please try again.',
      };
}

/// Stable provider — autoDispose so state resets when the capture page leaves
/// the widget tree. `Notifier<T>` + `NotifierProvider.autoDispose` per project
/// convention (CLAUDE.md gotcha: do NOT use `AutoDisposeNotifier<T>`).
final selfieCaptureControllerProvider = NotifierProvider.autoDispose<
    SelfieCaptureController, SelfieCaptureUploadState>(
  SelfieCaptureController.new,
);
