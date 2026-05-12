import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Bottom sheet shown on first Map tab entry to explain why location is needed.
///
/// Spec §D Permission flow:
///   - Icon: location pin, [TribelyColors.paperPrimary].
///   - Headline: "Events near you".
///   - Body: "So we can show events near you in Singapore."
///   - [PrimaryButton]: "Allow location" → calls [onAllow].
///   - [SecondaryButton]: "Not now — browse all SG events" → calls [onDecline].
///
/// This widget is purely presentational — the caller is responsible for:
///   - Triggering the OS permission dialog (via [onAllow]).
///   - Dismissing this sheet before the OS dialog appears.
///   - Storing the "prompt shown" flag so the sheet is not shown again.
///
/// Callbacks SHOULD use `Navigator.of(context).maybePop()` defensively when
/// dismissing — not unconditional `pop()` or `pop(rootNavigator: true)`. The
/// sheet's own route dismissal is handled by `showModalBottomSheet`; an
/// explicit pop in the callback is for any additional cleanup the caller needs.
///
/// The sheet does NOT reappear on subsequent Map tab taps after either action.
class LocationPermissionSheet extends StatelessWidget {
  const LocationPermissionSheet({
    required this.onAllow,
    required this.onDecline,
    super.key,
  });

  /// Called when the user taps "Allow location". The caller should dismiss the
  /// sheet, then invoke [LocationService.requestPermission()].
  final VoidCallback onAllow;

  /// Called when the user taps "Not now — browse all SG events". The caller
  /// dismisses the sheet and the map falls back to CBD centre.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location pin icon — paperPrimary per spec §D.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: TribelyColors.paperPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color: TribelyColors.paperPrimary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Headline
          Text(
            'Events near you',
            style: TribelyType.headline(TribelyColors.paperInkPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Body
          Text(
            'So we can show events near you in Singapore.',
            style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Primary CTA
          PrimaryButton(label: 'Allow location', onPressed: onAllow),
          const SizedBox(height: 12),
          // Secondary CTA (A2 SecondaryButton)
          SecondaryButton(
            label: 'Not now — browse all SG events',
            onPressed: onDecline,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public show-helper
// ---------------------------------------------------------------------------

/// Shows [LocationPermissionSheet] as a non-dismissable bottom sheet (the user
/// must pick one of the two CTAs — outside-tap dismiss is suppressed to avoid
/// ambiguity with "decline").
///
/// Returns after the user has tapped either CTA.
Future<void> showLocationPermissionSheet(
  BuildContext context, {
  required VoidCallback onAllow,
  required VoidCallback onDecline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // isDismissible=false: user must choose Allow or Not Now. Prevents
    // accidental outside-tap from leaving the allow/decline state ambiguous.
    isDismissible: false,
    enableDrag: false,
    builder: (_) =>
        LocationPermissionSheet(onAllow: onAllow, onDecline: onDecline),
  );
}
