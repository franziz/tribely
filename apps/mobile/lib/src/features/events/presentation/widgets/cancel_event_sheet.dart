import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/destructive_primary_button.dart';
import '../../../../core/widgets/primary_button.dart' show PrimaryButtonState;
import '../controllers/cancel_event_controller.dart';
import '../state/cancel_event_state.dart';
import '../string_assets/cancel_event_copy.dart';

/// Modal bottom sheet that asks the host to confirm cancelling an event.
///
/// Design spec mirrors [DeclineReasonSheet] / [RemoveAttendeeSheet] structure:
///   - Drag handle: 32×4dp centred.
///   - Headline: "Cancel this event?" (headline/22 semibold).
///   - Body copy: PM-approved verbatim from [CancelEventCopy.body].
///   - [DestructivePrimaryButton] "Yes, cancel event" — loading state while
///     in-flight; sheet stays open until server confirms (no optimistic close).
///   - [TextButton] "Keep event" — dismisses immediately.
///   - On failure: inline [BannerMessage] above the action buttons; sheet stays
///     open so the user can retry.
///   - On [CancelEventSuccess]: sheet auto-closes; the caller's
///     [onSuccess] callback is invoked to invalidate providers and refresh the
///     detail page.
///
/// Navigation is NOT performed here — responsibility lies with the event-detail
/// page which provided the [onSuccess] callback.
///
/// No reason text input — per technical non-goals.
class CancelEventSheet extends ConsumerWidget {
  const CancelEventSheet({
    required this.eventId,
    required this.onSuccess,
    super.key,
  });

  final String eventId;

  /// Called immediately after [CancelEventSuccess] is detected so the parent
  /// can invalidate providers and update the page state.
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelState = ref.watch(cancelEventControllerProvider(eventId));
    final controller = ref.read(
      cancelEventControllerProvider(eventId).notifier,
    );

    // On success: close the sheet and notify the caller.
    ref.listen<CancelEventState>(cancelEventControllerProvider(eventId), (
      prev,
      next,
    ) {
      if (next is CancelEventSuccess) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        onSuccess();
      }
    });

    final isSubmitting = cancelState is CancelEventSubmitting;
    final errorMessage = switch (cancelState) {
      CancelEventFailed() => CancelEventCopy.errorMessage,
      _ => null,
    };

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TribelyColors.paperBorderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 12 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Headline.
                  Text(
                    CancelEventCopy.headline,
                    style: TribelyType.headline(TribelyColors.paperInkPrimary),
                  ),
                  const SizedBox(height: 12),
                  // Body copy.
                  Text(
                    CancelEventCopy.body,
                    style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
                  ),
                  const SizedBox(height: 24),
                  // Inline error banner — shown on failure; cleared on retry.
                  if (errorMessage != null) ...[
                    BannerMessage(message: errorMessage),
                    const SizedBox(height: 16),
                  ],
                  // Destructive confirm button.
                  DestructivePrimaryButton(
                    label: CancelEventCopy.submitLabel,
                    state: isSubmitting
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                    onPressed: isSubmitting ? null : controller.cancel,
                  ),
                  const SizedBox(height: 12),
                  // Dismiss button.
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        CancelEventCopy.dismissLabel,
                        style: TribelyType.button(
                          TribelyColors.paperInkSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [CancelEventSheet] as a dismissible modal bottom sheet.
///
/// The sheet is intentionally dismissible (no text input to protect), so
/// [isDismissible] defaults to true. The host can tap outside or swipe down
/// to cancel without submitting.
///
/// [onSuccess]: invoked after server confirms the cancellation so the caller
/// can invalidate providers and update the page.
Future<void> showCancelEventSheet(
  BuildContext context, {
  required String eventId,
  required VoidCallback onSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CancelEventSheet(eventId: eventId, onSuccess: onSuccess),
  );
}
