import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/list_my_hosted_events_usecase_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../discover/domain/usecases/list_my_hosted_events_usecase.dart';
import '../state/my_events_state.dart';

// A12: params instance extracted to file-level const to avoid inline
// instantiation at the call site.
const _emptyParams = ListMyHostedEventsParams();

/// Provider — autoDispose so state is discarded when MyEventsPage leaves the
/// widget tree (e.g. the user navigates away).
final myEventsControllerProvider =
    NotifierProvider.autoDispose<MyEventsController, MyEventsState>(
      MyEventsController.new,
    );

/// Owns the hosted-event-IDs load for [MyEventsPage].
///
/// Session-gated: [build] watches [sessionControllerProvider] so the
/// controller auto-rebuilds whenever the session flips. The watch drives
/// these transitions automatically:
///
/// - [SessionAuthenticated]   → schedules [load()], returns [MyEventsLoading].
/// - [SessionUnauthenticated] → returns [MyEventsSignedOut], fires NO fetch.
/// - [SessionRestoring]       → returns [MyEventsLoading] (silent hold), fires NO fetch.
///
/// The controller maps [List<Event>] → [List<String>] of IDs because the page
/// only needs IDs to derive the pending-count badge key — carrying full entity
/// objects would be over-scoped here.
class MyEventsController extends Notifier<MyEventsState> {
  @override
  MyEventsState build() {
    final session = ref.watch(sessionControllerProvider);
    return switch (session) {
      SessionAuthenticated() => _scheduleLoad(),
      SessionUnauthenticated() => const MyEventsSignedOut(),
      // SessionRestoring — silent hold; do NOT schedule a load.
      _ => const MyEventsLoading(),
    };
  }

  /// Schedules [load()] via a post-build microtask and returns [MyEventsLoading].
  MyEventsState _scheduleLoad() {
    Future(() => load());
    return const MyEventsLoading();
  }

  /// Fetch the current user's hosted event IDs.
  Future<void> load() async {
    if (!ref.mounted) return;
    state = const MyEventsLoading();

    final useCase = ref.read(listMyHostedEventsUseCaseProvider);
    final result = await useCase(_emptyParams);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => MyEventsError(message: _mapFailureToUserCopy(failure)),
      (events) =>
          MyEventsLoaded(hostedEventIds: events.map((e) => e.id).toList()),
    );
  }

  /// Pull-to-refresh — re-invokes the full load.
  Future<void> refresh() => load();

  /// Maps a [Failure] to user-facing copy.
  ///
  /// Raw [failure.message] values from the API are NEVER exposed to the UI —
  /// they are server-internal strings that mean nothing to users.
  static String _mapFailureToUserCopy(Failure failure) => switch (failure) {
    NetworkFailure() => 'No connection. Pull down to retry.',
    AuthFailure() => 'Sign in to see your events.',
    _ => 'Something went wrong. Please try again.',
  };
}
