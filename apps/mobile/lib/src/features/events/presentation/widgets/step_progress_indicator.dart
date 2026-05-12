import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';

/// A horizontal segmented progress indicator for the multi-step create-event
/// flow. Each segment is a rounded pill: filled in the primary color for steps
/// at or before [current], outlined for future steps.
///
/// [current] is 1-based (1 = first step displayed as active).
/// [total] is the total number of steps.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    required this.current,
    required this.total,
    super.key,
  }) : assert(
         current >= 1 && current <= total,
         'current must be in range 1..total',
       );

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(total, (index) {
          final stepNumber = index + 1;
          final isActive = stepNumber <= current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive ? primary : border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
