import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/entities/join_request_with_requester.dart';
import '../string_assets/remove_attendee_copy.dart';

/// A single row in the host's "Attending" section on the event detail page.
///
/// Read-only — no Approve/Decline buttons. Layout mirrors [PendingRequestRow]
/// but without action buttons: avatar placeholder + display name.
///
/// Avatar image loading is deferred to TRI-23/36.
///
/// [onTapRequester]: optional callback invoked when the user taps the avatar or
/// display name. When null, the avatar/name area is not tappable.
///
/// [onTapRemove]: optional callback invoked when the host selects "Remove from
/// event" from the kebab action sheet. Only rendered when non-null AND the
/// join request has [JoinRequestStatus.approved] status.
class AttendingRequestRow extends StatelessWidget {
  const AttendingRequestRow({
    required this.item,
    this.onTapRequester,
    this.onTapRemove,
    super.key,
  });

  final JoinRequestWithRequester item;
  final VoidCallback? onTapRequester;

  /// When non-null and joiner status is [JoinRequestStatus.approved], renders a
  /// kebab IconButton aligned end. Tapping shows an action sheet; selecting
  /// "Remove from event" invokes this callback.
  final VoidCallback? onTapRemove;

  @override
  Widget build(BuildContext context) {
    final displayName = item.requester.displayName;
    final showKebab =
        onTapRemove != null &&
        item.joinRequest.status == JoinRequestStatus.approved;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: onTapRequester,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar placeholder — 40dp square, neutral fill.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TribelyColors.paperBorderSubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.person,
                size: 20,
                color: TribelyColors.paperInkSecondary,
              ),
            ),
            const SizedBox(width: 12),
            // Display name — fills remaining space.
            Expanded(
              child: Text(
                displayName,
                style: TribelyType.bodyM(
                  TribelyColors.paperInkPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Kebab menu — only for approved attendees when host provides callback.
            if (showKebab)
              IconButton(
                icon: const Icon(Icons.more_vert),
                color: TribelyColors.paperInkSecondary,
                onPressed: () => _showRemoveActionSheet(context),
                tooltip: 'More options',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveActionSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<_RowAction>(
      context: context,
      backgroundColor: TribelyColors.paperSurfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              title: Text(
                RemoveAttendeeCopy.actionSheetRemove,
                style: TribelyType.bodyM(TribelyColors.paperAccent),
              ),
              onTap: () => Navigator.of(sheetContext).pop(_RowAction.remove),
            ),
            ListTile(
              title: Text(
                RemoveAttendeeCopy.cancelLabel,
                style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
              ),
              onTap: () => Navigator.of(sheetContext).pop(null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == _RowAction.remove) {
      onTapRemove?.call();
    }
  }
}

enum _RowAction { remove }
