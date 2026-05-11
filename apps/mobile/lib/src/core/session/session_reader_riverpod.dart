import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/ports/session_reader.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/state/auth_state.dart';

/// Riverpod-backed implementation of [SessionReader].
///
/// Reads [sessionControllerProvider] synchronously via [Ref.read]. This is
/// intentional: [SessionReader.currentUserId] is a point-in-time snapshot, not
/// a reactive stream. Callers that need reactivity should watch
/// [sessionControllerProvider] directly (e.g. go_router redirect, widgets).
///
/// Lives in `core/session/` because it is cross-cutting infrastructure: the
/// [SessionReader] port itself is auth-domain, but this Riverpod bridge is
/// consumed by features other than auth (e.g. users). Per EL ruling, a
/// `core/` provider may read a feature's presentation provider — the provider
/// IS the feature's public API at the Riverpod boundary.
class SessionReaderRiverpod implements SessionReader {
  SessionReaderRiverpod(this._ref);

  final Ref _ref;

  @override
  String? get currentUserId {
    final session = _ref.read(sessionControllerProvider);
    return switch (session) {
      SessionAuthenticated(:final session) => session.user.id,
      _ => null,
    };
  }
}

/// Provider that exposes [SessionReader] to the service locator and use cases.
///
/// Defined in `core/` (not `auth/presentation/`) because the concrete impl is
/// consumed cross-feature. Use cases receive [SessionReader] via constructor
/// injection from get_it — get_it resolves it from [sessionReaderProvider] at
/// startup.
final sessionReaderProvider = Provider<SessionReader>(
  (ref) => SessionReaderRiverpod(ref),
);
