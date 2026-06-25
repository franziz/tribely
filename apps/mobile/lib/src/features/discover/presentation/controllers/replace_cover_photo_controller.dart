import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../events/presentation/providers/events_providers.dart';
import '../state/replace_cover_photo_state.dart';
import '../../../events/domain/usecases/replace_cover_photo_usecase.dart';
import '../../../events/domain/usecases/upload_cover_photo_usecase.dart';

/// Owns the per-event "replace cover photo" flow state.
///
/// Keyed by eventId via [NotifierProvider.autoDispose.family] — each event-detail
/// page gets its own isolated controller instance, discarded when the page is popped.
///
/// Flow:
///   1. UI calls [replaceCoverPhoto(croppedBytes)].
///   2. Controller calls [UploadCoverPhotoUseCase] with an [onProgress] callback
///      that emits [ReplaceCoverPhotoUploading] state transitions.
///   3. On [Right(storageKey)] → calls [ReplaceCoverPhotoUseCase].
///   4. On [Right(event)] → emits [ReplaceCoverPhotoSuccess].
///   5. On any [Left(failure)] → emits [ReplaceCoverPhotoFailed].
///
/// Navigation and provider invalidation are NOT performed here — the page
/// (event_detail_page.dart) observes [ReplaceCoverPhotoSuccess] via [ref.listen]
/// and invalidates the event-detail + discover-feed providers.
///
/// Does NOT import or extend [CreateEventController]; owns its own state machine.
class ReplaceCoverPhotoController extends Notifier<ReplaceCoverPhotoState> {
  ReplaceCoverPhotoController(this.eventId);

  final String eventId;

  @override
  ReplaceCoverPhotoState build() => const ReplaceCoverPhotoIdle();

  /// Uploads [croppedBytes] via [UploadCoverPhotoUseCase], then commits the
  /// resulting storage key via [ReplaceCoverPhotoUseCase].
  ///
  /// Guards against re-entry: if a replace is already in flight the call is
  /// a no-op.
  Future<void> replaceCoverPhoto(Uint8List croppedBytes) async {
    if (state is ReplaceCoverPhotoUploading) return;

    // Phase 1: start upload with indeterminate progress.
    state = const ReplaceCoverPhotoUploading(progress: null);

    if (!ref.mounted) return;
    final uploadUseCase = ref.read(uploadCoverPhotoUseCaseProvider);

    final uploadResult = await uploadUseCase(
      croppedBytes,
      onProgress: (sent, total) {
        if (!ref.mounted) return;
        final progress = (total > 0) ? (sent / total).clamp(0.0, 1.0) : null;
        state = ReplaceCoverPhotoUploading(progress: progress);
      },
    );

    if (!ref.mounted) return;

    final storageKey = uploadResult.fold((failure) => null, (key) => key);
    if (storageKey == null) {
      // Upload failed — extract failure from Left.
      state = uploadResult.fold(
        (failure) => ReplaceCoverPhotoFailed(failure: failure),
        (_) => const ReplaceCoverPhotoIdle(), // unreachable
      );
      return;
    }

    // Phase 2: commit the storage key via PUT /events/:id/cover-photo.
    if (!ref.mounted) return;
    final replaceUseCase = ref.read(replaceCoverPhotoUseCaseProvider);
    final replaceResult = await replaceUseCase(
      ReplaceCoverPhotoParams(eventId: eventId, storageKey: storageKey),
    );

    if (!ref.mounted) return;
    state = replaceResult.fold(
      (failure) => ReplaceCoverPhotoFailed(failure: failure),
      (_) => const ReplaceCoverPhotoSuccess(),
    );
  }

  /// Resets the controller to [ReplaceCoverPhotoIdle] so the UI can dismiss
  /// the failure banner.
  void clearFailure() {
    if (state is ReplaceCoverPhotoFailed) {
      state = const ReplaceCoverPhotoIdle();
    }
  }
}

/// Provider keyed by eventId.
///
/// Each event-detail page that renders the camera overlay gets its own isolated
/// state. autoDispose discards the state when the page is popped, preventing
/// stale progress/failure state on re-entry.
final replaceCoverPhotoControllerProvider = NotifierProvider.autoDispose
    .family<ReplaceCoverPhotoController, ReplaceCoverPhotoState, String>(
      ReplaceCoverPhotoController.new,
    );
