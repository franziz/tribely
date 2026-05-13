import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/usecases/browse_events_usecase.dart';

// ---------------------------------------------------------------------------
// Use case provider — isolated from discoverControllerProvider to prevent
// circular imports (discover_controller imports this; discover_providers
// imports discover_controller).
// ---------------------------------------------------------------------------

/// Exposes [BrowseEventsUseCase] from the get_it service locator to Riverpod.
final browseEventsUseCaseProvider = Provider<BrowseEventsUseCase>(
  (_) => sl<BrowseEventsUseCase>(),
);
