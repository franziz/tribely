import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/list_my_hosted_events_usecase_provider.dart';
import '../../../discover/domain/usecases/list_my_hosted_events_usecase.dart';
import '../state/hosting_tab_state.dart';

// A12: params instance extracted to file-level const to avoid inline
// instantiation at the call site.
const _emptyParams = ListMyHostedEventsParams();

/// Provider — autoDispose so state is discarded when the Hosting tab leaves
/// the widget tree (e.g. the user navigates away from MyEventsPage).
final hostingTabControllerProvider =
    NotifierProvider.autoDispose<HostingTabController, HostingTabState>(
      HostingTabController.new,
    );

/// Owns the Hosting tab's load state.
///
/// Kicks off a fetch on build so the tab never starts blank.
/// Exposes [load] for initial fetch and [refresh] for pull-to-refresh.
///
/// Failure mapping mirrors the previous [_HostingTabState._mapFailureToUserCopy]
/// logic: raw API error strings are never surfaced to the user.
class HostingTabController extends Notifier<HostingTabState> {
  @override
  HostingTabState build() {
    Future(() => load());
    return const HostingTabLoading();
  }

  /// Fetch the current user's hosted events. Also used as the initial load.
  Future<void> load() async {
    if (!ref.mounted) return;
    state = const HostingTabLoading();

    final useCase = ref.read(listMyHostedEventsUseCaseProvider);
    final result = await useCase(_emptyParams);

    if (!ref.mounted) return;
    state = result.fold(
      (failure) => HostingTabError(message: _mapFailureToUserCopy(failure)),
      (events) => HostingTabLoaded(events: events),
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
    AuthFailure() => 'Sign in to see events you\'re hosting.',
    _ => 'Something went wrong. Please try again.',
  };
}
