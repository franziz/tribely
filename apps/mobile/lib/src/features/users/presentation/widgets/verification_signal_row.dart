import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// A single verification signal row for the verification settings page.
///
/// Anatomy:
///   leading icon (24dp) → 12dp gap → Column(name bodyM w600 + state caption
///   w500 with 2dp gap) → Spacer → trailing chip OR spinner OR nothing.
///
/// [isCheckingStatus] renders a 16dp [CircularProgressIndicator] in place of
/// the chip. [ctaLabel] null with [isCheckingStatus] false renders no trailing
/// element.
///
/// The full row is the tap target when [onCtaTap != null]. A 1dp divider is
/// rendered below the row unless [isLastRow] is true.
///
/// StatelessWidget — no Riverpod imports. Caller owns state derivation.
class VerificationSignalRow extends StatelessWidget {
  const VerificationSignalRow({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.stateLabel,
    required this.isLastRow,
    required this.isCheckingStatus,
    this.ctaLabel,
    this.onCtaTap,
    super.key,
  });

  /// Human-readable signal name, e.g. "Email", "Phone", "Selfie".
  final String label;

  /// Leading icon representing this verification signal.
  final IconData icon;

  /// Color for [icon].
  final Color iconColor;

  /// Human-readable current state, e.g. "Verified", "Pending", "Failed".
  final String stateLabel;

  /// When non-null, renders an outlined chip with this label as the CTA.
  /// When null and [isCheckingStatus] is false, no trailing element is shown.
  final String? ctaLabel;

  /// Callback fired (with a light haptic) when the row is tapped and
  /// [onCtaTap] is non-null. Entire row is the tap target.
  final VoidCallback? onCtaTap;

  /// When true, no divider is rendered below this row.
  final bool isLastRow;

  /// When true, renders a 16dp [CircularProgressIndicator] in place of the
  /// chip. Chip is absent regardless of [ctaLabel].
  final bool isCheckingStatus;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    // Semantics label — differ by whether there's an actionable CTA.
    final String semanticsLabel;
    if (onCtaTap != null && ctaLabel != null) {
      semanticsLabel = '$label — $stateLabel — $ctaLabel button';
    } else {
      semanticsLabel = '$label — $stateLabel';
    }

    Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Leading icon
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          // Signal name + state label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TribelyType.bodyM(
                    inkPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  stateLabel,
                  style: TribelyType.caption(
                    inkSecondary,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Trailing element
          _buildTrailing(
            dark: dark,
            primary: primary,
            inkSecondary: inkSecondary,
          ),
        ],
      ),
    );

    // Minimum 64dp row height.
    rowContent = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: rowContent,
    );

    // Wrap with tap target when onCtaTap is provided.
    if (onCtaTap != null) {
      rowContent = InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onCtaTap!();
        },
        child: rowContent,
      );
    }

    // Expose a single merged label over the row; suppress individual children.
    rowContent = Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: rowContent,
    );

    // Divider below (unless last row).
    if (isLastRow) return rowContent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rowContent,
        Divider(
          height: 1,
          thickness: 1,
          color: borderSubtle,
          indent: 0,
          endIndent: 0,
        ),
      ],
    );
  }

  Widget _buildTrailing({
    required bool dark,
    required Color primary,
    required Color inkSecondary,
  }) {
    if (isCheckingStatus) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: inkSecondary),
      );
    }

    if (ctaLabel == null) return const SizedBox.shrink();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: primary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Text(
        ctaLabel!,
        style: TribelyType.caption(
          primary,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
