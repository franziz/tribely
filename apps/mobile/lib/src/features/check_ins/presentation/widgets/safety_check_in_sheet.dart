import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/check_ins_providers.dart';
import '../string_assets/check_in_copy.dart';

/// Modal bottom sheet presenting the post-event check-in prompt.
///
/// Two CTAs:
///   - "All good": calls [CheckInsController.acknowledged], cross-fades to a
///     confirmation chip "Glad you're safe.", then auto-dismisses after 2.5s.
///   - "I need help": pops the sheet, pushes [SafetyReportPage] via go_router.
///
/// The sheet is shown by [CheckInsOverlay] after the one-time intro sheet has
/// been dismissed (or when the user has already seen the intro).
class SafetyCheckInSheet extends ConsumerStatefulWidget {
  const SafetyCheckInSheet({
    required this.checkInId,
    required this.eventTitle,
    super.key,
  });

  final String checkInId;

  /// The event title to display in the prompt. Truncated defensively at 40
  /// chars if the server sends a longer value.
  final String eventTitle;

  @override
  ConsumerState<SafetyCheckInSheet> createState() => _SafetyCheckInSheetState();
}

class _SafetyCheckInSheetState extends ConsumerState<SafetyCheckInSheet> {
  bool _acknowledged = false;
  bool _loading = false;

  /// Truncates [eventTitle] at 40 characters for display safety.
  String get _displayTitle {
    final title = widget.eventTitle;
    return title.length > 40 ? '${title.substring(0, 40)}…' : title;
  }

  String get _promptTitle =>
      checkInPromptTitle.replaceAll('{event_title}', _displayTitle);

