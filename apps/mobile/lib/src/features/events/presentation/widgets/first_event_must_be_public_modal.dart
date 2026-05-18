import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/create_event_state.dart';

/// Modal shown when the server rejects a create-event call with
/// `FIRST_EVENT_MUST_BE_PUBLIC` (422). Explains why the event was rejected and
/// offers two recovery paths.
///
/// Always returns a [FirstEventMustBePublicModalResult] — [barrierDismissible]
/// is false so the user cannot dismiss without making a choice.
///
/// Usage:
/// ```dart
/// final result = await FirstEventMustBePublicModal.show(context);
/// controller.onPublishRejectionAcknowledged(result);
/// ```
class FirstEventMustBePublicModal extends StatelessWidget {
  const FirstEventMustBePublicModal({super.key});

  /// Shows the modal and returns the user's choice.
  ///
  /// Guaranteed to return a non-null [FirstEventMustBePublicModalResult]:
  /// [barrierDismissible] is false, and both CTAs pop with an explicit value.
  static Future<FirstEventMustBePublicModalResult> show(
    BuildContext context,
  ) async {
    final result = await showDialog<FirstEventMustBePublicModalResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstEventMustBePublicModal(),
    );
    // Fallback: if the dialog is somehow dismissed without a result (e.g. system
    // back on Android when barrierDismissible=false is not honoured), treat as
    // cancel so the host can retry without data loss.
    return result ?? FirstEventMustBePublicModalResult.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'First event must be public',
        style: TribelyType.headline(ink),
      ),
      content: Text(
        'Tribely events meet in public spots so others feel safe joining. '
        'Pick a cafe, park, or hawker centre to publish your first event.',
        style: TribelyType.bodyM(inkSecondary),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        PrimaryButton(
          label: 'Pick a public place',
          onPressed: () => Navigator.of(
            context,
          ).pop(FirstEventMustBePublicModalResult.pickPublicPlace),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(FirstEventMustBePublicModalResult.cancel),
          style: TextButton.styleFrom(foregroundColor: accent),
          child: Text('Cancel', style: TribelyType.button(accent)),
        ),
      ],
    );
  }
}
