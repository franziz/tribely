import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/validators/event_validators.dart';
import '../providers/events_providers.dart';
import '../state/create_event_state.dart';
import '../widgets/category_selector_field.dart';
import '../widgets/event_form_field.dart';

/// Step 1 — Title and Category.
///
/// Renders a title text field and a category dropdown. Both fields call
/// [CreateEventController.updateField] on change; field errors are sourced
/// from [CreateEventEditing.fieldErrors] so the controller remains the single
/// source of truth.
class CreateEventStep1BasicsPage extends ConsumerWidget {
  const CreateEventStep1BasicsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventControllerProvider);
    if (state is! CreateEventEditing) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(createEventControllerProvider.notifier);
    final draft = state.formData;
    final errors = state.fieldErrors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          EventFormField(
            label: 'Title',
            value: draft.title,
            errorText: errors['title'],
            textInputAction: TextInputAction.next,
            hint: 'e.g. Sunday morning hike at Bukit Timah',
            onChanged: (v) => controller.updateField(field: 'title', value: v),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$titleMinLen–$titleMaxLen characters',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          CategorySelectorField(
            value: draft.category,
            errorText: errors['category'],
            onChanged: (v) =>
                controller.updateField(field: 'category', value: v),
          ),
        ],
      ),
    );
  }
}
