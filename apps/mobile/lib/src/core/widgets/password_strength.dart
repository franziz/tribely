import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

enum PasswordStrength { empty, weak, ok, strong }

PasswordStrength assessPassword(String value) {
  if (value.isEmpty) return PasswordStrength.empty;
  if (value.length < 8) return PasswordStrength.weak;
  final hasMixed =
      value.contains(RegExp(r'[A-Z]')) && value.contains(RegExp(r'[a-z]'));
  final hasNumOrSym =
      value.contains(RegExp(r'[0-9]')) || value.contains(RegExp(r'[^a-zA-Z0-9]'));
  if (value.length >= 12 && hasMixed && hasNumOrSym) return PasswordStrength.strong;
  return PasswordStrength.ok;
}

/// Three-pip strength indicator. Discrete states are easier to perceive than
/// a continuous bar and don't imply a misleading 0–100 score.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    required this.strength,
    super.key,
  });

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;
    final accent =
        dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final success =
        dark ? TribelyColors.nightSuccess : TribelyColors.paperSuccess;
    final dim = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final filled = switch (strength) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.ok => 2,
      PasswordStrength.strong => 3,
    };

    final label = switch (strength) {
      PasswordStrength.empty => '8+ characters.',
      PasswordStrength.weak => 'A bit short.',
      PasswordStrength.ok => 'Good.',
      PasswordStrength.strong => 'Strong.',
    };

    final color = switch (strength) {
      PasswordStrength.empty => inkSecondary,
      PasswordStrength.weak => accent,
      PasswordStrength.ok => inkSecondary,
      PasswordStrength.strong => success,
    };

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: i < filled ? color : dim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (i < 2) const SizedBox(width: 4),
        ],
        const SizedBox(width: 12),
        Text(label, style: TribelyType.caption(inkSecondary)),
      ],
    );
  }
}
