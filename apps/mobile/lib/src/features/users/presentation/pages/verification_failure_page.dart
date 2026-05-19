import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../controllers/verification_failure_controller.dart';
import '../state/selfie_gating_state.dart';
import '../state/verification_failure_state.dart';
import '../providers/capability_providers.dart';
import '../string_assets/verification_failure_copy.dart';
import '../widgets/copy_to_clipboard_sheet.dart';
import '../widgets/pre_mailto_disclosure_sheet.dart';
import '../../domain/value_objects/selfie_failure_category.dart';

/// Full-screen failure/lockout page for selfie verification.
///
/// Reachable via:
///   - /verification/failure push from the [VerificationStatusCard] tap in
///     the TRI-68 settings page.
///   - /verification/failure push from a [DisabledCTAHint] tap (Brief F).
///
/// Displays:
///   - Title ("Your photo didn't pass review")
///   - Per-category reason body copy
///   - "Attempt N of 3" counter (at attempt 3: lock icon + paperAccent)
///   - Lockout body (at attempt 3)
///   - Primary CTA: "Try again" (< 3 attempts) | "Contact support" (locked)
///   - SLA line "We'll respond within 3 business days." (locked only)
///   - Tertiary "View verification settings" link
///
/// State changes animate at 150ms easeInOutCubic; skipped when
/// [MediaQuery.disableAnimations] is true.
class VerificationFailurePage extends ConsumerStatefulWidget {
  const VerificationFailurePage({super.key});

  @override
  ConsumerState<VerificationFailurePage> createState() =>
      _VerificationFailurePageState();
}

class _VerificationFailurePageState
    extends ConsumerState<VerificationFailurePage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to clipboard-fallback state transitions after build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleStateChange());
  }

  void _handleStateChange() {
    if (!mounted) return;
    final state = ref.read(verificationFailureControllerProvider);
    if (state is VerificationFailureShowClipboardFallback) {
      _showClipboardFallback(state.clipboardContent);
      ref.read(verificationFailureControllerProvider.notifier).reset();
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
    final surface = dark
        ? TribelyColors.nightSurface
        : TribelyColors.paperSurface;

    final gatingState = ref.watch(selfieGatingStateProvider);
    final ctrlState = ref.watch(verificationFailureControllerProvider);

    // Listen for clipboard fallback transition.
    ref.listen<VerificationFailureState>(
      verificationFailureControllerProvider,
      (previous, next) {
        if (next is VerificationFailureShowClipboardFallback) {
          _showClipboardFallback(next.clipboardContent);
          ref.read(verificationFailureControllerProvider.notifier).reset();
        }
      },
    );

    final isLocked = gatingState is SelfieGatingLocked;
    final SelfieFailureCategory? category = switch (gatingState) {
      SelfieGatingFailed(:final category) => category,
      SelfieGatingLocked(:final category) => category,
      _ => null,
    };
    final int attemptCount = switch (gatingState) {
      SelfieGatingFailed(:final attemptCount) => attemptCount,
      SelfieGatingLocked() => 3,
      _ => 0,
    };

    final title = verificationFailureTitle(category);
    final body = isLocked
        ? kVerificationLockedBody
        : verificationFailureBody(category);

    final isLaunching = ctrlState is VerificationFailureLaunching;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(color: ink),
        title: Text('Verification', style: TribelyType.headline(ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon + title.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: accent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: TribelyType.headline(ink)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Per-category or lockout body.
              AnimatedSwitcher(
                duration: context.motion(TribelyMotion.short),
                switchInCurve: TribelyMotion.easeInOut,
                switchOutCurve: TribelyMotion.easeInOut,
                child: Text(
                  body,
                  key: ValueKey(body),
                  style: TribelyType.bodyM(inkSecondary),
                ),
              ),
              const SizedBox(height: 20),
              // Attempt counter — pre-allocated height prevents layout jump.
              SizedBox(
                height: 28,
                child: AnimatedSwitcher(
                  duration: context.motion(TribelyMotion.short),
                  switchInCurve: TribelyMotion.easeInOut,
                  switchOutCurve: TribelyMotion.easeInOut,
                  child: _AttemptCounter(
                    key: ValueKey(attemptCount),
                    attemptCount: attemptCount,
                    isLocked: isLocked,
                    accent: accent,
                    inkSecondary: inkSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Primary CTA.
              PrimaryButton(
                label: isLocked ? 'Contact support' : 'Try again',
                onPressed: isLaunching
                    ? null
                    : isLocked
                    ? _onContactSupport
                    : _onTryAgain,
                state: isLaunching
                    ? PrimaryButtonState.loading
                    : PrimaryButtonState.idle,
              ),
              // SLA line — only shown when locked.
              AnimatedSize(
                duration: context.motion(TribelyMotion.short),
                curve: TribelyMotion.easeInOut,
                child: isLocked
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          kSlaLine,
                          style: TribelyType.caption(inkSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              // Tertiary link.
              TextButton(
                onPressed: () => context.go('/profile'),
                child: Text(
                  'View verification settings',
                  style: TribelyType.bodyM(inkSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTryAgain() {
    // Brief F / TRI-selfie-submission is the submitter — just pop back for now.
    if (context.canPop()) context.pop();
  }

  void _onContactSupport() {
    // Show PDPA disclosure sheet before opening mail client.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PreMailtoDisclosureSheet(
        onConfirm: () {
          ref
              .read(verificationFailureControllerProvider.notifier)
              .openMailClient();
        },
      ),
    );
  }

  void _showClipboardFallback(String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CopyToClipboardSheet(content: content),
    );
  }
}

// ---------------------------------------------------------------------------
// Attempt counter widget
// ---------------------------------------------------------------------------

class _AttemptCounter extends StatelessWidget {
  const _AttemptCounter({
    required this.attemptCount,
    required this.isLocked,
    required this.accent,
    required this.inkSecondary,
    super.key,
  });

  final int attemptCount;
  final bool isLocked;
  final Color accent;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: accent),
          const SizedBox(width: 4),
          Text(
            'Attempt 3 of 3 — locked for now',
            style: TribelyType.caption(accent),
          ),
        ],
      );
    }

    return Text(
      'Attempt $attemptCount of 3',
      style: TribelyType.caption(inkSecondary),
    );
  }
}
