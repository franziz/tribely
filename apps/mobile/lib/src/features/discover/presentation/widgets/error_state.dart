import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';

/// Inline centered error widget per §I.
///
/// Renders:
/// - Warning outlined icon in [TribelyColors.paperAccent].
/// - "Couldn't load events" body text.
/// - "Retry" text link in [TribelyColors.paperPrimary] semibold.
///
/// When a cached page already loaded, D3 renders this as a banner below the
/// last real card rather than replacing the list. The widget itself is
/// stateless and rendering-context agnostic — the caller (DiscoverListTab)
/// decides placement.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              size: 40,
              color: TribelyColors.paperAccent,
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load events",
              style: TribelyType.bodyM(TribelyColors.paperInkPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: TribelyType.bodyM(TribelyColors.paperPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
