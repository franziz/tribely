import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// Compact two-option bottom sheet for avatar image source selection.
///
/// Design spec:
///   - Drag handle: 36×4dp centred at top.
///   - "Take photo" (camera) row — [Icons.camera_alt], listed first.
///   - "Choose from library" row — [Icons.photo_library], listed second.
///   - Tap-outside / drag dismiss is enabled (no Cancel row per spec).
///   - No internal Riverpod/state — purely presentational.
///
/// Usage:
///   ```dart
///   showAvatarSourceSheet(
///     context,
///     onCamera: () { /* invoke AvatarPickerDatasource.pick(camera) */ },
///     onLibrary: () { /* invoke AvatarPickerDatasource.pick(library) */ },
///   );
///   ```
///
/// The sheet dismisses itself on row tap (via [Navigator.of(context).pop])
/// so the caller's callback fires after the sheet is gone.
class AvatarSourceSheet extends StatelessWidget {
  const AvatarSourceSheet({
    required this.onCamera,
    required this.onLibrary,
    super.key,
  });

  /// Called when the user taps "Take photo". Sheet dismisses before invoking.
  final VoidCallback onCamera;

  /// Called when the user taps "Choose from library". Sheet dismisses before
  /// invoking.
  final VoidCallback onLibrary;

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
            onTap: () {
              Navigator.of(context).pop();
              onCamera();
            },
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
            onTap: () {
              Navigator.of(context).pop();
              onLibrary();
            },
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

/// Shows [AvatarSourceSheet] as a drag-dismissible modal.
///
/// The sheet is dismissed on tap-outside (default) or by the user tapping
/// a row. No Cancel row is rendered — the spec deliberately omits it.
Future<void> showAvatarSourceSheet(
  BuildContext context, {
  required VoidCallback onCamera,
  required VoidCallback onLibrary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => AvatarSourceSheet(onCamera: onCamera, onLibrary: onLibrary),
  );
}
