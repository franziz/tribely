import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../events/presentation/widgets/cover_photo_source_sheet.dart';
import '../controllers/replace_cover_photo_controller.dart';
import '../providers/discover_providers.dart';
import '../providers/event_detail_providers.dart';
import '../state/replace_cover_photo_state.dart';

/// Host-only circular camera overlay button for the event-detail hero image.
///
/// **Placement**: callers embed this inside a [Stack] via a [Positioned]
/// bottom-right (12dp inset). [_HeroImage] in event_detail_page.dart places it
/// as the second overlay (category badge occupies bottom-left).
///
/// **Visual**: 44pt circle. `Icons.camera_alt` at 20sp in
/// [TribelyColors.nightInkPrimary] on a 64%-opacity [TribelyColors.nightSurface]
/// scrim. Semantic label "Replace cover photo".
///
/// **Gate**: render ONLY when `isHostViewer == true`. The event-detail page gates
/// this via the existing [isHostViewer] flag computed at `event_detail_page.dart:80-83`.
///
/// **Tap flow**:
///   1. Opens [CoverPhotoSourceSheet] UNMODIFIED.
///   2. File picked → push `/events/create/crop-photo` (TRI-49 page) → on
///      confirm → [ReplaceCoverPhotoController.replaceCoverPhoto].
///   3. During upload: suppresses the button; shows [_UploadingOverlay].
///   4. On success: emits [ReplaceCoverPhotoSuccess]; the page's [ref.listen]
///      invalidates providers + triggers haptic.
///   5. On failure: shows [_FailedOverlay] with Retry; button restored on
///      Retry (clears to Idle).
///
/// TRI-306 — fifth sanctioned cross-feature exception:
///   Imports `events/presentation/widgets/cover_photo_source_sheet.dart` (+ the
///   TRI-49 crop page route) per EL sign-off. See mobile-architecture.md §exceptions.
class CoverPhotoReplaceButton extends ConsumerWidget {
  const CoverPhotoReplaceButton({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replaceState = ref.watch(
      replaceCoverPhotoControllerProvider(eventId),
    );

    return switch (replaceState) {
      ReplaceCoverPhotoUploading(:final progress) => _UploadingOverlay(
        progress: progress,
      ),
      ReplaceCoverPhotoFailed(:final failure) => _FailedOverlay(
        failureMessage: failure.message,
        onRetry: () => ref
            .read(replaceCoverPhotoControllerProvider(eventId).notifier)
            .clearFailure(),
      ),
      // Idle + Success both show the button.
      // Success is transient — the page's ref.listen fires on the same frame
      // and invalidates providers; the controller resets to Idle on clearFailure.
      _ => _CameraButton(onTap: () => _onCameraTap(context, ref)),
    };
  }

  Future<void> _onCameraTap(BuildContext context, WidgetRef ref) async {
    await showCoverPhotoSourceSheet(
      context,
      onFilePicked: (XFile file) async {
        final bytes = await file.readAsBytes();
        if (!context.mounted) return;

        // Push to the existing TRI-49 crop page.
        // Route `/events/create/crop-photo` is registered in app_router.dart:343.
        final croppedBytes = await context.push<Uint8List>(
          '/events/create/crop-photo',
          extra: bytes,
        );

        if (croppedBytes == null) return; // user cancelled crop

        if (!context.mounted) return;
        await ref
            .read(replaceCoverPhotoControllerProvider(eventId).notifier)
            .replaceCoverPhoto(croppedBytes);

        // Haptic on success — provider invalidation is handled by the page's
        // ref.listen observing ReplaceCoverPhotoSuccess.
        if (!context.mounted) return;
        final postState = ref.read(
          replaceCoverPhotoControllerProvider(eventId),
        );
        if (postState is ReplaceCoverPhotoSuccess) {
          await HapticFeedback.lightImpact();
        }
      },
      onSizeError: () {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo is too large (max 15 MB). Please pick a smaller image.',
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Camera button — idle / success state
// ---------------------------------------------------------------------------

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  static const double _size = 44;
  static const double _iconSize = 20;
  static const double _inset = 12;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _inset,
      right: _inset,
      child: Semantics(
        label: 'Replace cover photo',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: TribelyColors.nightSurface.withValues(alpha: 0.64),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              size: _iconSize,
              color: TribelyColors.nightInkPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uploading overlay — progress strip + caption
// ---------------------------------------------------------------------------

/// Full-width overlay shown while an upload is in progress.
///
/// Shows a 3dp [LinearProgressIndicator] at the hero bottom and a "Updating
/// cover photo…" caption centred on a dark scrim. The camera button is
/// suppressed while this is visible (the controller is in [ReplaceCoverPhotoUploading]).
class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay({required this.progress});

  /// 0.0–1.0 determinate value; null = indeterminate (first callback not yet
  /// received from [UploadCoverPhotoUseCase.onProgress]).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption on a dark scrim.
          Container(
            color: TribelyColors.nightSurface.withValues(alpha: 0.64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Updating cover photo…',
              textAlign: TextAlign.center,
              style: TribelyType.caption(TribelyColors.nightInkPrimary),
            ),
          ),
          // 3dp progress strip (determinate when progress is known).
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: TribelyColors.nightBorderSubtle,
            valueColor: const AlwaysStoppedAnimation<Color>(
              TribelyColors.nightPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Failure overlay — BannerMessage with Retry
// ---------------------------------------------------------------------------

/// Positioned at the hero bottom when upload or mutation fails.
///
/// Shows a [BannerMessage] with a Retry action. Tapping Retry clears the
/// failure state (controller → Idle) so the camera button re-appears and the
/// user can start a new pick → crop → upload cycle.
///
/// The original photo is automatically restored because no local state is
/// held — the hero image always reads from the event entity in the provider.
class _FailedOverlay extends StatelessWidget {
  const _FailedOverlay({required this.failureMessage, required this.onRetry});

  final String failureMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: BannerMessage(
          message: failureMessage.isNotEmpty
              ? failureMessage
              : 'Cover photo update failed.',
          action: BannerAction(label: 'Retry', onTap: onRetry),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero cross-fade wrapper
// ---------------------------------------------------------------------------

/// Wraps a hero image widget in an [AnimatedSwitcher] so that when the
/// cover photo URL changes (after a successful replace), the new image
/// cross-fades in.
///
/// Duration: 250ms per spec, reduced to [Duration.zero] when the user has
/// enabled "Reduce Motion" in system settings
/// ([TribelyMotionContext.reduceMotion]).
///
/// Usage in [_HeroImage]:
/// ```dart
/// CoverPhotoCrossFade(
///   imageKey: ValueKey(event.coverPhotoUrl),
///   child: _buildImageOrPlaceholder(event),
/// )
/// ```
class CoverPhotoCrossFade extends StatelessWidget {
  const CoverPhotoCrossFade({
    required this.imageKey,
    required this.child,
    super.key,
  });

  /// Key that changes when the cover photo URL changes — drives the cross-fade.
  final Key imageKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = context.reduceMotion
        ? Duration.zero
        : TribelyMotion.medium;

    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: imageKey, child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Success listener helper
// ---------------------------------------------------------------------------

/// Handles a [ReplaceCoverPhotoSuccess] transition by invalidating the
/// event-detail and discover-feed providers.
///
/// Called from [ref.listen] in event_detail_page.dart's [_LoadedBody].
/// Extracted as a top-level function so the invalidation logic is testable
/// without mounting the full page.
void handleReplaceCoverPhotoSuccess(WidgetRef ref, {required String eventId}) {
  // Reload the event so the hero image URL updates immediately.
  ref.invalidate(eventDetailControllerProvider(eventId));

  // Invalidate the discover feed so event-card thumbnails reflect the change.
  ref.invalidate(discoverControllerProvider);
}
