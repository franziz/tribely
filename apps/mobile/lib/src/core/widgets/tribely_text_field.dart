import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Auth-flow text field. Outlined, 56dp tall, rounded 12dp corners.
/// Focus state = soft 4dp ember-coral glow (NOT a sharp 2dp ring).
/// Error state = coral border + caption with triangle accent below.
class TribelyTextField extends StatefulWidget {
  const TribelyTextField({
    required this.controller,
    required this.label,
    this.helper,
    this.errorText,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Minimum number of visible lines. Defaults to 1 to preserve existing
  /// single-line call-site behaviour. Pass [minLines] > 1 for multi-line
  /// text areas (e.g. safety report body: `minLines: 6`).
  final int minLines;

  /// Maximum number of visible lines before the field scrolls.
  /// Defaults to 1. Pass `null` for unbounded vertical growth (the field
  /// expands as the user types). Pass a positive integer to cap growth.
  final int? maxLines;

  @override
  State<TribelyTextField> createState() => _TribelyTextFieldState();
}

class _TribelyTextFieldState extends State<TribelyTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final hasError = widget.errorText != null;

    final color = hasError ? accent : (_focused ? accent : border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              obscureText: widget.obscure,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              onSubmitted: widget.onSubmitted,
              style: TribelyType.bodyL(ink),
              cursorColor: accent,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TribelyType.bodyM(inkSecondary),
                floatingLabelStyle: TribelyType.caption(inkSecondary),
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                suffixIcon: widget.suffix,
                suffixIconConstraints: const BoxConstraints(
                  minHeight: 56,
                  minWidth: 0,
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 8,
                height: 8,
                child: CustomPaint(painter: _TrianglePainter(color: accent)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: TribelyType.caption(accent),
                ),
              ),
            ],
          ),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(widget.helper!, style: TribelyType.caption(inkSecondary)),
        ],
      ],
    );
  }
}

/// Accent triangle next to error captions — softer than a generic red exclamation.
class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
