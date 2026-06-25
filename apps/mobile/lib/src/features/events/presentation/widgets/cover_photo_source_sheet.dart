import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// Maximum permitted cover-photo size in bytes (15 MB).
const int kCoverPhotoMaxBytes = 15 * 1024 * 1024;

/// Two-option bottom sheet for cover photo source selection.
///
/// Design spec mirrors [AvatarSourceSheet]:
///   - Drag handle: 36×4dp centred at top.
///   - "Take photo" (camera) row — [Icons.camera_alt], listed first.
///   - "Choose from library" row — [Icons.photo_library], listed second.
///   - Tap-outside / drag dismiss enabled (no Cancel row per spec).
///
/// Size validation (15 MB cap) happens inside this widget before calling
/// [onFilePicked]. If the file exceeds the cap, [onSizeError] is invoked
/// instead and the user must re-pick — no Retry flow; the sheet stays
/// dismissible and the caller handles re-opening.
///
/// [onFilePicked] receives a raw [XFile]; the caller reads bytes and routes
/// to the crop screen.
///
/// Usage:
/// ```dart
/// showCoverPhotoSourceSheet(
///   context,
///   onFilePicked: (file) { /* push to crop screen */ },
///   onSizeError: () { /* show re-pick snackbar */ },
/// );
/// ```
class CoverPhotoSourceSheet extends StatelessWidget {
  const CoverPhotoSourceSheet({
    required this.onFilePicked,
    required this.onSizeError,
    super.key,
  });

  /// Called with the picked [XFile] when size validation passes.
  final void Function(XFile file) onFilePicked;

  /// Called when the picked file exceeds [kCoverPhotoMaxBytes].
  /// The sheet will have already dismissed itself; the caller should show
  /// an appropriate error so the user can re-open and re-pick.
  final VoidCallback onSizeError;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    // Dismiss the sheet before invoking the system picker so the sheet's
    // animation doesn't compete with the system UI.
    Navigator.of(context).pop();

    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return; // user cancelled

    // Validate size.
    final bytes = await File(file.path).length();
    if (bytes > kCoverPhotoMaxBytes) {
      onSizeError();
      return;
    }

    onFilePicked(file);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle: 36×4dp centred.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TribelyColors.paperBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // "Take photo" — camera source, first per spec.
          _SourceRow(
            icon: Icons.camera_alt,
            label: 'Take photo',
            onTap: () => _pick(context, ImageSource.camera),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            color: TribelyColors.paperBorderSubtle,
          ),
          // "Choose from library" — gallery source.
          _SourceRow(
            icon: Icons.photo_library,
            label: 'Choose from library',
            onTap: () => _pick(context, ImageSource.gallery),
          ),
          // Safe-area padding below the last row.
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private row widget
// ---------------------------------------------------------------------------

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: TribelyColors.paperInkPrimary),
            const SizedBox(width: 16),
            Text(
              label,
              style: TribelyType.bodyM(TribelyColors.paperInkPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public show-helper
// ---------------------------------------------------------------------------

/// Shows [CoverPhotoSourceSheet] as a drag-dismissible modal.
Future<void> showCoverPhotoSourceSheet(
  BuildContext context, {
  required void Function(XFile file) onFilePicked,
  required VoidCallback onSizeError,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => CoverPhotoSourceSheet(
      onFilePicked: onFilePicked,
      onSizeError: onSizeError,
    ),
  );
}
