import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../controllers/create_event_controller.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/cover_photo_source_sheet.dart';

/// Step 0 — Cover photo.
///
/// The user picks a photo via [CoverPhotoSourceSheet], crops it on
/// [CoverPhotoCropPage] (route: `/events/create/crop-photo`), and the
/// wizard uploads the cropped bytes via [CreateEventController.uploadCoverPhoto].
///
/// States:
///   - No photo: "Add cover photo" CTA.
///   - Uploading: [LinearProgressIndicator] (determinate when progress is
///     available, indeterminate while waiting for first progress callback).
///     "Change photo" affordance hidden during upload.
///   - Uploaded: thumbnail-style confirmation row + "Change photo" link.
///   - Upload error:
///       - [ValidationFailure] (size/MIME): no Retry — must re-pick.
///       - Other failures: Retry uses the already-cropped local bytes.
class CreateEventStep0CoverPhotoPage extends ConsumerWidget {
  const CreateEventStep0CoverPhotoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventControllerProvider);
    if (state is! CreateEventEditing) return const SizedBox.shrink();

    final controller = ref.read(createEventControllerProvider.notifier);
    final draft = state.formData;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final primary = dark ? TribelyColors.nightPrimary : TribelyColors.paperPrimary;

    final hasKey = draft.coverPhotoStorageKey != null;
    final isUploading = state.coverPhotoUploading;
    final progress = state.coverPhotoProgress;
    final error = state.coverPhotoError;
    final localBytes = state.coverPhotoLocalBytes;

    // Whether the current failure requires a full re-pick (no Retry path).
    final isValidationError = error is ValidationFailure;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Header
          Text('Cover photo', style: TribelyType.headline(ink)),
          const SizedBox(height: 4),
          Text(
            'Add a photo to make your event stand out.',
            style: TribelyType.bodyM(inkSecondary),
          ),

          const SizedBox(height: 32),

          if (isUploading) ...[
            // --------------- Uploading state ---------------
            _UploadingCard(
              progress: progress,
              borderColor: borderSubtle,
              inkSecondary: inkSecondary,
            ),
          ] else if (hasKey) ...[
            // --------------- Photo uploaded ---------------
            _UploadedCard(
              storageKey: draft.coverPhotoStorageKey!,
              ink: ink,
              inkSecondary: inkSecondary,
              primary: primary,
              borderColor: borderSubtle,
              onChangeTap: () => _pickPhoto(context, ref, controller),
            ),
          ] else ...[
            // --------------- No photo yet ---------------
            _AddPhotoCta(
              borderColor: borderSubtle,
              primary: primary,
              onTap: () => _pickPhoto(context, ref, controller),
            ),
          ],

          // --------------- Error banner ---------------
          if (error != null && !isUploading) ...[
            const SizedBox(height: 16),
            _ErrorBanner(
              error: error,
              isValidationError: isValidationError,
              localBytes: localBytes,
              inkSecondary: inkSecondary,
              onRetry: localBytes != null
                  ? () => controller.uploadCoverPhoto(localBytes)
                  : null,
              onRePick: () => _pickPhoto(context, ref, controller),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(
    BuildContext context,
    WidgetRef ref,
    CreateEventController controller,
  ) async {
    await showCoverPhotoSourceSheet(
      context,
      onFilePicked: (XFile file) async {
        // Read bytes from the picked file.
        final bytes = await file.readAsBytes();

        // Push to crop screen and await the cropped result.
        if (!context.mounted) return;
        final croppedBytes = await context.push<Uint8List>(
          '/events/create/crop-photo',
          extra: bytes,
        );

        if (croppedBytes == null) return; // user cancelled crop

        // Upload the cropped bytes.
        await controller.uploadCoverPhoto(croppedBytes);
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
// Uploading state card
// ---------------------------------------------------------------------------

class _UploadingCard extends StatelessWidget {
  const _UploadingCard({
    required this.progress,
    required this.borderColor,
    required this.inkSecondary,
  });

  final double? progress;
  final Color borderColor;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('Uploading photo…', style: TribelyType.bodyM(inkSecondary)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Uploaded state card
// ---------------------------------------------------------------------------

class _UploadedCard extends StatelessWidget {
  const _UploadedCard({
    required this.storageKey,
    required this.ink,
    required this.inkSecondary,
    required this.primary,
    required this.borderColor,
    required this.onChangeTap,
  });

  final String storageKey;
  final Color ink;
  final Color inkSecondary;
  final Color primary;
  final Color borderColor;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 36, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cover photo added', style: TribelyType.bodyM(ink)),
                const SizedBox(height: 2),
                Text(
                  'The photo will appear on your event listing.',
                  style: TribelyType.caption(inkSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeTap,
            child: Text('Change', style: TribelyType.caption(primary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-photo CTA
// ---------------------------------------------------------------------------

class _AddPhotoCta extends StatelessWidget {
  const _AddPhotoCta({
    required this.borderColor,
    required this.primary,
    required this.onTap,
  });

  final Color borderColor;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor,
            width: 1.5,
            // Dashed border emulated via a solid border; dash rendering
            // requires a custom painter. Solid is acceptable for v1.
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: primary),
            const SizedBox(height: 8),
            Text(
              'Add cover photo',
              style: TribelyType.bodyM(primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.isValidationError,
    required this.localBytes,
    required this.inkSecondary,
    required this.onRetry,
    required this.onRePick,
  });

  final Failure error;
  final bool isValidationError;
  final Uint8List? localBytes;
  final Color inkSecondary;
  final VoidCallback? onRetry;
  final VoidCallback onRePick;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final bgColor = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;

    final message = isValidationError
        ? 'Photo is too large or format not supported. Please pick a different image.'
        : (error.message.isNotEmpty ? error.message : 'Upload failed. Please try again.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TribelyType.caption(accentColor)),
                const SizedBox(height: 8),
                // Re-pick path is always available.
                GestureDetector(
                  onTap: onRePick,
                  child: Text(
                    'Pick a different photo',
                    style: TribelyType.caption(accentColor).copyWith(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Retry path only for non-validation failures with local bytes.
                if (!isValidationError && onRetry != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onRetry,
                    child: Text(
                      'Retry upload',
                      style: TribelyType.caption(accentColor).copyWith(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
