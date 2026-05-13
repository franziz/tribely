import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/list_my_join_requests_usecase.dart';
import '../providers/join_requests_providers.dart';
import '../state/my_join_requests_state.dart';

/// Owns the joiner's "My Requests" tab state.
///
/// Optionally keyed by eventId (for when the tab is scoped to a single event).
/// When [eventId] is null, fetches all of the current user's join requests.
///
/// Kicks off a fetch on build so the page never starts at Initial.
class MyJoinRequestsController extends Notifier<MyJoinRequestsState> {
  MyJoinRequestsController(this.eventId);

  /// Optional event filter. Null means "all my requests".
  final String? eventId;

  @override
  MyJoinRequestsState build() {
    Future(() => _load());
    return const MyJoinRequestsLoading();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    state = const MyJoinRequestsLoading();

    final useCase = ref.read(listMyJoinRequestsUseCaseProvider);
    final params = ListMyJoinRequestsParams(eventId: eventId);
    final result = await useCase(params);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => MyJoinRequestsError(failure: failure),
      (items) => MyJoinRequestsLoaded(items: items),
    );
  }

  /// Retry after a transient error.
  Future<void> retry() => _load();

  /// Refresh the list (e.g. after a withdrawal is confirmed).
  Future<void> refresh() => _load();
}
