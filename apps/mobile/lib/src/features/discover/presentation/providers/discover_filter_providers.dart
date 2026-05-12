import 'dart:async';

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

/// Debounce window: coalesces rapid chip taps into a single emission.
///
/// Referenced by the Step-8.5 manual-smoke checklist.
const int _kDebounceMillis = 250;

/// A [StreamProvider] that emits a [DiscoverFiltersActive] snapshot 250ms
/// after the last state change on [discoverFilterControllerProvider].
///
/// The debounce is implemented entirely inside this provider — no public
/// property is exposed on [DiscoverFilterController], keeping the Notifier
/// compliant with `avoid_public_notifier_properties`.
///
/// D2's DiscoverController watches this provider. It will not emit until at
/// least one mutation has been made (idle state produces no emission).
///
/// Consumers that need the current snapshot without debouncing should read
/// [discoverFilterControllerProvider] directly.
final debouncedFiltersProvider = StreamProvider<DiscoverFiltersActive>((ref) {
  final controller = StreamController<DiscoverFiltersActive>.broadcast();
  Timer? debounceTimer;

  // Watch filter state — Riverpod re-runs this callback on every state change.
  ref.listen<DiscoverFilterState>(discoverFilterControllerProvider, (_, next) {
    if (next is! DiscoverFiltersActive) return;
    final snapshot = next;
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: _kDebounceMillis), () {
      if (!controller.isClosed) controller.add(snapshot);
    });
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
    controller.close();
  });

  return controller.stream;
});
