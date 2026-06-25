import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// A consistently-styled text input used across all create-event step pages.
///
/// Wraps [TextFormField] with the Tribely input decoration conventions and
/// wires [errorText] directly into the decoration so all form fields share
/// identical error-display styling. No local state — callers own the value
/// and error message from the controller.
class EventFormField extends StatelessWidget {
  const EventFormField({
    required this.label,
    required this.onChanged,
    this.value,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.hint,
    this.maxLength,
    this.buildCounter,
    super.key,
  });

  final String label;
  final String? value;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final bool enabled;
  final String? hint;

  /// Optional character limit passed to [TextFormField.maxLength].
  /// When null, no limit is enforced and no built-in counter is shown.
  final int? maxLength;

  /// Optional counter builder forwarded to [TextFormField.buildCounter].
  /// Matches the Flutter [InputCounterWidgetBuilder] signature. When null
  /// (and [maxLength] is also null) the default counter behaviour applies.
  final Widget? Function(
    BuildContext, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  })?
  buildCounter;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;

    // TextFormField.initialValue only sets the value once on first build.
    // Because step pages are rebuilt from controller state, we use a key-reset
    // pattern: the caller is expected to key this widget by field name so that
    // Flutter recreates the internal EditableText when the value changes
    // (e.g. after draft load). This is intentional — see controller's
    // acknowledgeResume / discardDraft which reset all draft fields.
    return TextFormField(
      initialValue: value,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      buildCounter: buildCounter,
      style: TribelyType.bodyM(ink),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: TribelyType.caption(inkSecondary),
        hintStyle: TribelyType.bodyM(inkSecondary),
        errorStyle: TribelyType.caption(accent),
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withAlpha(128), width: 1.5),
        ),
      ),
    );
  }
}
