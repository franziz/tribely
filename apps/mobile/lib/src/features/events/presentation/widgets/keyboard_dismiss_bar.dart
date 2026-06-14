import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// A thin full-width bar that floats above the software keyboard, providing a
/// tappable "Done" affordance to dismiss the keyboard on fields where the IME
/// action key does not offer a native dismiss (e.g. numeric pads, multiline
/// text areas).
///
/// This widget is intentionally dumb — it owns no focus nodes and never calls
/// [FocusManager] directly. The caller passes [onDismiss] and owns the
/// dismissal primitive, keeping this widget stateless and easily testable.
///
/// Usage:
/// ```dart
/// if (showAccessory)
///   KeyboardDismissBar(onDismiss: () => FocusManager.instance.primaryFocus?.unfocus()),
/// ```
class KeyboardDismissBar extends StatelessWidget {
  const KeyboardDismissBar({required this.onDismiss, super.key});

  /// Called when the user taps the "Done" label. Typically unfocuses the
  /// current field via `FocusManager.instance.primaryFocus?.unfocus()`.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final surfaceColor = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final doneColor = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Done',
                  style: TribelyType.bodyM(
                    doneColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
