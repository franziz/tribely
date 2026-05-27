import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../user_blocks/presentation/providers/user_block_providers.dart';
import '../../domain/entities/report_reason.dart';
import '../controllers/report_composer_controller.dart';
import '../providers/reports_providers.dart';
import '../state/report_composer_state.dart';
import '../string_assets/report_copy.dart';
import 'block_opt_in_sheet.dart';
import 'report_received_sheet.dart';
// One-widget cross-feature reference: reports/ → user_blocks/
// Sanctioned per Brief 2C: BlockOptInSheet needs to invoke BlockActionController
// when the user taps "Block [name]" after filing a report.

/// Bottom sheet for reporting a review.
///
/// Design spec:
///   - Drag handle: 32×4dp centred at top.
///   - Headline: "Report this review" (headline/22 semibold).
///   - Sub-copy: "Why are you reporting?" (bodyM/15, inkSecondary).
///   - Radio list with 7 [ReportReason] options (Designer-specified order).
///   - Disclaimer copy between picker and comment field (caption, inkSecondary).
///   - Optional multi-line comment field, ≤500 chars with counter.
///   - Submit button disabled until a reason is selected.
///   - On success: sheet dismisses, [ReportReceivedSheet] opens with the
///     SLA and Help Centre link. On Done/drag-dismiss the [BlockOptInSheet]
///     chains; on "Learn what happens next" the Help Centre article is
///     pushed instead and the block-opt-in chain is skipped.
///   - On failure: inline [BannerMessage] above the submit button.
///
/// Cross-feature import note: this widget is imported by
/// `reviews/presentation/widgets/review_row.dart` (Brief 2B spec). This is
/// a deliberate one-widget reference; it does NOT constitute a sanctioned
/// cross-feature exception under CLAUDE.md — it is a direct import documented
/// in place. Do NOT extend this pattern to other cross-feature widget imports
/// without EL/orchestrator sign-off.
///
/// Usage:
///   ```dart
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     builder: (_) => ReportReviewSheet(
///       reviewId: review.id,
///       reportedUserId: review.raterUserId,
///       reportedUserDisplayName: 'Alex',
///     ),
///   );
///   ```
class ReportReviewSheet extends ConsumerStatefulWidget {
  const ReportReviewSheet({
    required this.reviewId,
    required this.reportedUserId,
    required this.reportedUserDisplayName,
    super.key,
  });

  /// The ID of the review being reported — becomes [FileReportParams.targetId].
  final String reviewId;

  /// The user ID of the review author (used to drive the block opt-in sheet).
  final String reportedUserId;

  /// Display name of the user being reported (used in the block opt-in copy).
  final String reportedUserDisplayName;

  @override
  ConsumerState<ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends ConsumerState<ReportReviewSheet> {
  ReportReason? _selectedReason;
  final _commentController = TextEditingController();

  static const int _maxCommentLength = 500;
  static const int _warnThreshold = 450;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit(ReportComposerController controller) async {
    final reason = _selectedReason;
    if (reason == null) return;

    await controller.submit(
      targetType: 'review',
      targetId: widget.reviewId,
      reason: reason,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );
  }

  Future<void> _handleSuccess(BuildContext context) async {
    // Capture cross-feature dependencies BEFORE pop so the closures
    // hold stable references rather than [ref] (which becomes invalid
    // after the state is disposed by the pop below).
    final blockedUserId = widget.reportedUserId;
    final reportedUserDisplayName = widget.reportedUserDisplayName;
    final blockFn = ref.read(blockActionControllerProvider.notifier).block;

    // 1. Dismiss the report-review sheet.
    Navigator.of(context).pop();

    // 2. Show the persistent "Report received" sheet (TRI-164).
    //    Branches:
    //      - User taps Done OR drag-dismisses → chain into BlockOptInSheet.
    //      - User taps "Learn what happens next" → onLearnMore sets
    //        wentToArticle = true, pops the sheet, and pushes the article
    //        route. The chain is SKIPPED.
    var wentToArticle = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportReceivedSheet(
        onLearnMore: () {
          wentToArticle = true;
          Navigator.of(sheetContext).pop();
          context.push('/help/article/report-faq');
        },
      ),
    );

    // 3. Chain into block opt-in sheet, unless user navigated to article.
    if (wentToArticle || !context.mounted) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlockOptInSheet(
          reportedUserId: blockedUserId,
          reportedUserDisplayName: reportedUserDisplayName,
          onBlockTap: () => blockFn(blockedUserId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportComposerControllerProvider);
    final controller = ref.read(reportComposerControllerProvider.notifier);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    // Listen for Success to fire the post-submit flow.
    ref.listen<ReportComposerState>(reportComposerControllerProvider, (
      previous,
      next,
    ) {
      if (next is ReportComposerSuccess && context.mounted) {
        _handleSuccess(context);
      }
    });

    final isSubmitting = state is ReportComposerSubmitting;
    final canSubmit = _selectedReason != null && !isSubmitting;
    final failureMessage = state is ReportComposerFailure
        ? state.message
        : null;

    final commentLength = _commentController.text.length;
    final counterColor = commentLength >= _warnThreshold
        ? (dark ? TribelyColors.nightAccent : TribelyColors.paperAccent)
        : inkSecondary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Headline
                Text('Report this review', style: TribelyType.headline(ink)),
                const SizedBox(height: 6),

                // Sub-copy
                Text(
                  ReportCopy.reasonPickerLabel,
                  style: TribelyType.bodyM(inkSecondary),
                ),
                const SizedBox(height: 16),

                // Reason radio list
                ...ReportReason.values.map(
                  (reason) => _ReasonRadioTile(
                    reason: reason,
                    selected: _selectedReason == reason,
                    primaryColor: primary,
                    inkColor: ink,
                    onTap: () => setState(() => _selectedReason = reason),
                  ),
                ),

                const SizedBox(height: 16),

                // Disclaimer
                Text(
                  ReportCopy.disclaimer,
                  style: TribelyType.caption(inkSecondary),
                ),
                const SizedBox(height: 16),

                // Optional comment field
                StatefulBuilder(
                  builder: (context, setFieldState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _commentController,
                          maxLines: 4,
                          maxLength: _maxCommentLength,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null, // we draw our own counter
                          decoration: InputDecoration(
                            hintText: 'Add more details (optional)',
                            hintStyle: TribelyType.bodyM(inkSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: TribelyType.bodyM(ink),
                          onChanged: (_) {
                            setFieldState(() {});
                            setState(() {}); // rebuild counter color
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_commentController.text.length}/$_maxCommentLength',
                          style: TribelyType.caption(counterColor),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Failure banner
                if (failureMessage != null) ...[
                  BannerMessage(message: failureMessage),
                  const SizedBox(height: 12),
                ],

                // Submit button
                PrimaryButton(
                  label: 'Submit report',
                  onPressed: canSubmit ? () => _onSubmit(controller) : null,
                  state: isSubmitting
                      ? PrimaryButtonState.loading
                      : PrimaryButtonState.idle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal: radio tile for a single reason option
// ---------------------------------------------------------------------------

class _ReasonRadioTile extends StatelessWidget {
  const _ReasonRadioTile({
    required this.reason,
    required this.selected,
    required this.primaryColor,
    required this.inkColor,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final Color primaryColor;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Custom radio indicator — avoids deprecated Radio.groupValue API.
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? primaryColor
                          : inkColor.withValues(alpha: 0.4),
                      width: selected ? 6 : 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.displayString,
                style: TribelyType.bodyM(inkColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
