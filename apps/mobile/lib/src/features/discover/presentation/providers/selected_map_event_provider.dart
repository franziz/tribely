import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../events/domain/entities/event.dart';

// ---------------------------------------------------------------------------
// SelectedMapEventController
// ---------------------------------------------------------------------------

/// Controls which event's bottom card is visible on the Discover map.
///
/// Single source of truth for card visibility: when state is non-null the
/// card is shown; when null the card is hidden.
///
/// Follows the project's established `Notifier<T>` +
/// `NotifierProvider.autoDispose` convention (never `AutoDisposeNotifier<T>`).
class SelectedMapEventController extends Notifier<Event?> {
  @override
  Event? build() => null;

  /// Show the card for [event].
  void select(Event event) => state = event;

  /// Hide the card.
  void clear() => state = null;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// AutoDispose provider so that navigating away from the Discover branch
/// naturally resets the selected event state when the widget tree is disposed.
///
/// Scoped to the Discover branch; no cross-feature consumers.
final selectedMapEventProvider =
    NotifierProvider.autoDispose<SelectedMapEventController, Event?>(
      SelectedMapEventController.new,
    );
