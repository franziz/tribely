import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Soft-coral banner used for form-level errors and recovery prompts.
/// Sits ABOVE the form, not as an overlay — recovery information should be
/// in flow, not blocking.
class BannerMessage extends StatelessWidget {
  const BannerMessage({
    required this.message,
    this.action,
    this.onDismiss,
    super.key,
  });

  final String message;
  final BannerAction? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;

    return Container(
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
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
                    ink,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                if (action != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: action!.onTap,
                    child: Text(
                      action!.label,
                      style: TribelyType.bodyM(accent).copyWith(
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
              icon: Icon(Icons.close, size: 18, color: ink),
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
