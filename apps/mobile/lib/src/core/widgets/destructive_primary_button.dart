/// LEGAL-COMPLIANCE: WCAG AA contrast on active-state coral background (3.5:1)
/// depends on the label rendering at 16sp semibold (qualifies as "large text"
/// under WCAG 2.1 SC 1.4.3). Do NOT lower font weight or size below
/// TribelyType.button.
library;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/motion.dart';
import '../design/typography.dart';
import 'loading_dots.dart';
import 'primary_button.dart' show PrimaryButtonState;

/// Destructive variant of [PrimaryButton] for irreversible actions.
///
/// Shares all structural and motion properties with [PrimaryButton] but
/// overrides the active background to `paperAccent`/`nightAccent` (ember coral)
/// — semantically correct for permanent destructive CTAs where teal/brass would
/// mislead the user into treating the action as positive.
///
/// [PrimaryButtonState.success] is intentionally unsupported: destructive flows
/// navigate away on success rather than showing a success state in-place.
///
/// Usage:
/// ```dart
/// DestructivePrimaryButton(
///   label: 'Permanently delete account',
///   onPressed: isEnabled ? _onDelete : null,
///   state: _buttonState,
/// )
/// ```
class DestructivePrimaryButton extends StatelessWidget {
  const DestructivePrimaryButton({
    required this.label,
    required this.onPressed,
    this.state = PrimaryButtonState.idle,
    super.key,
  }) : assert(
         state != PrimaryButtonState.success,
         'DestructivePrimaryButton does not support success state — '
         'destructive flows navigate away on success.',
       );

  final String label;
  final VoidCallback? onPressed; // null = disabled
  final PrimaryButtonState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;
    final activeFg = dark
        ? TribelyColors.nightSurface
        : TribelyColors.paperSurfaceHigh;
    final disabledBg = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final disabledFg = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    final disabled = onPressed == null && state == PrimaryButtonState.idle;
    final bg = disabled ? disabledBg : activeBg;
    final fg = disabled ? disabledFg : activeFg;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: state == PrimaryButtonState.idle ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: fg.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedSwitcher(
              duration: TribelyMotion.short,
              child: switch (state) {
                PrimaryButtonState.idle => Text(
                  label,
                  key: const ValueKey('idle'),
                  style: TribelyType.button(fg),
                ),
                PrimaryButtonState.loading => LoadingDots(
                  key: const ValueKey('loading'),
                  color: fg,
                ),
                PrimaryButtonState.success => throw AssertionError(
                  'DestructivePrimaryButton does not support success state.',
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
