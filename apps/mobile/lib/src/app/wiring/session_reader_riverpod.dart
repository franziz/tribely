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
/// Lives in `app/wiring/` (the composition root) because it binds a domain
/// port ([SessionReader]) to a presentation-layer provider
/// ([sessionControllerProvider]). This is above both `core/` and `features/`
/// in the dependency direction: Core ← Infrastructure ← Presentation.
/// A file in `core/` that imports from `features/.../presentation/` would
/// invert that direction.
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

/// Provider that exposes [SessionReader] to use cases that depend on it.
///
/// Lives in `app/wiring/` (not `core/`) because the concrete adapter imports
/// [auth/presentation] — placing it in `core/` would make `core/` depend on
/// a feature's presentation layer, inverting the dependency direction.
final sessionReaderProvider = Provider<SessionReader>(
  (ref) => SessionReaderRiverpod(ref),
);
