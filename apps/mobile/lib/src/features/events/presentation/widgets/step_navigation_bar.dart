import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// Footer navigation bar for the multi-step create-event flow.
///
/// - Back button is hidden (not rendered) on the first step ([current] == 0).
/// - Next/Publish button label is "Next" for steps 0–3, "Publish" for step 4.
/// - Next/Publish button is disabled when [canAdvance] is false.
///
/// [current] is 0-based. [total] is the total number of steps.
class StepNavigationBar extends StatelessWidget {
  const StepNavigationBar({
    required this.current,
    required this.total,
    required this.canAdvance,
    required this.onBack,
    required this.onNextOrPublish,
    super.key,
  });

  final int current;
  final int total;
  final bool canAdvance;
  final VoidCallback onBack;
  final VoidCallback onNextOrPublish;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? TribelyColors.nightPrimary
        : TribelyColors.paperPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;

    final isFirstStep = current == 0;
    final isLastStep = current == total - 1;
    final nextLabel = isLastStep ? 'Publish' : 'Next';

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button — hidden on the first step so Next stays
              // right-anchored at the same position as Steps 2-5.
              if (!isFirstStep)
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(
                    'Back',
                    style: TribelyType.button(primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(100, 48),
                  ),
                )
              else
                const Spacer(),
              // Next / Publish button
              FilledButton(
                onPressed: canAdvance ? onNextOrPublish : null,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  disabledBackgroundColor: border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(140, 48),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextLabel,
                      style: TribelyType.button(
                        canAdvance
                            ? (dark
                                  ? TribelyColors.nightSurface
                                  : TribelyColors.paperSurfaceHigh)
                            : inkSecondary,
                      ),
                    ),
                    if (!isLastStep) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: canAdvance
                            ? (dark
                                  ? TribelyColors.nightSurface
                                  : TribelyColors.paperSurfaceHigh)
                            : inkSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
