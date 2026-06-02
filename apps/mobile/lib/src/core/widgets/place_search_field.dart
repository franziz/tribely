import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Search field for venue lookup — pure presentation primitive.
///
/// Owns no state beyond listening to [controller] for clear-button visibility.
/// Debounce is the caller's responsibility (Brief C controller).
///
/// Parameters:
/// - [controller] — text controller; caller owns lifecycle.
/// - [onChanged] — forwarded verbatim from [TextField.onChanged]; no debounce.
/// - [onCleared] — called when the trailing clear-X icon is tapped.
/// - [enabled] — when false the field is non-editable and visually de-emphasised
///   (0.5 opacity, matching [TribelyTextField]'s disabled treatment).
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final bool enabled;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  // Re-render whenever the controller text changes so the clear button
  // appears / disappears without rebuilding the entire tree.
  void _onControllerChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(PlaceSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
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
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final hasText = widget.controller.text.isNotEmpty;

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          style: TribelyType.bodyM(ink),
          decoration: InputDecoration(
            hintText: 'Search venues in Singapore',
            hintStyle: TribelyType.bodyM(inkSecondary),
            contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: inkSecondary, size: 20),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: hasText
                ? GestureDetector(
                    onTap: widget.onCleared,
                    child: Icon(Icons.close, color: inkSecondary, size: 18),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
      ),
    );
  }
}
