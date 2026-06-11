import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../state/selfie_gating_state.dart';
import '../string_assets/selfie_capture_copy.dart';

/// Screen 1 — Selfie consent.
///
/// Route: /selfie/consent
///
/// Renders two variants driven by the [intakeDisabled] flag:
///
///   **Standard variant** (intakeDisabled == false):
///   - Camera icon + Fraunces headline
///   - Legal consent body v1.1 (verbatim from [selfie_capture_copy.dart])
///   - Micro-detail line
///   - PrimaryButton "Take my photo" → requests camera permission →
///     on grant, pushes /selfie/capture
///   - TextButton "Not now" → pops
///
///   **Intake-disabled variant** (intakeDisabled == true):
///   - Hourglass icon + "Verification temporarily unavailable" headline
///   - Body copy
///   - "Got it" CTA → pops (never opens camera)
///
/// The router guard (in app_router.dart) ensures the user's [SelfieGatingState]
/// is one that allows entry before this page is shown. Defensive copy is
/// rendered here only as a final fallback.
class SelfieConsentPage extends ConsumerWidget {
  const SelfieConsentPage({required this.intakeDisabled, super.key});

  /// When true, renders the maintenance-mode variant and never opens the
  /// camera regardless of user action.
  final bool intakeDisabled;

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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: intakeDisabled
            ? _buildIntakeDisabled(
                context,
                ink: ink,
                inkSecondary: inkSecondary,
              )
            : _buildStandard(
                context,
                ink: ink,
                inkSecondary: inkSecondary,
                accent: accent,
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Standard variant
  // ---------------------------------------------------------------------------

  Widget _buildStandard(
    BuildContext context, {
    required Color ink,
    required Color inkSecondary,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Camera icon
                Center(
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 56,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 24),
                // Fraunces headline
                Text(
                  kConsentHeadline,
                  style: TextStyle(
                    fontFamily: TribelyType.displayFamily,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    height: 34 / 28,
                    color: ink,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Legal consent body v1.1 — verbatim, paragraph by paragraph.
                // LEGAL-COMPLIANCE LOCKED — do not inline-edit these strings.
                // Edit only via selfie_capture_copy.dart after legal sign-off.
                Text(
                  kConsentBodyParagraph1,
                  style: TribelyType.bodyM(inkSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  kConsentBodyParagraph2,
                  style: TribelyType.bodyM(inkSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  kConsentBodyParagraph3,
                  style: TribelyType.bodyM(inkSecondary),
                ),
                const SizedBox(height: 16),
                // Affirmative-act sentence — PENDING legal re-bless.
                // TODO(TRI-23): replace with the final legal-blessed wording
                // once team-lead relays the re-blessed affirmative-act sentence.
                Text(
                  kConsentAffirmativeActSentence,
                  style: TribelyType.bodyM(inkSecondary),
                ),
                const SizedBox(height: 16),
                // Policy link
                GestureDetector(
                  onTap: () {
                    // TODO(TRI-152): open kConsentPolicyUrl via url_launcher
                    // once the live privacy-policy URL gate is cleared.
                  },
                  child: Text(
                    '$kConsentPolicyLinkLabel →',
                    style: TribelyType.bodyM(accent).copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Micro-detail
                Text(
                  kConsentMicroDetail,
                  style: TribelyType.caption(inkSecondary),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        // CTAs
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: kConsentPrimaryCtaLabel,
                onPressed: () => _onTakePhoto(context),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  kConsentSecondaryCtaLabel,
                  style: TribelyType.button(inkSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Intake-disabled variant
  // ---------------------------------------------------------------------------

  Widget _buildIntakeDisabled(
    BuildContext context, {
    required Color ink,
    required Color inkSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 56, color: ink),
                const SizedBox(height: 24),
                Text(
                  kIntakeDisabledHeadline,
                  style: TextStyle(
                    fontFamily: TribelyType.displayFamily,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    height: 34 / 28,
                    color: ink,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  kIntakeDisabledBody,
                  style: TribelyType.bodyM(inkSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: PrimaryButton(
            label: kIntakeDisabledCtaLabel,
            onPressed: () => context.pop(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Permission request + navigation
  // ---------------------------------------------------------------------------

  Future<void> _onTakePhoto(BuildContext context) async {
    final status = await Permission.camera.request();

    if (!context.mounted) return;

    if (status.isGranted) {
      unawaited(context.push('/selfie/capture'));
      return;
    }

    if (status.isPermanentlyDenied) {
      // User has permanently denied — show Settings prompt via capture page
      // (which handles the permission-denied state). Push so the user can
      // navigate back to consent if they change their mind.
      unawaited(context.push('/selfie/capture'));
      return;
    }

    // status.isDenied — user tapped "Don't allow" in the system dialog.
    // Nothing to do: the system dialog has already explained the permission.
    // The user can tap "Take my photo" again to re-request.
  }
}

// ---------------------------------------------------------------------------
// Router guard helper — exposed so app_router.dart can read it without
// importing presentation state directly.
// ---------------------------------------------------------------------------

/// Returns whether [state] allows entry into the selfie consent flow.
///
/// Allowed: NotStarted, Failed, Locked (retry-after is enforced server-side).
/// Blocked: Approved (already done), Pending (already under review).
bool selfieConsentEntryAllowed(SelfieGatingState state) => switch (state) {
      SelfieGatingNotStarted() ||
      SelfieGatingFailed() ||
      SelfieGatingLocked() =>
        true,
      SelfieGatingPending() || SelfieGatingApproved() => false,
    };
