import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/discover_controller.dart';
import '../state/discover_state.dart';

// Re-export so discover-internal callers can import from one place without
// introducing circular dependencies. The provider itself lives in core/providers/
// so that cross-feature consumers (my_events) don't incur a presentation import.
export '../../../../core/providers/browse_events_usecase_provider.dart';

// ---------------------------------------------------------------------------
// D2 — DiscoverController
//
// Not autoDispose: the Discover tab is persistent and we don't want to lose
// accumulated pagination state on every navigation pop. The controller lives
// as long as the ProviderScope.
// ---------------------------------------------------------------------------

/// Primary state controller for the Discover screen.
///
/// D3 / D4 subscribe to this to render the event feed, map pins, loading
/// skeletons, empty states, and error views.
///
/// D3's Retry button and loadMore scroll trigger call [DiscoverController]
/// methods directly via [discoverControllerProvider.notifier].
final discoverControllerProvider =
    NotifierProvider<DiscoverController, DiscoverState>(DiscoverController.new);
