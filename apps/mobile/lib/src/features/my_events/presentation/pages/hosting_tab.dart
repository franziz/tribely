import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../discover/domain/entities/discover_filters.dart';
import '../../../discover/domain/usecases/browse_events_usecase.dart';
import '../../../../core/providers/browse_events_usecase_provider.dart';
import '../../../events/domain/entities/event.dart';
import '../controllers/hosting_pending_count_controller.dart';

/// Content for the "Hosting" tab in [MyEventsPage].
///
/// Lists events the current user hosts via [GET /events?hostUserId=me].
/// Per-row pending count badge is sourced from [HostingPendingCountController].
///
/// States:
///   - Loading: CircularProgressIndicator centred.
///   - Error: BannerMessage with retry.
///   - Empty: copy + "Create an event" PrimaryButton.
///   - Loaded: RefreshIndicator-wrapped ListView with per-row pending captions.
class HostingTab extends ConsumerStatefulWidget {
  const HostingTab({super.key});

  @override
  ConsumerState<HostingTab> createState() => _HostingTabState();
}

class _HostingTabState extends ConsumerState<HostingTab> {
  _HostingTabViewState _viewState = const _HostingTabLoading();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _viewState = const _HostingTabLoading());

    try {
      final session = ref.read(sessionControllerProvider);
      if (session is! SessionAuthenticated) {
        setState(
          () => _viewState = const _HostingTabError(
            message: 'Sign in to see your hosted events.',
          ),
        );
        return;
      }

      final useCase = ref.read(browseEventsUseCaseProvider);
      final result = await useCase(
        const BrowseEventsParams(filters: DiscoverFilters(hostUserId: 'me')),
      );

      if (!mounted) return;

      result.fold(
        (failure) => setState(
          () => _viewState = _HostingTabError(message: failure.message),
        ),
        (page) =>
            setState(() => _viewState = _HostingTabLoaded(events: page.events)),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _viewState = const _HostingTabError(
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    return switch (_viewState) {
      _HostingTabLoading() => const _LoadingBody(),
      _HostingTabError(:final message) => _ErrorBody(
        message: message,
        onRetry: _load,
      ),
      _HostingTabLoaded(:final events) when events.isEmpty => _EmptyBody(),
      _HostingTabLoaded(:final events) => _LoadedBody(
        events: events,
        onRefresh: _refresh,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Local view-state sealed hierarchy (not exposed outside this file)
// ---------------------------------------------------------------------------

sealed class _HostingTabViewState extends Equatable {
  const _HostingTabViewState();
}

final class _HostingTabLoading extends _HostingTabViewState {
  const _HostingTabLoading();

  @override
  List<Object?> get props => const [];
}

final class _HostingTabError extends _HostingTabViewState {
  const _HostingTabError({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}

final class _HostingTabLoaded extends _HostingTabViewState {
  const _HostingTabLoaded({required this.events});
  final List<Event> events;

  @override
  List<Object?> get props => [events];
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BannerMessage(
            message: message,
            action: BannerAction(label: 'Retry', onTap: onRetry),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "You haven't created any events yet.",
              textAlign: TextAlign.center,
              style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: PrimaryButton(
                label: 'Create an event',
                onPressed: () => context.push('/events/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded list with pull-to-refresh
// ---------------------------------------------------------------------------

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.events, required this.onRefresh});

  final List<Event> events;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventIds = events.map((e) => e.id).toList();
    final pendingState = ref.watch(
      hostingPendingCountControllerProvider(eventIds),
    );

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate the pending count so it refetches on pull-to-refresh.
        ref.invalidate(hostingPendingCountControllerProvider(eventIds));
        await onRefresh();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (context, _) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: TribelyColors.paperBorderSubtle,
        ),
        itemBuilder: (context, index) {
          final event = events[index];
          final pendingCount = pendingState.perEvent[event.id] ?? 0;
          return _HostingEventRow(event: event, pendingCount: pendingCount);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual hosted event row
// ---------------------------------------------------------------------------

/// A row in the Hosting tab list.
///
/// Shows: event thumb placeholder + title + SGT date + capacity caption.
/// When [pendingCount] > 0, adds a leading 6dp paperAccent dot + caption
/// "● [N] pending" (caption/13, paperAccent).
class _HostingEventRow extends StatelessWidget {
  const _HostingEventRow({required this.event, required this.pendingCount});

  final Event event;
  final int pendingCount;

  // SGT: UTC+8
  static const _sgtOffset = Duration(hours: 8);

  @override
  Widget build(BuildContext context) {
    final startsAtSgt = event.startsAt.toUtc().add(_sgtOffset);
    final dateLabel = _formatDate(startsAtSgt);
    final hasPending = pendingCount > 0;

    return Semantics(
      button: true,
      label: hasPending
          ? '${event.title}, $pendingCount pending request${pendingCount == 1 ? '' : 's'}'
          : event.title,
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Event thumbnail placeholder.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: TribelyColors.paperInkSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TribelyType.bodyM(
                        TribelyColors.paperInkPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TribelyType.caption(
                        TribelyColors.paperInkSecondary,
                      ),
                    ),
                    Text(
                      '${event.capacity} spots',
                      style: TribelyType.caption(
                        TribelyColors.paperInkSecondary,
                      ),
                    ),
                    // Pending badge — only when > 0.
                    if (hasPending) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 6dp accent dot.
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TribelyColors.paperAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pendingCount pending',
                            style: TribelyType.caption(
                              TribelyColors.paperAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: TribelyColors.paperInkSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = DateFormat('EEE, d MMM').format(dt);
    final time = DateFormat('h a').format(dt);
    return '$day · $time';
  }
}
