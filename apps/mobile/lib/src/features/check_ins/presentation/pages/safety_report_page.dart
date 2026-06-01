import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../providers/check_ins_providers.dart';
import '../state/check_ins_state.dart';
import '../string_assets/check_in_copy.dart';

/// Full-screen safety report form reached via "I need help" on [SafetyCheckInSheet].
///
/// The user must:
///   1. Tick the pre-submit 999 disclaimer checkbox.
///   2. Enter a free-text report (max 2000 chars).
///
/// On submit:
///   - Calls [CheckInsController.flagged] with the report body and
///     `disclaimerAcknowledged: true`.
///   - On success: pushReplaces to [SafetyReportSubmittedPage].
///   - On failure: stays on this page and shows an inline error banner.
///     The checkbox state is RETAINED on failure (PM rule: carry-over within
///     same attempt session).
///
/// Back navigation cancels without confirmation. The controller state remains
/// [CheckInsShowing]; the check-in record stays `pending` server-side.
/// The next foreground-trigger will re-surface the prompt per M1's logic.
///
/// Disabled-state helper text: when the checkbox is unticked the helper text
/// is shown even if the text field is also empty. This is intentional — the
/// checkbox is the primary gate and users must acknowledge it before typing.
class SafetyReportPage extends ConsumerStatefulWidget {
  const SafetyReportPage({super.key});

  @override
  ConsumerState<SafetyReportPage> createState() => _SafetyReportPageState();
}

class _SafetyReportPageState extends ConsumerState<SafetyReportPage> {
  static const int _maxLength = 2000;
  static const int _warnThreshold = 1900;

  final _textController = TextEditingController();

  /// Tap recognizer for the first "999" in the disclaimer — bold + tappable
  /// (tel:999). Constructed once in [initState] and disposed in [dispose] to
  /// avoid leaking a new instance on every [AnimatedBuilder] rebuild.
  late final TapGestureRecognizer _disclaimerLinkRecognizer;

  /// Tracks whether the user has ticked the pre-submit 999 disclaimer.
  ///
  /// Lifecycle:
  ///   - Initialises to `false` on each fresh mount (per-submit reset).
  ///   - Survives same-mount retries — is NOT reset on submission failure
  ///     (PM rule: carry-over within same attempt session).
  bool _acknowledged = false;

  bool _submitting = false;
  Failure? _error;

  @override
  void initState() {
    super.initState();
    _disclaimerLinkRecognizer = TapGestureRecognizer()..onTap = _onTel999Tap;
  }

  @override
  void dispose() {
    _disclaimerLinkRecognizer.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onTel999Tap() async {
    try {
      final ok = await launchUrl(Uri.parse('tel:999'));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call 999 on your phone.')),
        );
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call 999 on your phone.')));
    }
  }

