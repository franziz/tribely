import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/join_requests_providers.dart';
import '../state/request_to_join_state.dart';
import '../string_assets/safety_reminder_copy.dart';
import 'join_request_failure_copy.dart';
import 'safety_reminder_row.dart';

/// Modal bottom sheet shown once before the user's first-ever join request.
///
/// Design spec (safety-reminder-spec-tri34.md):
///   - Drag handle: 32×4dp centred, de-emphasised (paperBorderSubtle).
///   - No "Cancel" text-link — drag / back gesture is the implicit cancel.
///   - Header: "Quick check before you head out" (headline/22 semibold,
///     paperInkPrimary).
///   - Three [SafetyReminderRow]s: public spot / tell a friend / trust your gut.
///   - Single CTA: "Got it, send my request".
///   - CTA pending state: [PrimaryButtonState.loading]; sheet stays open.
///   - On success: auto-dismiss after 150ms.
///   - On failure: inline [BannerMessage] above CTA; sheet stays open.
///   - No amber/red; no forced-delay timer.
///
/// The CTA calls `requestToJoinControllerProvider(eventId).notifier
///   .submit(acknowledgedSafetyReminder: true)` and listens for
/// [RequestToJoinSubmitted] to auto-dismiss (mirrors [ConfirmJoinSheet]).
///
/// Usage:
/// ```dart
/// showSafetyReminderSheet(
///   context,
///   eventId: event.id,
/// );
/// ```
class SafetyReminderSheet extends ConsumerWidget {
  const SafetyReminderSheet({required this.eventId, super.key});

  /// The event the user is about to request to join.
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestToJoinControllerProvider(eventId));
    final controller = ref.read(
      requestToJoinControllerProvider(eventId).notifier,
    );

    // Auto-dismiss 150ms after a successful submission (mirrors ConfirmJoinSheet).
    ref.listen<RequestToJoinState>(requestToJoinControllerProvider(eventId), (
      previous,
      next,
    ) {
      if (next is RequestToJoinSubmitted) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
    });

    final isSubmitting = state is RequestToJoinSubmitting;
    final failure = state is RequestToJoinFailed ? state.failure : null;

    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle: 32×4dp centred, de-emphasised.
          Padding(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header.
                Text(
                  SafetyReminderCopy.header,
                  style: TribelyType.headline(TribelyColors.paperInkPrimary),
                ),
                const SizedBox(height: 20),
                // Reminder rows.
                const SafetyReminderRow(
                  emoji: SafetyReminderCopy.row1Emoji,
                  copy: SafetyReminderCopy.row1Copy,
                  semanticsLabel: SafetyReminderCopy.row1SemanticsLabel,
                ),
                const SizedBox(height: 14),
                const SafetyReminderRow(
                  emoji: SafetyReminderCopy.row2Emoji,
                  copy: SafetyReminderCopy.row2Copy,
                  semanticsLabel: SafetyReminderCopy.row2SemanticsLabel,
                ),
                const SizedBox(height: 14),
                const SafetyReminderRow(
                  emoji: SafetyReminderCopy.row3Emoji,
                  copy: SafetyReminderCopy.row3Copy,
                  semanticsLabel: SafetyReminderCopy.row3SemanticsLabel,
                ),
                const SizedBox(height: 24),
                // Error banner (shown only on failure).
                if (failure != null) ...[
                  BannerMessage(message: joinRequestFailureMessage(failure)),
                  const SizedBox(height: 16),
                ],
                // Primary CTA — no "Cancel" link per design spec.
                PrimaryButton(
                  label: SafetyReminderCopy.ctaLabel,
                  state: isSubmitting
                      ? PrimaryButtonState.loading
                      : PrimaryButtonState.idle,
                  onPressed: isSubmitting
                      ? null
                      : () =>
                            controller.submit(acknowledgedSafetyReminder: true),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [SafetyReminderSheet] as a drag-dismissible modal bottom sheet.
///
/// Mirrors [showConfirmJoinSheet]'s [showModalBottomSheet] configuration:
/// `isScrollControlled: true`, transparent background, drag + dismiss enabled.
Future<void> showSafetyReminderSheet(
  BuildContext context, {
  required String eventId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => SafetyReminderSheet(eventId: eventId),
  );
}
