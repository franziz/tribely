import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/entities/join_request_with_event.dart';

/// A list row for the joiner's "Requested" tab.
///
/// Displays:
///   - Event thumbnail placeholder (48×48dp rounded square)
///   - Event title (bodyM semibold)
///   - SGT-formatted datetime: "Sat, 14 Jun · 7 PM"
///   - "Hosted by {name}" caption (if available)
///   - Right-aligned [StatusPill] for the request status
///   - When status == pending: a "Withdraw request" text link at bottom-right
///
/// [onWithdraw] is called when the user taps "Withdraw request" and confirms
/// the AlertDialog. The calling widget is responsible for showing the dialog
/// and calling onWithdraw only after confirmation.
class MyJoinRequestRow extends StatelessWidget {
  const MyJoinRequestRow({
    required this.item,
    this.onWithdraw,
    this.isWithdrawing = false,
    super.key,
  });

  final JoinRequestWithEvent item;

  /// Called when the user confirms a withdraw. Only shown for pending requests.
  final VoidCallback? onWithdraw;

  /// Whether a withdraw operation is in flight for this row.
  final bool isWithdrawing;

  // SGT: UTC+8
  static const _sgtOffset = Duration(hours: 8);

  @override
  Widget build(BuildContext context) {
    final startsAtSgt = item.event.startsAt.toUtc().add(_sgtOffset);
    final dateLabel = _formatDate(startsAtSgt);
    final pillState = _pillState(item.joinRequest.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event thumbnail placeholder.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: TribelyColors.paperInkSecondary,
                ),
              ),
              const SizedBox(width: 12),
              // Event info.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.event.title,
                      style: TribelyType.bodyM(
                        TribelyColors.paperInkPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TribelyType.caption(
                        TribelyColors.paperInkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status pill — right-aligned.
              StatusPill(state: pillState, semanticsContext: item.event.title),
            ],
          ),
          // Withdraw link — only shown for pending requests.
          if (item.joinRequest.status == JoinRequestStatus.pending) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: isWithdrawing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : GestureDetector(
                      onTap: onWithdraw,
                      child: Text(
                        'Withdraw request',
                        style: TribelyType.caption(
                          TribelyColors.paperPrimary,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = DateFormat('EEE, d MMM').format(dt);
    final time = DateFormat('h a').format(dt);
    return '$day · $time';
  }

  StatusPillState _pillState(JoinRequestStatus status) {
    return switch (status) {
      JoinRequestStatus.pending => StatusPillState.pending,
      JoinRequestStatus.approved => StatusPillState.approved,
      JoinRequestStatus.declined => StatusPillState.declined,
      JoinRequestStatus.withdrawn => StatusPillState.withdrawn,
      // TODO(TRI-63 Brief 7): replace with StatusPillState.removedByHost once
      // the pill state is added in the Brief 7 widget pass.
      JoinRequestStatus.removedByHost => StatusPillState.declined,
    };
  }
}
