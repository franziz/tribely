import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/get_event_detail_usecase.dart';
import '../providers/event_detail_providers.dart';
import '../state/event_detail_state.dart';

/// Owns the lifecycle of a single event detail view.
///
/// Keyed by [eventId] via [NotifierProvider.family] — each event ID gets its
/// own isolated state + auto-dispose when the detail page leaves the tree.
///
/// Build kicks off the fetch immediately so the page never starts at Initial.
/// The caller must not pass [eventId] as an explicit Params to the provider —
/// the controller reads it from its constructor arg, consistent with the
/// [UserProfileController] pattern already established in this codebase.
class EventDetailController extends Notifier<EventDetailState> {
  EventDetailController(this.eventId);
  final String eventId;

  @override
  EventDetailState build() {
    // Kick off fetch asynchronously — avoids triggering a state change during
    // build, which Riverpod 3.x forbids. Mirrors the UserProfileController
    // pattern at features/users/presentation/controllers/user_profile_controller.dart.
    Future(() => _load());
    return const EventDetailLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = const EventDetailLoading();

    final useCase = ref.read(getEventDetailUseCaseProvider);
    final params = GetEventDetailParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => switch (failure) {
        NotFoundFailure() => const EventDetailNotFound(),
        _ => EventDetailError(failure),
      },
      EventDetailLoaded.new,
    );
  }

  /// Retry after a transient error. Not applicable to NotFound (permanent).
  Future<void> retry() async {
    await _load();
  }
}
