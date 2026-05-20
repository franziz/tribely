import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../controllers/block_action_controller.dart';
import '../providers/user_block_providers.dart';
import '../state/block_action_state.dart';
import '../string_assets/block_copy.dart';

/// Bottom sheet confirming a block action before executing it.
///
/// Shows the consequence bullet list from [BlockCopy.blockConsequenceBullets],
/// a "Block [name]" primary button, and a "Cancel" text button.
///
/// On confirm:
///   - Invokes [BlockActionController.block].
///   - On [BlockActionSuccess]: dismisses and invokes [onSuccess] so the
///     caller can show a SnackBar with [BlockCopy.blockSuccess].
///   - On [BlockActionFailure]: shows an inline error banner.
///
/// Usage:
///   ```dart
///   showModalBottomSheet<void>(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => BlockConfirmSheet(
///       userId: targetUserId,
///       displayName: 'Maya Tan',
///       onSuccess: () { /* show SnackBar */ },
///     ),
///   );
///   ```
class BlockConfirmSheet extends ConsumerWidget {
  const BlockConfirmSheet({
    required this.userId,
    required this.displayName,
    this.onSuccess,
    super.key,
  });

  /// The user ID to block.
  final String userId;

  /// Display name used in the button label ("Block [name]").
  final String displayName;

  /// Called after a successful block, once the sheet is dismissed.
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final actionState = ref.watch(blockActionControllerProvider);

    // On success: dismiss the sheet, then fire the caller's callback.
    ref.listen<BlockActionState>(blockActionControllerProvider, (prev, next) {
      if (next is BlockActionSuccess) {
        Navigator.of(context).pop();
        onSuccess?.call();
      }
    });

    final isBlocking = actionState is BlockActionBlocking;
    final failureMessage = actionState is BlockActionFailure
        ? actionState.message
        : null;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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

              // Title
              Text(
                BlockCopy.blockConfirmTitle,
                style: TribelyType.headline(ink),
              ),
              const SizedBox(height: 16),

              // Consequence bullets
              ...BlockCopy.blockConsequenceBullets.map(
                (bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: TribelyType.bodyM(inkSecondary)),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TribelyType.bodyM(inkSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Inline failure banner
              if (failureMessage != null) ...[
                const SizedBox(height: 12),
                BannerMessage(message: failureMessage),
              ],

              const SizedBox(height: 20),

              // Block button
              PrimaryButton(
                label: 'Block $displayName',
                state: isBlocking
                    ? PrimaryButtonState.loading
                    : PrimaryButtonState.idle,
                onPressed: isBlocking
                    ? null
                    : () => ref
                          .read(blockActionControllerProvider.notifier)
                          .block(userId),
              ),
              const SizedBox(height: 12),

              // Cancel text button
              Center(
                child: TextButton(
                  onPressed: isBlocking
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TribelyType.bodyM(ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
