import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../string_assets/block_copy.dart';

/// Anonymized placeholder row for past-event attendee lists where the
/// counterparty has been blocked (by the viewer or vice versa).
///
/// Renders a grey circle avatar (no initials, no photo) and an italic
/// "Former participant" caption. NOT tappable — there is no profile to navigate
/// to. Does NOT show "you blocked them" or any direction-of-block signal.
///
/// Usage — replace the normal attendee row with this widget when the attendee's
/// blocked status is detected:
///   ```dart
///   isBlocked
///     ? const FormerParticipantRow()
///     : NormalAttendeeRow(attendee: attendee)
///   ```
class FormerParticipantRow extends StatelessWidget {
  const FormerParticipantRow({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final avatarBg = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Grey placeholder circle — no initials, no photo
          CircleAvatar(radius: 20, backgroundColor: avatarBg),
          const SizedBox(width: 12),

          // "Former participant" italic caption
          Expanded(
            child: Text(
              BlockCopy.formerParticipant,
              style: TribelyType.italicCaption(inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
