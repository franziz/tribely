import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/join_requests_providers.dart';
import '../state/request_to_join_state.dart';

/// 50% modal bottom sheet for confirming a join request.
///
/// Design spec:
///   - Drag handle: 32×4dp centred at top.
///   - Host avatar placeholder: 48dp circle.
///   - Headline: "Send a request to join [HostName]'s [EventTitle]?"
///     TribelyType.headline/22 semibold, wrapping.
///   - Body: "They'll get a notification and can approve or decline."
///     bodyM/15, paperInkSecondary.
///   - "Happening now" hint (conditional — see [startsAt] / [endsAt]):
///     Shown when the event is currently underway (past startsAt+15min, before
///     endsAt). Renders as a 1dp divider / sub-copy / 1dp divider block between
///     the body copy and the primary CTA.
///   - PrimaryButton("Send request") — loading state during submit.
///   - Text-only "Cancel" below the button.
///   - On success: sheet auto-dismisses after 150ms.
///   - On failure: BannerMessage above button; sheet stays open.
///
/// Usage:
///   ```dart
///   showConfirmJoinSheet(
///     context,
///     eventId: event.id,
///     hostName: event.hostDisplayName ?? 'Host',
///     eventTitle: event.title,
///     startsAt: event.startsAt,
///     endsAt: event.endsAt,
///   );
///   ```
class ConfirmJoinSheet extends ConsumerWidget {
  const ConfirmJoinSheet({
    required this.eventId,
    required this.hostName,
    required this.eventTitle,
    required this.startsAt,
    required this.endsAt,
    this.now,
    super.key,
  });

  final String eventId;
  final String hostName;
  final String eventTitle;

  /// Event start time. Used to compute the "happening now" hint trigger.
  final DateTime startsAt;

  /// Event end time. Used to compute the "happening now" hint trigger.
  final DateTime endsAt;

  /// Override for the current time. Defaults to [DateTime.now] when null.
  /// Exposed for widget testing only — production callers must not set this.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestToJoinControllerProvider(eventId));
    final controller = ref.read(
      requestToJoinControllerProvider(eventId).notifier,
    );

    // Auto-dismiss 150ms after a successful submission.
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

    final effectiveNow = now ?? DateTime.now();
    final showHappeningNowHint =
        effectiveNow.isAfter(startsAt.add(const Duration(minutes: 15))) &&
        effectiveNow.isBefore(endsAt);

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
          // Drag handle: 32×4dp centred.
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
                // Host avatar placeholder: 48dp circle.
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: TribelyColors.paperBorderSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 26,
                    color: TribelyColors.paperInkSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Headline.
                Text(
                  "Send a request to join $hostName's $eventTitle?",
                  style: TribelyType.headline(TribelyColors.paperInkPrimary),
                ),
                const SizedBox(height: 8),
                // Body copy.
                Text(
                  "They'll get a notification and can approve or decline.",
                  style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
                ),
                // "Happening now" hint — rendered only when the event is
                // currently underway (past startsAt+15min, before endsAt).
                if (showHappeningNowHint) ...[
                  const SizedBox(height: 16),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: TribelyColors.paperBorderSubtle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$hostName might be on the go — they'll respond when they can.",
                    style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: TribelyColors.paperBorderSubtle,
                  ),
                ],
                const SizedBox(height: 24),
                // Error banner (shown only on failure).
                if (failure != null) ...[
                  BannerMessage(message: _failureMessage(failure)),
                  const SizedBox(height: 16),
                ],
                // Submit button.
                PrimaryButton(
                  label: 'Send request',
                  state: isSubmitting
                      ? PrimaryButtonState.loading
                      : PrimaryButtonState.idle,
                  onPressed: isSubmitting ? null : controller.submit,
                ),
                const SizedBox(height: 12),
                // Cancel text link.
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Cancel',
                      style: TribelyType.button(
                        TribelyColors.paperInkSecondary,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _failureMessage(Failure failure) {
    return switch (failure) {
      EmailNotVerifiedFailure() =>
        'Please verify your email before requesting to join.',
      CapacityFullFailure() => 'This event is full.',
      ConflictFailure(:final subcode) when subcode == 'ALREADY_APPROVED' =>
        'You have already been approved for this event.',
      ConflictFailure() => 'You already have a pending request for this event.',
      NetworkFailure() => 'No connection. Check your network and try again.',
      _ => failure.message,
    };
  }
}

/// Shows [ConfirmJoinSheet] as a 50%-height drag-dismissible modal.
Future<void> showConfirmJoinSheet(
  BuildContext context, {
  required String eventId,
  required String hostName,
  required String eventTitle,
  required DateTime startsAt,
  required DateTime endsAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => ConfirmJoinSheet(
      eventId: eventId,
      hostName: hostName,
      eventTitle: eventTitle,
      startsAt: startsAt,
      endsAt: endsAt,
    ),
  );
}
