import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/report_copy.dart';

/// Bottom sheet shown after a successful report submission, offering the
/// user an optional block action.
///
/// Two CTAs:
///   - "Block [name]" (PrimaryButton, paperPrimary colour — not accent).
///   - "Not now" (TextButton) — dismisses the sheet.
///
/// On "Block [name]" tap: [onBlockTap] is called. The caller is responsible
/// for invoking the block use case (Brief 2C).
///
/// Brief 2C integration:
///   If Brief 2C's BlockUserUseCase has landed, pass a real callback.
///   If not yet landed, the caller passes a no-op and a TODO comment guides
///   the wiring (see review_row.dart).
///
/// Usage:
///   ```dart
///   showModalBottomSheet<void>(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => BlockOptInSheet(
///       reportedUserId: userId,
///       reportedUserDisplayName: 'Alex',
///       onBlockTap: () { /* call BlockUserUseCase */ },
///     ),
///   );
///   ```
class BlockOptInSheet extends StatelessWidget {
  const BlockOptInSheet({
    required this.reportedUserId,
    required this.reportedUserDisplayName,
    this.onBlockTap,
    super.key,
  });

  /// The user ID of the person to block. Passed through to [onBlockTap].
  final String reportedUserId;

  /// Display name shown in the block button label ("Block [name]").
  final String reportedUserDisplayName;

  /// Called when the user taps "Block [name]".
  ///
  /// If Brief 2C's BlockUserUseCase has not yet landed, pass null or a no-op.
  // TODO: import BlockUserUseCase from user_blocks/ when Brief 2C lands
  //   and wire: onBlockTap: () => ref.read(blockUserUseCaseProvider)(BlockUserParams(userId: reportedUserId))
  final VoidCallback? onBlockTap;

  @override
  Widget build(BuildContext context) {
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
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // Prompt
              Text(
                ReportCopy.blockOptInPrompt,
                style: TribelyType.bodyM(inkSecondary),
              ),
              const SizedBox(height: 24),

              // Block button (paperPrimary, NOT accent)
              PrimaryButton(
                label: 'Block $reportedUserDisplayName',
                onPressed: () {
                  Navigator.of(context).pop();
                  onBlockTap?.call();
                },
              ),
              const SizedBox(height: 12),

              // "Not now" text button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Not now', style: TribelyType.bodyM(ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
