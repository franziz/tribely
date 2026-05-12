// Smoke tests for CreateEventPage.
//
// Strategy: override [createEventControllerProvider] with a fixed
// [CreateEventEditing] state so the controller's async init (draft load) is
// bypassed. The test-scoped GoRouter provides a minimal route tree so that
// [context.go('/my-events')] does not throw a ProviderNotFoundException or a
// missing-route assertion in production code paths.
//
// Scope: render correctness only. State-machine transitions are covered by
// the controller tests. No interactions are driven here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/presentation/controllers/create_event_controller.dart';
import 'package:tribely/src/features/events/presentation/pages/create_event_page.dart';
import 'package:tribely/src/features/events/presentation/providers/events_providers.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';
import 'package:tribely/src/features/events/presentation/widgets/step_progress_indicator.dart';

// ---------------------------------------------------------------------------
// Fixed controller — returns a constant CreateEventEditing with no async work.
// ---------------------------------------------------------------------------

class _FixedEditingController extends CreateEventController {
  @override
  CreateEventState build() {
    return const CreateEventEditing(
      formData: EventDraft(),
      currentStep: 0,
      fieldErrors: {},
      isResuming: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal GoRouter for the smoke test.
//
// CreateEventPage calls context.go('/my-events') on success. Providing a real
// GoRouter avoids LookupBoundary failures without needing a full production
// route tree.
// ---------------------------------------------------------------------------

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/events/create',
    routes: [
      GoRoute(
        path: '/events/create',
        builder: (context, state) => const CreateEventPage(),
      ),
      GoRoute(
        path: '/my-events',
        builder: (context, state) =>
            const Scaffold(body: Text('my-events-stub')),
      ),
    ],
  );
}

void main() {
  group('CreateEventPage smoke', () {
    testWidgets('renders app bar title "Create Event"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEventControllerProvider.overrideWith(
              _FixedEditingController.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: _buildTestRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Event'), findsOneWidget);
    });

    testWidgets('renders exactly one StepProgressIndicator', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEventControllerProvider.overrideWith(
              _FixedEditingController.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: _buildTestRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StepProgressIndicator), findsOneWidget);
    });

    testWidgets('step 1 renders a text field labelled "Title"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEventControllerProvider.overrideWith(
              _FixedEditingController.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: _buildTestRouter()),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 (Basics) is the active page at currentStep=0.
      // EventFormField renders a TextFormField with an InputDecoration whose
      // labelText is 'Title'. Find by the label text.
      expect(find.text('Title'), findsOneWidget);
    });
  });
}
