import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// The states a join-request-style status pill can represent.
///
/// Intentionally feature-agnostic — no dependency on any join-request domain
/// type. Call-sites map their own enums to [StatusPillState].
enum StatusPillState { pending, approved, declined, withdrawn, removedByHost }

/// A read-only pill badge that communicates request status via colour and text.
///
/// Spec: border-radius 99 (full pill), 28dp visual height, 48dp touch target,
/// 12dp horizontal padding, 6dp leading dot, caption/13 medium weight text.
///
/// Accessibility: the widget exposes a Semantics label of the form
/// "Request status: [State]". When [semanticsContext] is supplied the label
/// becomes "Request status: [State], for [semanticsContext]", allowing
/// call-sites to add event-name context without baking it into the widget.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.state, this.semanticsContext, super.key});

  final StatusPillState state;

  /// Optional context appended to the semantics label.
  /// When non-null, label = "Request status: [State], for [semanticsContext]".
  final String? semanticsContext;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = _background(dark);
    final fg = _foreground(dark);
    final label = _label();
    final semanticsLabel = semanticsContext != null
        ? 'Request status: $label, for $semanticsContext'
        : 'Request status: $label';

    return Semantics(
      label: semanticsLabel,
      // Exclude child text from the default traversal — the explicit label
      // above is the canonical a11y description.
      excludeSemantics: true,
      child: SizedBox(
        // 48dp touch-target height; pill visually centres within it.
        height: 48,
        child: Center(
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Leading dot — 6dp circle.
                SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: TribelyType.caption(fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _background(bool dark) {
    switch (state) {
      case StatusPillState.pending:
        return dark
            ? TribelyColors.nightAccentSoft
            : TribelyColors.paperAccentSoft;
      case StatusPillState.approved:
        return dark
            ? TribelyColors.nightSuccessSoft
            : TribelyColors.paperSuccessSoft;
      case StatusPillState.declined:
      case StatusPillState.withdrawn:
        return dark
            ? TribelyColors.nightBorderSubtle
            : TribelyColors.paperBorderSubtle;
      case StatusPillState.removedByHost:
        return dark
            ? TribelyColors.nightBorderSubtle
            : TribelyColors.paperBorderSubtle;
    }
  }

  Color _foreground(bool dark) {
    switch (state) {
      case StatusPillState.pending:
        return dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
      case StatusPillState.approved:
        return dark ? TribelyColors.nightSuccess : TribelyColors.paperSuccess;
      case StatusPillState.declined:
      case StatusPillState.withdrawn:
        return dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary;
      case StatusPillState.removedByHost:
        return dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    }
  }

  String _label() {
    switch (state) {
      case StatusPillState.pending:
        return 'Pending';
      case StatusPillState.approved:
        return 'Approved';
      case StatusPillState.declined:
        return 'Declined';
      case StatusPillState.withdrawn:
        return 'Withdrawn';
      case StatusPillState.removedByHost:
        return 'Removed';
    }
  }
}
