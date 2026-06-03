import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/safety_reminder_copy.dart';
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
/// **Brief G seam:** The CTA's submit wiring is intentionally left as an
/// [onAcknowledge] callback parameter. Brief G will replace the stub callback
/// with controller wiring without restructuring this widget.
///
/// Usage:
/// ```dart
/// showSafetyReminderSheet(
///   context,
///   eventId: event.id,
/// );
/// ```
class SafetyReminderSheet extends ConsumerStatefulWidget {
  const SafetyReminderSheet({
    required this.eventId,
    required this.onAcknowledge,
    super.key,
  });

  /// The event the user is about to request to join.
  final String eventId;

  /// Called when the user taps the CTA.
  ///
  /// Returns null on success; returns a non-null error message on failure.
  ///
  /// TODO(Brief G): replace with controller wiring from
  ///   `requestToJoinControllerProvider(eventId)`.
  final Future<String?> Function() onAcknowledge;

  @override
  ConsumerState<SafetyReminderSheet> createState() =>
      _SafetyReminderSheetState();
}

class _SafetyReminderSheetState extends ConsumerState<SafetyReminderSheet> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleAcknowledge() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await widget.onAcknowledge();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
    } else {
      // Success — auto-dismiss after 150ms (mirrors ConfirmJoinSheet).
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                SafetyReminderRow(
                  emoji: SafetyReminderCopy.row1Emoji,
                  copy: SafetyReminderCopy.row1Copy,
                  semanticsLabel: SafetyReminderCopy.row1SemanticsLabel,
                ),
                const SizedBox(height: 14),
                SafetyReminderRow(
                  emoji: SafetyReminderCopy.row2Emoji,
                  copy: SafetyReminderCopy.row2Copy,
                  semanticsLabel: SafetyReminderCopy.row2SemanticsLabel,
                ),
                const SizedBox(height: 14),
                SafetyReminderRow(
                  emoji: SafetyReminderCopy.row3Emoji,
                  copy: SafetyReminderCopy.row3Copy,
                  semanticsLabel: SafetyReminderCopy.row3SemanticsLabel,
                ),
                const SizedBox(height: 24),
                // Error banner (shown only on failure).
                if (_errorMessage != null) ...[
                  BannerMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                // Primary CTA — no "Cancel" link per design spec.
                PrimaryButton(
                  label: SafetyReminderCopy.ctaLabel,
                  state: _isSubmitting
                      ? PrimaryButtonState.loading
                      : PrimaryButtonState.idle,
                  onPressed: _isSubmitting ? null : _handleAcknowledge,
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
///
/// [onAcknowledge] is the CTA callback — Brief G will wire this to the
/// `requestToJoinControllerProvider(eventId)`.
Future<void> showSafetyReminderSheet(
  BuildContext context, {
  required String eventId,
  required Future<String?> Function() onAcknowledge,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => SafetyReminderSheet(
      eventId: eventId,
      onAcknowledge: onAcknowledge,
    ),
  );
}
