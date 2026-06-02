import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/widgets/disabled_cta_hint.dart';
import '../../../users/presentation/providers/capability_providers.dart';
import '../../../users/presentation/state/selfie_gating_state.dart';
import '../../../users/presentation/string_assets/verification_failure_copy.dart';
import '../controllers/create_event_controller.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/resume_draft_dialog.dart';
import '../widgets/step_navigation_bar.dart';
import '../widgets/step_progress_indicator.dart';
import 'create_event_step1_basics_page.dart';
import 'create_event_step2_venue_page.dart';
import 'create_event_step3_when_page.dart';
import 'create_event_step4_logistics_page.dart';
import 'create_event_step5_describe_page.dart';

/// Host page for the multi-step create-event flow.
///
/// Owns the [PageController] (local UI ephemera only — actual step state lives
/// in [CreateEventController]). Uses [ref.listen] for all imperative side
/// effects (dialog, snackbar, navigation) to keep [build] free of side effects.
///
/// Step pages are indexed 0–4:
///   0 = Basics (title, category)
///   1 = Venue (name, lat, lng)
///   2 = When (startsAt, endsAt)
///   3 = Logistics (capacity, approvalMode)
///   4 = Describe + Review (description, read-only summary)
class CreateEventPage extends ConsumerStatefulWidget {
  const CreateEventPage({super.key});

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  late final PageController _pageController;

  /// Guards the resume dialog so it is only shown once per mount, even if the
  /// state rebuilds with [isResuming] == true multiple times before the async
  /// dialog resolves.
  bool _resumeDialogShown = false;

  /// Tracks the last rendered step so we can detect when Step 5 (index 4)
  /// becomes visible and trigger a [refreshBlockingFields] call to catch
  /// time-decayed validators.
  int _lastRenderedStep = 0;

  static const int _totalSteps = 5;
  static const int _lastStepIndex = _totalSteps - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Dismisses the software keyboard, then invokes [action].
  ///
  /// Called by the Next and Previous button wrappers so focus is always
  /// released before the controller advances or retreats the step. The
  /// controller itself is pure Dart and must not import Flutter widget-tree
  /// APIs (architecture rule — no `flutter/widgets.dart` in Notifier classes).
  void _dismissFocusAndCall(VoidCallback action) {
    FocusManager.instance.primaryFocus?.unfocus();
    action();
  }

  void _animateToStep(int step) {
    if (!_pageController.hasClients) return;
    final currentPage = _pageController.page?.round() ?? 0;
    if (currentPage == step) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventControllerProvider);
    final controller = ref.read(createEventControllerProvider.notifier);

