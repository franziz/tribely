import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../domain/entities/user_capabilities.dart';
import '../../domain/repositories/user_capabilities_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure bridge
// ---------------------------------------------------------------------------

/// Lifts [UserCapabilitiesRepository] (registered in get_it) into the Riverpod
/// graph so capability consumers can resolve it uniformly via [ref].
final _userCapabilitiesRepositoryProvider =
    Provider<UserCapabilitiesRepository>(
      (_) => sl<UserCapabilitiesRepository>(),
    );

// ---------------------------------------------------------------------------
// Capability provider
// ---------------------------------------------------------------------------

/// Fetches and caches the authenticated user's capability flags for the
/// current session.
///
/// **Failure path returns `canPostPrivateVenue: false`** — the safer default.
/// If the server is unreachable, first-time-host warnings are shown rather
/// than silently bypassed. This prevents a capability-API outage from
/// accidentally granting new users the private-venue permission.
///
/// Uses plain [FutureProvider] (not autoDispose) because capabilities are
/// stable per session. Riverpod's natural FutureProvider caching avoids
/// repeated network calls; no additional caching layer is needed.
final myCapabilitiesProvider = FutureProvider<UserCapabilities>((ref) async {
  final repo = ref.watch(_userCapabilitiesRepositoryProvider);
  final result = await repo.getMyCapabilities();
  return result.fold(
    (failure) => const UserCapabilities.restricted(),
    (caps) => caps,
  );
});
