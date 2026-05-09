import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// "show / hide" text toggle — NOT an eye icon. Reasons:
///   - announces clearly to screen readers
///   - translates cleanly (eye-meaning isn't universal)
///   - bigger tap target than a 24dp icon
class ShowPasswordToggle extends StatelessWidget {
  const ShowPasswordToggle({
    required this.visible,
    required this.onToggle,
    super.key,
  });

  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Semantics(
      button: true,
      label: visible ? 'Hide password' : 'Show password',
      child: TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          visible ? 'hide' : 'show',
          style: TribelyType.caption(inkSecondary),
        ),
      ),
    );
  }
}
