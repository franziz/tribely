import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Inline hint displayed below a disabled CTA button to explain the blocker.
///
/// Per TRI-57 contract: disabled CTAs must explain their blocker inline.
///
/// API:
///   - [text] — the full hint string (always displayed).
///   - [accentSpan] — optional substring of [text] to render in [paperAccent]
///     / [nightAccent]. The rest of [text] renders in [paperInkSecondary] /
///     [nightInkSecondary]. When null, the whole string renders in secondary.
///   - [onTap] — optional tap handler. When provided, wraps in a 44dp-minimum
///     [InkWell]. When null, non-interactive.
///
/// This widget is a PRIMITIVE — it carries no domain knowledge, no enum
/// references, no feature coupling. Copy is always provided by the caller.
class DisabledCTAHint extends StatelessWidget {
  const DisabledCTAHint({
    required this.text,
    this.accentSpan,
    this.onTap,
    super.key,
  });

  /// The full hint string.
  final String text;

  /// Optional substring of [text] to render in the accent color.
  /// Must be an exact substring of [text].
  final String? accentSpan;

  /// Optional tap handler. Wraps in a 44dp-minimum InkWell when provided.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final textWidget = _buildText(secondary, accent);

    if (onTap == null) {
      return _padded(textWidget);
    }

    return InkWell(
      onTap: onTap,
      splashColor: accent.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: _padded(textWidget),
      ),
    );
  }

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: child);

  Widget _buildText(Color secondary, Color accent) {
    final span = accentSpan;
    if (span == null || span.isEmpty) {
      return Text(
        text,
        style: TribelyType.caption(secondary),
        textAlign: TextAlign.center,
      );
    }

    // Split on the first occurrence of accentSpan.
    final idx = text.indexOf(span);
    final before = text.substring(0, idx);
    final after = text.substring(idx + span.length);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TribelyType.caption(secondary),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(text: span, style: TribelyType.caption(accent)),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}
