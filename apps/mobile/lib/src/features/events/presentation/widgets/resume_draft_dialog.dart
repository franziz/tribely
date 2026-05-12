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
class ResumeDraftDialog extends StatelessWidget {
  const ResumeDraftDialog({
    required this.onResume,
    required this.onDiscard,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    final inkSecondary = dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;
    final primary = dark ? TribelyColors.nightPrimary : TribelyColors.paperPrimary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final surface = dark ? TribelyColors.nightSurfaceHigh : TribelyColors.paperSurfaceHigh;

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Resume your draft?',
        style: TribelyType.headline(ink),
      ),
      content: Text(
        'You have an unfinished event draft. Continue where you left off, or start fresh.',
        style: TribelyType.bodyM(inkSecondary),
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
              dark ? TribelyColors.nightSurface : TribelyColors.paperSurfaceHigh,
            ),
          ),
        ),
      ],
    );
  }
}
