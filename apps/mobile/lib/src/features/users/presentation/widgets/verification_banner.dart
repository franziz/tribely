import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../string_assets/verification_settings_copy.dart';

/// Status banner for the verification settings page.
///
/// Renders one of two states:
///   - Fully verified: success-token background with a checkmark icon.
///   - Partial / not started / pending / failed: neutral-surface background
///     with a lock icon prompting the user to complete verification.
///
/// StatelessWidget — caller owns the boolean derivation from domain state.
/// No Riverpod imports.
class VerificationBanner extends StatelessWidget {
  const VerificationBanner({required this.isFullyVerified, super.key});

  /// Whether all three verification signals (email, phone, selfie) are
  /// approved. When true, renders the success state; when false, renders the
  /// neutral prompt state.
  final bool isFullyVerified;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color background;
    final Color iconAndTextColor;
    final IconData icon;
    final String copy;

    if (isFullyVerified) {
      background = dark
          ? TribelyColors.nightSuccessSoft
          : TribelyColors.paperSuccessSoft;
      iconAndTextColor = dark
          ? TribelyColors.nightSuccess
          : TribelyColors.paperSuccess;
      icon = Icons.verified;
      copy = kVerificationBannerFullyVerified;
    } else {
      background = dark
          ? TribelyColors.nightSurfaceHigh
          : TribelyColors.paperSurfaceHigh;
      iconAndTextColor = dark
          ? TribelyColors.nightInkSecondary
          : TribelyColors.paperInkSecondary;
      icon = Icons.lock_outline;
      copy = kVerificationBannerPartial;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconAndTextColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(copy, style: TribelyType.bodyM(iconAndTextColor)),
          ),
        ],
      ),
    );
  }
}
