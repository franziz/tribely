import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// A read-only pill badge indicating that a user is verified.
///
/// Spec: border-radius 99 (full pill), 20dp visual height, 8dp horizontal
/// padding, 14dp verified icon, caption text. Non-interactive — no touch
/// target.
///
/// Accessibility: exposes a Semantics label of "Verified" when
/// [isVerified] is true. Contributes nothing to the semantics tree when
/// [isVerified] is false.
class VerifiedPill extends StatelessWidget {
  const VerifiedPill({required this.isVerified, super.key});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? TribelyColors.nightSuccess : TribelyColors.paperSuccess;
    final bg =
        dark ? TribelyColors.nightSuccessSoft : TribelyColors.paperSuccessSoft;

    return Semantics(
      label: 'Verified',
      excludeSemantics: true,
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 14, color: fg),
            const SizedBox(width: 4),
            Text('Verified', style: TribelyType.caption(fg)),
          ],
        ),
      ),
    );
  }
}
