import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../state/selfie_gating_state.dart';
import '../string_assets/verification_failure_copy.dart';

/// Selfie verification status card for the TRI-68 settings page.
///
/// Renders four visual states driven by [SelfieGatingState]:
///   - [SelfieGatingNotStarted]: simple row inviting the user to start.
///   - [SelfieGatingPending]: read-only row with "Under review" label.
///     Not tappable — nothing to remedy yet.
///   - [SelfieGatingFailed] / [SelfieGatingLocked]: taller card (~96–104dp)
///     with icon, title, and a "View details" link. Tappable.
///   - [SelfieGatingApproved]: success row with checkmark.
///
/// Tapping in any state EXCEPT pending routes to /verification/failure via
/// [onTap]. Caller is responsible for navigation.
class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard({
    required this.gatingState,
    required this.onTap,
    super.key,
  });

  final SelfieGatingState gatingState;

  /// Called on tap for all states except [SelfieGatingPending].
  /// Typically navigates to /verification/failure.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (gatingState) {
      SelfieGatingNotStarted() => _SimpleRow(
        icon: Icons.camera_alt_outlined,
        iconColor: dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary,
        label: 'Verify your selfie',
        supporting: 'Tap to get started',
        onTap: onTap,
        dark: dark,
      ),
      SelfieGatingPending() => _SimpleRow(
        icon: Icons.hourglass_top_rounded,
        iconColor: dark
            ? TribelyColors.nightInkSecondary
            : TribelyColors.paperInkSecondary,
        label: kPendingRowLabel,
        supporting: kPendingRowSupporting,
        onTap: null, // Read-only — nothing to remedy yet.
        dark: dark,
      ),
      SelfieGatingFailed(:final category) => _FailureCard(
        icon: Icons.warning_amber_rounded,
        title: verificationFailureTitle(category),
        body: verificationFailureBody(category),
        onTap: onTap,
        dark: dark,
      ),
      SelfieGatingLocked(:final category) => _FailureCard(
        icon: Icons.lock_outline_rounded,
        title: verificationFailureTitle(category),
        body: kVerificationLockedBody,
        onTap: onTap,
        dark: dark,
      ),
      SelfieGatingApproved() => _SimpleRow(
        icon: Icons.check_circle_outline_rounded,
        iconColor: dark
            ? TribelyColors.nightSuccess
            : TribelyColors.paperSuccess,
        label: 'Selfie verified',
        supporting: 'You\'re all set.',
        onTap: onTap,
        dark: dark,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Simple row (not_started, pending, approved)
// ---------------------------------------------------------------------------

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.supporting,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String supporting;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final content = Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TribelyType.caption(ink)),
                const SizedBox(height: 2),
                Text(supporting, style: TribelyType.caption(inkSecondary)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: inkSecondary, size: 20),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Failure / locked card (failed, locked) — taller, ~96–104dp
// ---------------------------------------------------------------------------

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    required this.dark,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        decoration: BoxDecoration(
          color: accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TribelyType.caption(ink)),
                  const SizedBox(height: 4),
                  Text(body, style: TribelyType.caption(inkSecondary)),
                  const SizedBox(height: 6),
                  Text('View details →', style: TribelyType.caption(accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
