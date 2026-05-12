import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
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

  static const int _totalSteps = 5;

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
      if (next is CreateEventEditing && next.isResuming && !_resumeDialogShown) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created!')),
        );
      }

      // Submission error — navigate to the offending step and show banner.
      if (next is CreateEventSubmissionError) {
        _animateToStep(next.returnToStep);
        final banner = next.fieldErrors['_banner'];
        if (banner != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(banner)),
          );
        }
      }
    });

    // ---------------------------------------------------------------------------
    // Derived display values from the current state
    // ---------------------------------------------------------------------------
    final currentStep = switch (state) {
      CreateEventEditing(:final currentStep) => currentStep,
      CreateEventSubmitting() => _totalSteps - 1,
      CreateEventSubmissionError(:final returnToStep) => returnToStep,
      CreateEventSubmissionSuccess() => _totalSteps - 1,
    };

    final isSubmitting = state is CreateEventSubmitting;

    final canAdvance = switch (state) {
      CreateEventEditing() => controller.canAdvance(currentStep),
      _ => false,
    };

    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        dark ? TribelyColors.nightSurface : TribelyColors.paperSurface;

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
      body: Stack(
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
      bottomNavigationBar: StepNavigationBar(
        current: currentStep,
        total: _totalSteps,
        canAdvance: canAdvance,
        onBack: controller.previousStep,
        onNextOrPublish: currentStep < _totalSteps - 1
            ? controller.nextStep
            : controller.submit,
      ),
    );
  }
}
