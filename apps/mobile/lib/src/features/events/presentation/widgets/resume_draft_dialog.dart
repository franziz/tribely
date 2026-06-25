import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// Dialog shown when the create-event flow detects a previously saved draft.
///
/// The caller is responsible for showing this dialog via [showDialog] and
/// wiring [onResume] / [onDiscard] to the controller methods
/// [CreateEventController.acknowledgeResume] and
/// [CreateEventController.discardDraft] respectively. The dialog dismisses
/// itself after either action.
///
/// When [hasCoverPhoto] is true, a "Cover photo attached" indicator row is
/// rendered beneath the draft summary text and above the action buttons.
/// The indicator is informational only — no action is bound to it.
class ResumeDraftDialog extends StatelessWidget {
  const ResumeDraftDialog({
    required this.onResume,
    required this.onDiscard,
    this.hasCoverPhoto = false,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onDiscard;

  /// Whether the saved draft has a non-null [EventDraft.coverPhotoStorageKey].
  /// When true, a "Cover photo attached" indicator row is rendered.
  final bool hasCoverPhoto;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Resume your draft?', style: TribelyType.headline(ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have an unfinished event draft. Continue where you left off, or start fresh.',
            style: TribelyType.bodyM(inkSecondary),
          ),
          // Cover-photo indicator — rendered only when draft has a stored key.
          // The key is an object-path (not a URL), so a literal thumbnail is
          // not available without a separate presign round-trip. Per EL ruling:
          // show a text indicator instead.
          if (hasCoverPhoto) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.image_outlined, size: 16, color: inkSecondary),
                const SizedBox(width: 6),
                Text(
                  'Cover photo attached',
                  style: TribelyType.caption(inkSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDiscard();
          },
          style: TextButton.styleFrom(foregroundColor: accent),
          child: Text('Discard', style: TribelyType.button(accent)),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onResume();
          },
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Resume',
            style: TribelyType.button(
              dark
                  ? TribelyColors.nightSurface
                  : TribelyColors.paperSurfaceHigh,
            ),
          ),
        ),
      ],
    );
  }
}
