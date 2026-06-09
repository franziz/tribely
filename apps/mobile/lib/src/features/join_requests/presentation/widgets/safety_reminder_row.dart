import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// A single safety-reminder row: an emoji glyph + body copy.
///
/// The entire row is wrapped in a [Semantics] node with
/// [Semantics.excludeSemantics] set to true so VoiceOver and TalkBack read
/// the [semanticsLabel] as one unit ("Location pin. Meet in a public spot")
/// rather than announcing the emoji and text separately.
///
/// Intended for use inside [SafetyReminderSheet] only (feature-scoped widget;
/// does NOT live in `core/widgets/` — one consumer this cycle).
///
/// Example:
/// ```dart
/// SafetyReminderRow(
///   emoji: SafetyReminderCopy.row1Emoji,
///   copy: SafetyReminderCopy.row1Copy,
///   semanticsLabel: SafetyReminderCopy.row1SemanticsLabel,
/// );
/// ```
class SafetyReminderRow extends StatelessWidget {
  const SafetyReminderRow({
    required this.emoji,
    required this.copy,
    required this.semanticsLabel,
    super.key,
  });

  /// The emoji glyph rendered as the leading character (e.g. `'📍'`).
  final String emoji;

  /// The body copy rendered next to the emoji.
  final String copy;

  /// The merged VoiceOver / TalkBack label for the entire row.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Provide a single merged label for VoiceOver/TalkBack so the emoji
      // and text are announced as one unit (matches `status_pill.dart` pattern).
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22, height: 1.2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              copy,
              style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