  Future<void> _onAllGood() async {
    if (_loading) return;
    setState(() => _loading = true);

    await ref.read(checkInsControllerProvider.notifier).acknowledged();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _acknowledged = true;
    });

    // Auto-dismiss after 2.5s.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onNeedHelp() {
    Navigator.of(context).pop();
    context.push('/check-ins/safety-report');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final accent = dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;
    final border = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final reduceMotion = context.reduceMotion;

    // When reduce-motion is enabled skip AnimatedCrossFade entirely (it uses
    // a RenderAnimatedSize that misbehaves at Duration.zero). Just show the
    // correct child directly.
    final Widget body;
    if (reduceMotion) {
      body = _acknowledged
          ? _ConfirmationChip(ink: ink)
          : _PromptContent(
              title: _promptTitle,
              loading: _loading,
              ink: ink,
              accent: accent,
              onAllGood: _onAllGood,
              onNeedHelp: _onNeedHelp,
            );
    } else {
      body = AnimatedCrossFade(
        duration: const Duration(milliseconds: 500),
        firstCurve: Curves.easeInOutCubic,
        secondCurve: Curves.easeInOutCubic,
        crossFadeState: _acknowledged
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: _PromptContent(
          title: _promptTitle,
          loading: _loading,
          ink: ink,
          accent: accent,
          onAllGood: _onAllGood,
          onNeedHelp: _onNeedHelp,
        ),
        secondChild: _ConfirmationChip(ink: ink),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            body,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers — inlined per brief B2 guidance (two callers, no shared
// widget; extract if a third caller appears).
// ---------------------------------------------------------------------------

/// Launches `tel:999`. Falls back to a SnackBar if [launchUrl] returns false
/// or throws (e.g., simulator without a phone dialler).
Future<void> _onTel999TapFn(BuildContext context) async {
  try {
    final ok = await launchUrl(Uri.parse('tel:999'));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call 999 on your phone.')));
    }
  } on PlatformException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Call 999 on your phone.')));
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PromptContent extends StatefulWidget {
  const _PromptContent({
    required this.title,
    required this.loading,
    required this.ink,
    required this.accent,
    required this.onAllGood,
    required this.onNeedHelp,
  });

  final String title;
  final bool loading;
  final Color ink;
  final Color accent;
  final VoidCallback onAllGood;
  final VoidCallback onNeedHelp;

  @override
  State<_PromptContent> createState() => _PromptContentState();
}

class _PromptContentState extends State<_PromptContent> {
  late final TapGestureRecognizer _tel999Recognizer;
  late final TapGestureRecognizer _ctaRecognizer;

  @override
  void initState() {
    super.initState();
    _tel999Recognizer = TapGestureRecognizer()..onTap = _onTel999Tap;
    _ctaRecognizer = TapGestureRecognizer()..onTap = widget.onNeedHelp;
  }

  @override
  void dispose() {
    _tel999Recognizer.dispose();
    _ctaRecognizer.dispose();
    super.dispose();
  }

  Future<void> _onTel999Tap() async {
    await _onTel999TapFn(context);
  }

  /// Builds the reminder body as [Text.rich].
  ///
  /// Render rules (per Brief B2):
  ///   - "999" is bolded + `tel:999` link.
  ///   - "file a safety report" renders as a CTA-styled inline link that
  ///     triggers [onNeedHelp] (same destination as the "I need help" CTA).
  ///
  /// [safetyCheckInReminderBody] contains exactly one "999" and exactly one
  /// "file a safety report". If the copy drifts, falls back to plain text.
  Widget _buildReminderRichText() {
    const raw = safetyCheckInReminderBody;

    // Split on the CTA phrase first, then split the left part on "999".
    const ctaPhrase = 'file a safety report';
    final ctaParts = raw.split(ctaPhrase);
    if (ctaParts.length != 2) {
      return Semantics(
        label: raw,
        child: Text(raw, style: TribelyType.bodyM(widget.ink)),
      );
    }

    final leftOfCta =
        ctaParts[0]; // "...call the Police on 999.\n\n...you can "
    final rightOfCta = ctaParts[1]; // ". We aim to review..."

    final leftParts = leftOfCta.split('999');
    if (leftParts.length != 2) {
      return Semantics(
        label: raw,
        child: Text(raw, style: TribelyType.bodyM(widget.ink)),
      );
    }

    return Semantics(
      label: raw,
      container: true,
      child: Text.rich(
        TextSpan(
          style: TribelyType.bodyM(widget.ink),
          children: [
            TextSpan(text: leftParts[0]),
            // "999" — bold + tappable (tel:999)
            TextSpan(
              text: '999',
              recognizer: _tel999Recognizer,
              style: TribelyType.bodyM(widget.accent).copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: leftParts[1]),
            // "file a safety report" — CTA-styled inline link
            TextSpan(
              text: ctaPhrase,
              recognizer: _ctaRecognizer,
              style: TribelyType.bodyM(widget.accent).copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: rightOfCta),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: TribelyType.headline(widget.ink)),
        const SizedBox(height: 16),
        // Reminder body — 999 link + "file a safety report" inline CTA.
        _buildReminderRichText(),
        const SizedBox(height: 24),
        // Primary CTA — "All good"
        PrimaryButton(
          label: checkInPromptAllGoodCta,
          onPressed: widget.loading ? null : widget.onAllGood,
          state: widget.loading
              ? PrimaryButtonState.loading
              : PrimaryButtonState.idle,
        ),
        const SizedBox(height: 12),
        // Secondary CTA — "I need help" (OutlinedButton styled by theme extension)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.loading ? null : widget.onNeedHelp,
            child: const Text(checkInPromptNeedHelpCta),
          ),
        ),
      ],
    );
  }
}

class _ConfirmationChip extends StatelessWidget {
  const _ConfirmationChip({required this.ink});
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final successColor = dark
        ? TribelyColors.nightSuccess
        : TribelyColors.paperSuccess;
    final successSoftColor = dark
        ? TribelyColors.nightSuccessSoft
        : TribelyColors.paperSuccessSoft;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: successSoftColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: successColor, size: 20),
            const SizedBox(width: 8),
            Text(
              checkInAcknowledgedConfirmation,
              style: TribelyType.bodyM(
                successColor,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
