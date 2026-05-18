import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Controls the visual treatment of [BannerMessage].
///
/// - [BannerVariant.accent] — soft-coral error/warning banner (default).
///   Existing callers that omit [BannerMessage.variant] continue to render
///   exactly as before.
/// - [BannerVariant.neutral] — muted informational banner using the surface
///   and border-subtle tokens; text in inkSecondary.
enum BannerVariant { accent, neutral }

/// Soft-coral banner used for form-level errors and recovery prompts.
/// Sits ABOVE the form, not as an overlay — recovery information should be
/// in flow, not blocking.
///
/// Pass [variant] to switch between the accent (default) and neutral styles.
class BannerMessage extends StatelessWidget {
  const BannerMessage({
    required this.message,
    this.action,
    this.onDismiss,
    this.variant = BannerVariant.accent,
    super.key,
  });

  final String message;
  final BannerAction? action;
  final VoidCallback? onDismiss;
  final BannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor;
    final Color leftBorderColor;
    final Color textColor;
    final Color actionColor;

    switch (variant) {
      case BannerVariant.accent:
        leftBorderColor = dark
            ? TribelyColors.nightAccent
            : TribelyColors.paperAccent;
        backgroundColor = dark
            ? TribelyColors.nightAccentSoft
            : TribelyColors.paperAccentSoft;
        textColor = dark
            ? TribelyColors.nightInkPrimary
            : TribelyColors.paperInkPrimary;
        actionColor = leftBorderColor;
      case BannerVariant.neutral:
        backgroundColor = dark
            ? TribelyColors.nightSurfaceHigh
            : TribelyColors.paperSurfaceHigh;
        leftBorderColor = dark
            ? TribelyColors.nightBorderSubtle
            : TribelyColors.paperBorderSubtle;
        textColor = dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary;
        actionColor = textColor;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: leftBorderColor, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TribelyType.bodyM(
                    textColor,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                if (action != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: action!.onTap,
                    child: Text(
                      action!.label,
                      style: TribelyType.bodyM(actionColor).copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textColor),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

class BannerAction {
  const BannerAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}
