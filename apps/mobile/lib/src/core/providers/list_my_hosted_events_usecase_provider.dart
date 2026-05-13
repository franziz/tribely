import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import '../../features/discover/domain/usecases/list_my_hosted_events_usecase.dart';

// ---------------------------------------------------------------------------
// Use case provider — lives in core/providers/ because multiple features
// may consume ListMyHostedEventsUseCase and the provider would otherwise
// need a cross-feature presentation import.
// ---------------------------------------------------------------------------

/// Exposes [ListMyHostedEventsUseCase] from the get_it service locator to Riverpod.
final listMyHostedEventsUseCaseProvider = Provider<ListMyHostedEventsUseCase>(
  (_) => sl<ListMyHostedEventsUseCase>(),
);
