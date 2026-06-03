import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../events/domain/entities/event.dart';
import '../controllers/hosting_pending_count_controller.dart';
import '../controllers/hosting_tab_controller.dart';
import '../state/hosting_tab_state.dart';

/// Content for the "Hosting" tab in [MyEventsPage].
///
/// Lists events the current user hosts via [GET /me/events].
/// Per-row pending count badge is sourced from [HostingPendingCountController].
///
/// States:
///   - Loading: CircularProgressIndicator centred.
///   - Error: BannerMessage with retry.
///   - Empty: copy + "Create an event" PrimaryButton.
///   - Loaded: RefreshIndicator-wrapped ListView with per-row pending captions.
class HostingTab extends ConsumerWidget {
  const HostingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostingTabControllerProvider);
    final controller = ref.read(hostingTabControllerProvider.notifier);

    return switch (state) {
      HostingTabLoading() => const _LoadingBody(),
      HostingTabError(:final message) => _ErrorBody(
        message: message,
        onRetry: controller.load,
      ),
      HostingTabLoaded(:final events) when events.isEmpty => _EmptyBody(),
      HostingTabLoaded(:final events) => _LoadedBody(
        events: events,
        onRefresh: controller.refresh,
      ),
    };
  }
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
    final key = (events.map((e) => e.id).toList()..sort()).join(',');
    final pendingState = ref.watch(hostingPendingCountControllerProvider(key));

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate the pending count so it refetches on pull-to-refresh.
        ref.invalidate(hostingPendingCountControllerProvider(key));
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
    final isCancelled = event.status == 'cancelled';
    final hasPending = !isCancelled && pendingCount > 0;

    // Semantics label priority:
    //   1. Cancelled → announce status, not pending count.
    //   2. Pending requests → include count.
    //   3. Default → event title only.
    final semanticsLabel = isCancelled
        ? '${event.title}, cancelled'
        : hasPending
            ? '${event.title}, $pendingCount pending request${pendingCount == 1 ? '' : 's'}'
            : event.title;

    return Semantics(
      button: true,
      label: semanticsLabel,
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
                    // Cancelled badge — replaces pending count for cancelled events.
                    if (isCancelled) ...[
                      const SizedBox(height: 2),
                      const StatusPill(
                        state: StatusPillState.cancelled,
                        semanticsPrefix: 'Event status',
                      ),
                    ] else if (hasPending) ...[
                      // Pending badge — only when > 0 and not cancelled.
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
