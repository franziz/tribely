import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Six-box OTP code input for SMS verification flows.
///
/// A single hidden [TextField] drives all state; the six boxes are purely
/// decorative overlays rendered via a [Stack]. Tapping anywhere on the widget
/// routes focus to the hidden field.
///
/// Accessibility: the hidden field carries the semantic label
/// "6-digit verification code". The decorative boxes are wrapped in
/// [ExcludeSemantics] so screen readers only interact with the real input.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    required this.onCompleted,
    this.onChanged,
    this.errorState = false,
    this.enabled = true,
    super.key,
  });

  /// Fires exactly once when the entered code reaches 6 digits.
  /// Re-fires only if the user clears and re-completes.
  final void Function(String code) onCompleted;

  /// Fires on every input change with the partial or complete value.
  final void Function(String partial)? onChanged;

  /// When true, all 6 box borders render in the accent error color.
  final bool errorState;

  /// Whether the input is interactive.
  final bool enabled;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;

  // Tracks whether we've already fired onCompleted for the current 6-char run.
  // Resets when the length drops below 6 so re-fill triggers again.
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    final text = _controller.text;
    setState(() {}); // rebuild boxes

    widget.onChanged?.call(text);

    if (text.length < 6) {
      _completedFired = false;
    } else if (text.length == 6 && !_completedFired) {
      _completedFired = true;
      widget.onCompleted(text);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static const double _boxWidth = 48;
  static const double _boxHeight = 56;
  static const double _gap = 6;
  static const int _length = 6;

  // Total width: 6 boxes + 5 gaps
  static const double _totalWidth = _length * _boxWidth + (_length - 1) * _gap;

  List<Widget> _buildBoxes(bool dark) {
    final text = _controller.text;
    final widgets = <Widget>[];
    for (var i = 0; i < _length; i++) {
      if (i > 0) widgets.add(const SizedBox(width: _gap));
      final char = i < text.length ? text[i] : null;
      final isFocusedBox = _focused && i == text.length && i < _length;
      widgets.add(
        _OtpBox(
          char: char,
          isFocused: isFocusedBox,
          errorState: widget.errorState,
          dark: dark,
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '6-digit verification code',
      child: GestureDetector(
        onTap: () {
          if (widget.enabled) {
            _focusNode.requestFocus();
          }
        },
        // Transparent so the gesture detector catches taps on the full area.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _totalWidth,
          height: _boxHeight,
          child: Stack(
            children: [
              // Hidden text field — drives all input state.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    // In debug mode, omit autofill hints so that a real device's
                    // SMS app cannot overwrite a manually-typed magic code
                    // (e.g. "000000") via AutofillHints.oneTimeCode injection.
                    // Production users keep the autofill UX; developers testing
                    // on real devices stop having their keystrokes overwritten.
                    autofillHints: kDebugMode
                        ? const []
                        : const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_length),
                    ],
                    // Prevent the cursor from showing on the overlay.
                    showCursor: false,
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              ),
              // Decorative boxes — ExcludeSemantics so a11y ignores them.
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildBoxes(dark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.char,
    required this.isFocused,
    required this.errorState,
    required this.dark,
  });

  final String? char;
  final bool isFocused;
  final bool errorState;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final double borderWidth;

    if (errorState) {
      borderColor = dark
          ? TribelyColors.nightAccent
          : TribelyColors.paperAccent;
      borderWidth = 2;
    } else if (isFocused) {
      borderColor = dark
          ? TribelyColors.nightPrimary
          : TribelyColors.paperPrimary;
      borderWidth = 2;
    } else if (char != null) {
      borderColor = dark
          ? TribelyColors.nightPrimary
          : TribelyColors.paperPrimary;
      borderWidth = 1.5;
    } else {
      borderColor = dark
          ? TribelyColors.nightBorderSubtle
          : TribelyColors.paperBorderSubtle;
      borderWidth = 1.5;
    }

    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;

    return Container(
      width: _OtpCodeInputState._boxWidth,
      height: _OtpCodeInputState._boxHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: char != null
          ? Text(
              char!,
              style: TribelyType.headline(
                inkPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            )
          : null,
    );
  }
}
