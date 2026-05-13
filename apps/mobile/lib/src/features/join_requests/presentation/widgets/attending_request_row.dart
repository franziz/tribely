import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/join_request_with_requester.dart';

/// A single row in the host's "Attending" section on the event detail page.
///
/// Read-only — no Approve/Decline buttons. Layout mirrors [PendingRequestRow]
/// but without action buttons: avatar placeholder + display name.
///
/// Avatar image loading is deferred to TRI-23/36.
///
/// [onTapRequester]: optional callback invoked when the user taps the avatar or
/// display name. When null, the avatar/name area is not tappable.
class AttendingRequestRow extends StatelessWidget {
  const AttendingRequestRow({
    required this.item,
    this.onTapRequester,
    super.key,
  });

  final JoinRequestWithRequester item;
  final VoidCallback? onTapRequester;

  @override
  Widget build(BuildContext context) {
    final displayName = item.requester.displayName;

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
          ],
        ),
      ),
    );
  }
}
