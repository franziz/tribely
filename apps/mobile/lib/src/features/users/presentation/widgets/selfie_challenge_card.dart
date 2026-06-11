import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';

/// Selfie challenge card — feature-scoped, dismissible, non-blocking.
///
/// Displayed in the capture footer per the Designer spec (TRI-23 Brief E).
/// Acts as an optional-action prompt, not a gate. Dismiss taps remove the
/// card with a fade-out; no action required to proceed.
///
/// Placement: [users/presentation/widgets/] — feature-scoped per EL's YAGNI
/// ruling. Do NOT move to core/widgets/ without EL sign-off.
class SelfieChallengeCard extends StatelessWidget {
  const SelfieChallengeCard({
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh.withValues(alpha: 0.9)
        : TribelyColors.paperSurfaceHigh.withValues(alpha: 0.9);
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quick tip',
                  style: TribelyType.caption(ink).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Face the light, hold your phone at eye level, and '
                  'make sure your whole face is inside the oval.',
                  style: TribelyType.caption(inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              size: 18,
              color: inkSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            tooltip: 'Dismiss tip',
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}

/// Wrapper that fades out [SelfieChallengeCard] on dismiss.
///
/// Caller should use this widget and let it manage its own visibility state
/// so the fade animation doesn't require the parent to rebuild.
class DismissableSelfieChallengeCard extends StatefulWidget {
  const DismissableSelfieChallengeCard({super.key});

  @override
  State<DismissableSelfieChallengeCard> createState() =>
      _DismissableSelfieChallengeCardState();
}

class _DismissableSelfieChallengeCardState
    extends State<DismissableSelfieChallengeCard> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: TribelyMotion.short,
      child: _visible
          ? SelfieChallengeCard(
              onDismiss: () => setState(() => _visible = false),
            )
          : const SizedBox.shrink(),
    );
  }
}
