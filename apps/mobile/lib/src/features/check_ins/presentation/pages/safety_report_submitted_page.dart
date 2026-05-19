import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../string_assets/check_in_copy.dart';

/// Terminal-state full-screen page shown after a safety report is submitted.
///
/// Back navigation is intentionally suppressed — this is a one-way terminal
/// state. The "Done" CTA returns the user to the app home (/events).
///
/// The SPF 999 disclaimer block is rendered verbatim from [check_in_copy.dart],
/// which sources the string from [docs/policies/post-event-check-in.md].
class SafetyReportSubmittedPage extends ConsumerWidget {
  const SafetyReportSubmittedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return PopScope(
      // Suppress back navigation — terminal state. The Done CTA is the
      // only intended exit path.
      canPop: false,
      child: Scaffold(
        // No AppBar back button — terminal state.
        appBar: AppBar(
          title: Text(
            safetyReportSubmittedTitle,
            style: TribelyType.headline(ink),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safetyReportSubmittedBody,
                  style: TribelyType.bodyL(inkSecondary),
                ),
                const SizedBox(height: 24),
                // SPF 999 disclaimer block — verbatim per policy SoT.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          safetyReportSubmittedSpf999Disclaimer,
                          style: TribelyType.bodyM(
                            ink,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: safetyReportSubmittedDoneCta,
                  onPressed: () => context.go('/events'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