  Future<void> _onSend() async {
    final body = _textController.text.trim();
    if (body.isEmpty || body.length > _maxLength) return;
    // Defensive guard — canSend already gates on _acknowledged, but be explicit.
    if (!_acknowledged) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Drive the controller and observe the resulting state to determine
    // success vs. failure — the controller transitions to CheckInsError on
    // failure, and to CheckInsEmpty / CheckInsShowing(next) on success.
    await ref
        .read(checkInsControllerProvider.notifier)
        .flagged(body, disclaimerAcknowledged: true);

    if (!mounted) return;

    final state = ref.read(checkInsControllerProvider);
    if (state is CheckInsError) {
      setState(() {
        _submitting = false;
        _error = state.failure;
        // _acknowledged is intentionally NOT reset here (PM carry-over rule).
      });
    } else {
      // Success — navigate to the terminal confirmation page.
      context.pushReplacement('/check-ins/safety-report/submitted');
    }
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
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final accentSoft = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Scaffold(
      appBar: AppBar(
        title: Text(safetyReportPageTitle, style: TribelyType.headline(ink)),
      ),
      // Use a Column with an Expanded scroll area for the gate block + text
      // field and a pinned bottom button + helper. This prevents layout
      // overflow when the text field grows with content.
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _textController,
          builder: (context, _) {
            final charCount = _textController.text.length;
            final isEmpty = charCount == 0;
            final isOverLimit = charCount > _maxLength;
            final isNearLimit = charCount >= _warnThreshold;
            final counterColor = isNearLimit ? accent : inkSecondary;
            final canSend =
                !isEmpty && !isOverLimit && !_submitting && _acknowledged;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          BannerMessage(message: _error!.message),
                          const SizedBox(height: 16),
                        ],

                        // --------------------------------------------------
                        // Hard pre-submit 999 gate
                        // --------------------------------------------------

                        // Heading row — mirrors the accent colour treatment
                        // of the terminal-page (SafetyReportSubmittedPage)
                        // disclaimer block.
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accentSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Heading
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      safetyReportGateHeading,
                                      style: TribelyType.bodyM(
                                        ink,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Disclaimer body — Text.rich with the FIRST
                              // "999" bolded + tappable, SECOND "999" bolded
                              // only. Wrapped in Semantics so screen readers
                              // get a clean read-aloud of the full paragraph.
                              Semantics(
                                label: safetyReportGateDisclaimerBody,
                                container: true,
                                child: _buildDisclaimerRichText(
                                  ink: ink,
                                  accent: accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Checkbox acknowledgement
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _acknowledged,
                          onChanged: _submitting
                              ? null
                              : (v) =>
                                    setState(() => _acknowledged = v ?? false),
                          title: Text(
                            safetyReportGateCheckboxLabel,
                            style: TribelyType.bodyM(ink),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          // Ensures min 48×48dp tap target (CheckboxListTile
                          // provides this by default; explicit for clarity).
                          visualDensity: VisualDensity.standard,
                        ),

                        const SizedBox(height: 16),

                        // --------------------------------------------------
                        // Report text area
                        // --------------------------------------------------
                        TribelyTextField(
                          controller: _textController,
                          label: safetyReportPlaceholder,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 6,
                          maxLines: null,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$charCount / $_maxLength',
                            style: TribelyType.caption(counterColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ----------------------------------------------------------
                // Pinned bottom — submit CTA + disabled-state helper
                // ----------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: PrimaryButton(
                    label: safetyReportSendCta,
                    onPressed: canSend ? _onSend : null,
                    state: _submitting
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                  ),
                ),
                // Helper text shown when the checkbox is not yet ticked.
                // Prefer this helper even when the text field is also empty —
                // the checkbox is the primary gate (documented in class doc).
                if (!_acknowledged)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      safetyReportGateDisabledHelperText,
                      style: TribelyType.caption(inkSecondary),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the disclaimer body as [Text.rich].
  ///
  /// The text is split around each occurrence of "999":
  ///   - FIRST "999": bold + tappable (tel:999).
  ///   - SECOND "999": bold only.
  ///
  /// The [Semantics] wrapper on the caller provides the screen-reader label,
  /// so the individual [TextSpan] tap-target does not need its own label.
  Widget _buildDisclaimerRichText({required Color ink, required Color accent}) {
    // safetyReportGateDisclaimerBody structure:
    //   "If you or someone else is in immediate danger, or a crime is in
    //    progress, call the Police on 999 now.\n\n
    //    This form is for non-emergency safety reports. It is not monitored in
    //    real time and is not a substitute for emergency services. We aim to
    //    review reports during Singapore business hours (Monday to Friday, 9am
    //    to 9pm SGT, excluding public holidays)."
    //
    // We split on "999" — two occurrences in the copy.
    const raw = safetyReportGateDisclaimerBody;
    final parts = raw.split('999');
    // parts[0]: "...on " (before first 999)
    // parts[1]: " now.\n\n...on " (between first and second 999)
    // parts[2]: " now.\n\n..." (after second 999, no trailing "999")
    // If for any reason the split doesn't yield exactly 3, fall back to plain.
    if (parts.length != 3) {
      return Text(raw, style: TribelyType.bodyM(ink));
    }

    return Text.rich(
      TextSpan(
        style: TribelyType.bodyM(ink),
        children: [
          TextSpan(text: parts[0]),
          // FIRST "999" — bold + tappable (tel:999)
          TextSpan(
            text: '999',
            recognizer: _disclaimerLinkRecognizer,
            style: TribelyType.bodyM(accent).copyWith(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: parts[1]),
          // SECOND "999" — bold only, not tappable
          TextSpan(
            text: '999',
            style: TribelyType.bodyM(ink).copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: parts[2]),
        ],
      ),
    );
  }
}
