// Widget tests for CreateEventStep5DescribePage — Cost notes review row
// (TRI-51 Sub-task B).
//
// Strategy: override [createEventControllerProvider] with a fixed
// [CreateEventEditing] state carrying a draft with/without costNotes.
// No map or animated widgets on Step 5 — bounded pump() walks are safe.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tribely/src/features/events/domain/entities/event_category.dart';
import 'package:tribely/src/features/events/domain/entities/event_draft.dart';
import 'package:tribely/src/features/events/domain/validators/event_validators.dart';
import 'package:tribely/src/features/events/presentation/controllers/create_event_controller.dart';
import 'package:tribely/src/features/events/presentation/pages/create_event_step5_describe_page.dart';
import 'package:tribely/src/features/events/presentation/providers/events_providers.dart';
import 'package:tribely/src/features/events/presentation/state/create_event_state.dart';

// ---------------------------------------------------------------------------
// Helpers — mirrored from create_event_page_test.dart
// ---------------------------------------------------------------------------

const _testStepFields = {
  0: ['title', 'category'],
  1: ['latitude', 'longitude'],
  2: ['startsAt', 'endsAt'],
  3: ['capacity', 'approvalMode'],
  4: ['description'],
};

String? _testValidateField(String field, EventDraft draft) {
  return switch (field) {
    'title' => validateTitle(draft.title),
    'category' => validateCategory(draft.category),
    'venueName' => validateVenueName(draft.venueName),
    'latitude' => validateLatitude(draft.latitude),
    'longitude' => validateLongitude(draft.longitude),
    'startsAt' => validateStartsAt(draft.startsAt),
    'endsAt' => validateEndsAt(draft.endsAt, draft.startsAt),
    'capacity' => validateCapacity(draft.capacity),
    'approvalMode' => validateApprovalMode(draft.approvalMode),
    'description' => validateDescription(draft.description),
    _ => null,
  };
}

({
  Map<int, List<String>> blockingFields,
  Map<int, List<(String, String)>> blockingFieldErrors,
})
_testDeriveBlocking(EventDraft draft) {
  final fields = <int, List<String>>{};
  final errors = <int, List<(String, String)>>{};
  for (final entry in _testStepFields.entries) {
    final failingFields = <String>[];
    final failingErrors = <(String, String)>[];
    for (final field in entry.value) {
      final error = _testValidateField(field, draft);
      if (error != null) {
        failingFields.add(field);
        failingErrors.add((field, error));
      }
    }
    if (failingFields.isNotEmpty) {
      fields[entry.key] = failingFields;
      errors[entry.key] = failingErrors;
    }
  }
  return (blockingFields: fields, blockingFieldErrors: errors);
}

// ---------------------------------------------------------------------------
// Fixed controllers — return constant CreateEventEditing state.
// ---------------------------------------------------------------------------

/// Controller whose draft has costNotes set to a non-empty string.
class _WithCostNotesController extends CreateEventController {
  @override
  CreateEventState build() {
    final draft = EventDraft(
      title: 'Sunday Morning Hike',
      category: EventCategory.hike,
      venueName: '1 Marina Blvd',
      latitude: 1.28,
      longitude: 103.85,
      startsAt: DateTime(2030, 6, 1, 8),
      endsAt: DateTime(2030, 6, 1, 11),
      capacity: 10,
      approvalMode: 'auto',
      description: 'A lovely hike for solo travellers.',
      costNotes: 'Pay your own way',
      currentStep: 4,
    );
    final (:blockingFields, :blockingFieldErrors) = _testDeriveBlocking(draft);
    return CreateEventEditing(
      formData: draft,
      currentStep: 4,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }
}

/// Controller whose draft has costNotes == null.
class _NoCostNotesController extends CreateEventController {
  @override
  CreateEventState build() {
    final draft = EventDraft(
      title: 'Sunday Morning Hike',
      category: EventCategory.hike,
      venueName: '1 Marina Blvd',
      latitude: 1.28,
      longitude: 103.85,
      startsAt: DateTime(2030, 6, 1, 8),
      endsAt: DateTime(2030, 6, 1, 11),
      capacity: 10,
      approvalMode: 'auto',
      description: 'A lovely hike for solo travellers.',
      currentStep: 4,
    );
    final (:blockingFields, :blockingFieldErrors) = _testDeriveBlocking(draft);
    return CreateEventEditing(
      formData: draft,
      currentStep: 4,
      fieldErrors: const {},
      isResuming: false,
      blockingFields: blockingFields,
      blockingFieldErrors: blockingFieldErrors,
    );
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpStep5(
  WidgetTester tester,
  CreateEventController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [createEventControllerProvider.overrideWith(() => controller)],
      child: const MaterialApp(
        home: Scaffold(body: CreateEventStep5DescribePage()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CreateEventStep5DescribePage — Cost notes review row (TRI-51 B)', () {
    testWidgets(
      'draft with costNotes — "Cost notes" label and value are rendered',
      (tester) async {
        await _pumpStep5(tester, _WithCostNotesController());

        expect(find.text('Cost notes'), findsOneWidget);
        expect(find.text('Pay your own way'), findsOneWidget);
      },
    );

    testWidgets('draft without costNotes — "Cost notes" label is absent', (
      tester,
    ) async {
      await _pumpStep5(tester, _NoCostNotesController());

      expect(find.text('Cost notes'), findsNothing);
    });
  });
}
