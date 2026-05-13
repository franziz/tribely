import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/motion.dart';
import '../design/typography.dart';

/// Secondary (ghost/outline) CTA — transparent fill, theme-primary border and
/// label. Intended for "Maybe later" / decline-and-continue actions in
/// permission-rationale sheets and similar secondary flows.
///
/// API surface mirrors [PrimaryButton] so swapping between primary and
/// secondary at a call site is a one-line change.
///
/// Parameters:
/// - [label] — button text.
/// - [onPressed] — null disables the button (lower opacity, not border removal).
/// - [isLoading] — replaces label with a [CircularProgressIndicator] sized to
///   the label line-height; tap is suppressed while loading.
/// - [fullWidth] — when true (default) the button stretches to fill available
///   width, matching sheet-level full-bleed layout; set false for intrinsic
///   sizing in inline / row contexts.
///
/// Accessibility: minimum tap target is 48dp (§4) regardless of [fullWidth].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;

  // Opacity applied to the entire button when disabled or loading, per spec:
  // "lower opacity on label + border; do NOT collapse the border".
  static const double _disabledOpacity = 0.38;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    final bool isDisabled = onPressed == null;
    final bool isSuppressed = isDisabled || isLoading;

    // Border and label both derive from the theme primary — a single opacity
    // wrapper degrades them in lock-step without collapsing the border stroke.
    final borderSide = BorderSide(color: primary, width: 1.5);

    final child = AnimatedSwitcher(
      duration: TribelyMotion.short,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            )
          : Text(
              label,
              key: const ValueKey('idle'),
              style: TribelyType.button(primary),
            ),
    );

    final button = Opacity(
      opacity: isSuppressed ? _disabledOpacity : 1.0,
      child: OutlinedButton(
        onPressed: isSuppressed ? null : onPressed,
        style: OutlinedButton.styleFrom(
          // Transparent fill — ghost pattern.
          backgroundColor: Colors.transparent,
          foregroundColor: primary,
          // Disable the built-in disabled color override so the Opacity
          // wrapper is the sole visual signal; this keeps the border visible.
          disabledForegroundColor: primary,
          disabledBackgroundColor: Colors.transparent,
          side: borderSide,
          // Ensure ≥48dp tap target (§4 Accessibility).
          minimumSize: const Size(48, 48),
          // Match PrimaryButton's corner radius.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          // Tight padding keeps text centred and avoids unintended height jump
          // vs PrimaryButton's 56dp; consumers can wrap in a SizedBox if they
          // need a fixed height.
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          overlayColor: primary.withValues(alpha: 0.08),
        ),
        child: child,
      ),
    );

    if (!fullWidth) return button;

    return SizedBox(width: double.infinity, child: button);
  }
}
