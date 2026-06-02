import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/tribely_text_field.dart';

/// A compact free-text fallback field for venue name entry.
///
/// Rendered below the venue search results in states where the picker cannot
/// provide a definitive result (Initial, Empty, DegradedQuota, DegradedNetwork,
/// NoCoords). Hidden in the Selected state per designer spec.
///
/// Copy is locked per EL spec:
/// - Section heading: "Can't find it? Enter the venue name"
/// - Label / placeholder: "e.g. Lau Pa Sat, Marina Bay Sands"
/// - Helper text: "You'll still need to select a matching venue above for the
///   map. This name is how guests see the venue."
///
/// Owns no state beyond the [TextEditingController] lifecycle. The parent is
/// responsible for reading/writing [EventDraft.venueDisplayNameOverride] via
/// the create-event controller.
class FreeTextDisambiguationField extends StatefulWidget {
  const FreeTextDisambiguationField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Current value of [EventDraft.venueDisplayNameOverride]. May be null when
  /// the field has not been filled yet.
  final String? value;

  /// Called on every keystroke. Passes null when the field is cleared.
  final ValueChanged<String?> onChanged;

  @override
  State<FreeTextDisambiguationField> createState() =>
      _FreeTextDisambiguationFieldState();
}

class _FreeTextDisambiguationFieldState
    extends State<FreeTextDisambiguationField> {
  late final TextEditingController _controller;

  void _handleChange() {
    final text = _controller.text;
    widget.onChanged(text.isEmpty ? null : text);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _controller.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(FreeTextDisambiguationField old) {
    super.didUpdateWidget(old);
    // Sync the controller text when the external value changes (e.g. draft
    // load or clearSelection). Guard against cursor-jump on every keystroke by
    // only writing when the incoming value actually differs from what is
    // currently in the controller.
    final incoming = widget.value ?? '';
    if (_controller.text != incoming) {
      // Temporarily remove the listener so the programmatic setText does not
      // fire widget.onChanged with a redundant notification.
      _controller.removeListener(_handleChange);
      _controller.text = incoming;
      _controller.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Can't find it? Enter the venue name",
          style: TribelyType.caption(
            inkSecondary,
          ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        const SizedBox(height: 10),
        TribelyTextField(
          controller: _controller,
          label: 'e.g. Lau Pa Sat, Marina Bay Sands',
          helper:
              "You'll still need to select a matching venue above for the map. "
              'This name is how guests see the venue.',
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
