import 'package:flutter/material.dart';

import '../../../../core/widgets/show_password_toggle.dart';
import '../../../../core/widgets/tribely_text_field.dart';

/// Password field with an internal show/hide toggle.
///
/// The toggle is a `setState` on this widget's local state — only this
/// field rebuilds when toggled, not the surrounding page. (Compare against
/// hoisting `_showPwd` to the page state, which would rebuild the entire
/// form on every toggle.)
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.helper,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TribelyTextField(
      controller: widget.controller,
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText,
      obscure: !_visible,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      suffix: ShowPasswordToggle(
        visible: _visible,
        onToggle: () => setState(() => _visible = !_visible),
      ),
    );
  }
}
