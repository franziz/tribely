import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/discover_filter_controller.dart';
import '../state/discover_filter_state.dart';

// ---------------------------------------------------------------------------
// Filter controller
// ---------------------------------------------------------------------------

/// Riverpod 3.x [NotifierProvider] wiring [DiscoverFilterController].
///
/// D2's DiscoverController MUST subscribe to [debouncedFiltersProvider], not
/// this provider, to avoid triggering a network call on every chip tap.
final discoverFilterControllerProvider =
    NotifierProvider<DiscoverFilterController, DiscoverFilterState>(
      DiscoverFilterController.new,
    );

// ---------------------------------------------------------------------------
// Debounced view — 250ms coalesced snapshot for downstream consumers (D2)
// ---------------------------------------------------------------------------

/// A [StreamProvider] that emits a [DiscoverFiltersActive] snapshot 250ms
/// after the last mutation on [discoverFilterControllerProvider].
///
/// D2's DiscoverController watches this provider. It will not emit until at
/// least one mutation has been made (the initial state is sent synchronously
/// on the first debounce tick after [DiscoverFilterController.build] returns,
/// only if a mutation occurs — idle state produces no emission).
///
/// Consumers that need the current snapshot without waiting for a debounce
/// tick should read [discoverFilterControllerProvider] directly.
final debouncedFiltersProvider = StreamProvider<DiscoverFiltersActive>((ref) {
  final notifier = ref.watch(discoverFilterControllerProvider.notifier);
  return notifier.debouncedStream;
});