    // ---------------------------------------------------------------------------
    // State-transition side effects — all imperative work lives here, not in build
    // ---------------------------------------------------------------------------
    ref.listen<CreateEventState>(createEventControllerProvider, (prev, next) {
      // Resume-draft dialog — shown exactly once after isResuming is set.
      if (next is CreateEventEditing &&
          next.isResuming &&
          !_resumeDialogShown) {
        _resumeDialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ResumeDraftDialog(
            onResume: controller.acknowledgeResume,
            onDiscard: controller.discardDraft,
          ),
        );
      }

      // Step navigation sync — animate PageView to match the controller's step.
      if (next is CreateEventEditing) {
        _animateToStep(next.currentStep);
      }

      // Submission success — navigate to My Events.
      if (next is CreateEventSubmissionSuccess) {
        // TODO(TRI-37): when event detail page lands, replace with /events/${next.eventId}
        context.go('/my-events');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event created!')));
      }

      // Submission error — navigate to the offending step and show banner.
      if (next is CreateEventSubmissionError) {
        _animateToStep(next.returnToStep);
        final banner = next.fieldErrors['_banner'];
        if (banner != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(banner)));
        }
      }
    });

    // ---------------------------------------------------------------------------
    // Derived display values from the current state
    // ---------------------------------------------------------------------------
    final currentStep = switch (state) {
      CreateEventEditing(:final currentStep) => currentStep,
      CreateEventSubmitting() => _lastStepIndex,
      CreateEventSubmissionError(:final returnToStep) => returnToStep,
      CreateEventSubmissionSuccess() => _lastStepIndex,
    };

    // When Step 5 first becomes visible, force a blockingFields recompute so
    // time-decayed validators (validateStartsAt) are surfaced before the user
    // taps Publish. Use addPostFrameCallback to stay outside build() mutation.
    if (currentStep == _lastStepIndex && _lastRenderedStep != _lastStepIndex) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.refreshBlockingFields();
      });
    }
    _lastRenderedStep = currentStep;

    final isSubmitting = state is CreateEventSubmitting;

    // Selfie gating — read once per build; only blocks the Publish step.
    final selfieGatingState = ref.watch(selfieGatingStateProvider);
    final isSelfieGated = selfieGatingState is! SelfieGatingApproved;

    // On step 4 the Publish button must require every prior step to also be
    // valid — not just step 4's own fields. canSubmit() is the full cross-step
    // check. On steps 0–3 the per-step canAdvance is sufficient.
    // Selfie gating is additive: if selfie is not approved, Publish is blocked
    // regardless of form validity.
    final canAdvance = switch (state) {
      CreateEventEditing() =>
        currentStep < _lastStepIndex
            ? controller.canAdvance(currentStep)
            : controller.canSubmit() && !isSelfieGated,
      _ => false,
    };

    // Blocking hint data — only relevant when in editing state.
    final blockingFieldErrors = switch (state) {
      CreateEventEditing(:final blockingFieldErrors) => blockingFieldErrors,
      _ => const <int, List<(String, String)>>{},
    };

    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurface
        : TribelyColors.paperSurface;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Create Event'),
        leading: BackButton(
          onPressed: () {
            // Autosave guarantees draft preservation — no confirm dialog needed.
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/my-events');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: StepProgressIndicator(
            current: currentStep + 1,
            total: _totalSteps,
          ),
        ),
      ),
      body: GestureDetector(
        // Tap-outside keyboard dismissal. behavior: opaque ensures taps on
        // non-interactive areas of child widgets also trigger this handler.
        // FocusManager.instance.primaryFocus?.unfocus() clears the focused
        // node directly, avoiding the scope-vs-node ambiguity of
        // FocusScope.of(context).unfocus() which defaults to
        // UnfocusDisposition.scope and moves focus up rather than clearing it.
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            // Step pages — swipe is disabled; only controller-driven navigation.
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                CreateEventStep1BasicsPage(),
                CreateEventStep2VenuePage(),
                CreateEventStep3WhenPage(),
                CreateEventStep4LogisticsPage(),
                CreateEventStep5DescribePage(),
              ],
            ),

            // Submitting overlay — semi-transparent barrier + centered spinner.
            if (isSubmitting)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withAlpha(77),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selfie-gating hint — shown above the nav bar on the Publish step
          // when the user's selfie is not approved. Takes precedence over the
          // form-validity _BlockingHint per TRI-57 (selfie-gating's hint copy
          // wins when selfie is the blocker). Only rendered on the last step;
          // navigation steps are not selfie-gated.
          if (isSelfieGated && currentStep == _lastStepIndex)
            _SelfieGatingHint(selfieGatingState: selfieGatingState),

          // Blocking hint — rendered above the nav bar when the current step
          // has a blocking field (so the user knows why Next/Publish is grey).
          // Suppressed when selfie gating is active on the last step so the
          // two hints don't compete for the same inline space.
          if (!canAdvance &&
              state is CreateEventEditing &&
              !(isSelfieGated && currentStep == _lastStepIndex))
            _BlockingHint(
              currentStep: currentStep,
              totalSteps: _totalSteps,
              blockingFieldErrors: blockingFieldErrors,
              onGoToStep: controller.goToStep,
            ),
          StepNavigationBar(
            current: currentStep,
            total: _totalSteps,
            canAdvance: canAdvance,
            onBack: () => _dismissFocusAndCall(controller.previousStep),
            onNextOrPublish: currentStep < _lastStepIndex
                ? () => _dismissFocusAndCall(controller.nextStep)
                : controller.submit,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selfie-gating hint (Create Event — last step only)
// ---------------------------------------------------------------------------

/// Renders [DisabledCTAHint] above the nav bar when the user's selfie
/// verification is not approved. Routes to /verification/failure on tap for
/// failed/locked states; falls back to /verification/failure for pending and
/// notStarted until TRI-68 (settings page) and TRI-23 (selfie capture entry)
/// land their respective routes.
class _SelfieGatingHint extends StatelessWidget {
  const _SelfieGatingHint({required this.selfieGatingState});

  final SelfieGatingState selfieGatingState;

  @override
  Widget build(BuildContext context) {
    return switch (selfieGatingState) {
      SelfieGatingFailed() || SelfieGatingLocked() => DisabledCTAHint(
        text: kDisabledHintCreateEvent,
        accentSpan: kDisabledHintCreateEventAccentSpan,
        onTap: () => context.push('/verification/failure'),
      ),
      SelfieGatingPending() => DisabledCTAHint(
        text: kDisabledHintPending,
        // Single-colour (inkSecondary) — no accentSpan.
        // TODO(TRI-68): route to verification settings page once that route lands.
        onTap: () => context.push('/verification/failure'),
      ),
      SelfieGatingNotStarted() => DisabledCTAHint(
        text: kDisabledHintPending,
        // Single-colour (inkSecondary) — no accentSpan.
        // TODO(TRI-23): route to selfie capture entry point once that route lands.
        onTap: () => context.push('/verification/failure'),
      ),
      SelfieGatingApproved() => const SizedBox.shrink(),
    };
  }
}

/// Displays a hint above the nav bar explaining why Next/Publish is disabled.
///
/// On the final step (Step 5, [currentStep] == [totalSteps] - 1): renders a
/// list of every blocking field across all steps. Each item is tappable and
/// navigates to the owning step. Format:
///   "Can't publish yet — N things to finish:"
///   "• Step 3: Event must start at least 5 minutes from now  [Edit]"
///
/// On intermediate steps (0 – totalSteps - 2): renders only the first blocking
/// field for the current step as a single-line hint. Format:
///   "Step N: [error message]"
///
/// Styled using existing design tokens (accent + accentSoft for error).
/// No new design system additions.
class _BlockingHint extends StatelessWidget {
  const _BlockingHint({
    required this.currentStep,
    required this.totalSteps,
    required this.blockingFieldErrors,
    required this.onGoToStep,
  });

  final int currentStep;
  final int totalSteps;

  /// Step index → list of (fieldName, errorMessage) for fields that fail.
  final Map<int, List<(String, String)>> blockingFieldErrors;

  final void Function(int step) onGoToStep;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = dark
        ? TribelyColors.nightAccent
        : TribelyColors.paperAccent;
    final bgColor = dark
        ? TribelyColors.nightAccentSoft
        : TribelyColors.paperAccentSoft;
    final borderColor = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    final isLastStep = currentStep == totalSteps - 1;

    if (isLastStep) {
      return _buildLastStepHint(context, accentColor, bgColor, borderColor);
    }
    return _buildIntermediateStepHint(context, accentColor, bgColor);
  }

  Widget _buildLastStepHint(
    BuildContext context,
    Color accentColor,
    Color bgColor,
    Color borderColor,
  ) {
    // Collect all blocking items across all steps in step order.
    final items = <(int, String)>[];
    for (final entry in blockingFieldErrors.entries) {
      for (final (_, error) in entry.value) {
        items.add((entry.key, error));
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();

    final count = items.length;
    final plural = count == 1 ? 'thing' : 'things';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Can't publish yet — $count $plural to finish:",
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) {
            final (stepIndex, errorMessage) = item;
            final stepLabel = 'Step ${stepIndex + 1}';
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () => onGoToStep(stepIndex),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• $stepLabel: $errorMessage',
                        style: TextStyle(color: accentColor, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIntermediateStepHint(
    BuildContext context,
    Color accentColor,
    Color bgColor,
  ) {
    // Show the first error for the current step only.
    final stepErrors = blockingFieldErrors[currentStep];
    if (stepErrors == null || stepErrors.isEmpty) {
      return const SizedBox.shrink();
    }

    final (fieldName, rawErrorMessage) = stepErrors.first;
    final stepLabel = 'Step ${currentStep + 1}';

    // Step 2 (index 1): map technical lat/lng field errors to the venue-picker
    // user-facing copy. "Latitude is required" / "Longitude is required" are
    // too technical — the user sees a venue search UI, not lat/lng inputs.
    final errorMessage =
        (currentStep == 1 &&
            (fieldName == 'latitude' || fieldName == 'longitude'))
        ? 'Pick a venue from the search results to continue'
        : rawErrorMessage;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '$stepLabel: $errorMessage',
        style: TextStyle(color: accentColor, fontSize: 12),
      ),
    );
  }
}
