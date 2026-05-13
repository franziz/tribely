import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import '../../features/discover/domain/usecases/browse_events_usecase.dart';

// ---------------------------------------------------------------------------
// Use case provider — lives in core/providers/ because multiple features
// (discover, my_events) consume BrowseEventsUseCase and the provider would
// otherwise need a cross-feature presentation import.
// ---------------------------------------------------------------------------

/// Exposes [BrowseEventsUseCase] from the get_it service locator to Riverpod.
final browseEventsUseCaseProvider = Provider<BrowseEventsUseCase>(
  (_) => sl<BrowseEventsUseCase>(),
);
