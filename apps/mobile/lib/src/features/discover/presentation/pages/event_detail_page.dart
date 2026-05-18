import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../events/domain/entities/event.dart';
import '../../../join_requests/domain/entities/join_request.dart';
import '../../../join_requests/domain/entities/join_request_with_requester.dart';
import '../../../join_requests/presentation/controllers/host_pending_list_controller.dart';
import '../../../join_requests/presentation/controllers/request_to_join_controller.dart';
import '../../../join_requests/presentation/providers/join_requests_providers.dart';
import '../../../join_requests/presentation/state/host_attending_list_state.dart';
import '../../../join_requests/presentation/state/host_pending_list_state.dart';
import '../../../join_requests/presentation/state/request_to_join_state.dart';
import '../../../join_requests/presentation/widgets/attending_request_row.dart';
import '../../../join_requests/presentation/widgets/confirm_join_sheet.dart';
import '../../../join_requests/presentation/widgets/decline_reason_sheet.dart';
import '../../../join_requests/presentation/widgets/pending_request_row.dart';
import '../../../../core/widgets/requester_profile_sheet.dart';
import '../../../../core/widgets/verified_pill.dart';
import '../providers/event_detail_providers.dart';
import '../state/event_detail_state.dart';

/// Read-only event detail page. Accessed via `/events/:id`.
///
/// Renders outside the bottom-nav shell (parentNavigatorKey: _rootNavigatorKey
/// in app_router.dart) so the nav bar is hidden on this screen (§E).
///
/// Non-host viewer CTA renders a sticky bottom bar with state-aware content:
///   - No existing request → "Request to join" button → ConfirmJoinSheet
///   - Pending request → StatusPill + "Sent to {host}" + "Withdraw request" link
///   - Approved request → StatusPill(approved), no action
///   - Declined request → StatusPill(declined) + decisionReason caption
///   - Withdrawn request (event not past) → PrimaryButton("Request to join") → re-request
///   - Event past / capacity full → disabled button + inline reason
///   - 403 EMAIL_NOT_VERIFIED → BannerMessage above bar + "Verify now" link
///
/// Host viewers see NO CTA (isHostViewer branch). B2 will wire the host-side
/// management UI; leave the slot intact via [_HostBranchPlaceholder].
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventDetailControllerProvider(eventId));
    // Sanctioned cross-feature presentation import per CLAUDE.md mobile rules —
    // session identity is genuinely app-global state.
    final session = ref.watch(sessionControllerProvider);

    // Hoist host-viewer check here so _LoadedBody stays a plain StatelessWidget.
    // isHostViewer = true only when the authenticated user is the event's host.
    // Unauthenticated → false → CTA renders (default). Per PM AC: no empty
    // button slot, no layout artifact when the host views their own event.
    final isHostViewer =
        session is SessionAuthenticated &&
        state is EventDetailLoaded &&
        session.session.user.id == state.event.hostId;

    // Watch join state at the outer Scaffold level so we can supply
    // bottomNavigationBar — Scaffold auto-reserves the exact inset, eliminating
    // the manual stickyBarHeight estimation that caused the overlap bug.
    // Only matters when the event is loaded and the viewer is not the host;
    // for all other states joinState is ignored.
    final joinState = state is EventDetailLoaded
        ? ref.watch(requestToJoinControllerProvider(eventId))
        : null;

    final effectiveRequest = switch (joinState) {
      RequestToJoinSubmitted(:final joinRequest) => joinRequest,
      RequestToJoinIdle(:final existingRequest) => existingRequest,
      RequestToJoinWithdrawing(:final withdrawingRequest) => withdrawingRequest,
      _ => null,
    };

    final emailNotVerifiedFailure = switch (joinState) {
      RequestToJoinFailed(:final failure)
          when failure is EmailNotVerifiedFailure =>
        failure,
      _ => null,
    };

    // Determine if we should show the sticky join bar.
    final showStickyBar =
        !isHostViewer && state is EventDetailLoaded && joinState != null;

    return Scaffold(
      backgroundColor: TribelyColors.paperSurface,
      // extendBodyBehindAppBar = true allows the hero image to bleed behind
      // the translucent AppBar on the loaded state.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _BackButton(),
        // Share action deferred per §E technical non-goals.
      ),
      // Scaffold.bottomNavigationBar auto-insets the body by the bar's exact
      // rendered height — no manual height estimation needed. This fixes the
      // sticky-bar overlap that occurred with the old Stack + stickyBarHeight()
      // approach (pending/declined content was ~126px; estimate was 100px).
      //
      // showStickyBar == true only when state is EventDetailLoaded and
      // joinState != null, so the pattern-match and null-check below are safe.
      bottomNavigationBar: switch (showStickyBar) {
        true when state is EventDetailLoaded && joinState != null =>
          _StickyJoinBar(
            event: state.event,
            joinState: joinState,
            effectiveRequest: effectiveRequest,
            emailNotVerifiedBanner: emailNotVerifiedFailure != null,
          ),
        _ => null,
      },
      body: switch (state) {
        EventDetailInitial() => const _LoadingSkeleton(),
        EventDetailLoading() => const _LoadingSkeleton(),
        EventDetailLoaded(:final event) => _LoadedBody(
          event: event,
          isHostViewer: isHostViewer,
          eventId: eventId,
        ),
        EventDetailError(:final failure) => _ErrorBody(
          message: failure.message,
          onRetry: () =>
              ref.read(eventDetailControllerProvider(eventId).notifier).retry(),
        ),
        EventDetailNotFound() => _NotFoundBody(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Back button
// ---------------------------------------------------------------------------

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton (§H detail variant)
// ---------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Hero: full-width 3:2 aspect ratio.
    final heroHeight = screenWidth * (2 / 3);

    // SingleChildScrollView prevents RenderFlex overflow when the skeleton
    // content (hero + metadata) exceeds the available Scaffold body height.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero skeleton — bleeds to top including safe area.
          SkeletonLoader(
            width: double.infinity,
            height: heroHeight + MediaQuery.paddingOf(context).top,
            borderRadius: 0,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line (~80% width)
                SkeletonLoader(
                  width: screenWidth * 0.80,
                  height: 28,
                  borderRadius: 6,
                ),
                const SizedBox(height: 12),
                // Meta line 1 (~60%)
                SkeletonLoader(
                  width: screenWidth * 0.60,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                // Meta line 2 (~50%)
                SkeletonLoader(
                  width: screenWidth * 0.50,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 24),
                // Description — wider line (~90%)
                SkeletonLoader(
                  width: screenWidth * 0.90,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: screenWidth * 0.80,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: screenWidth * 0.70,
                  height: 14,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.event,
    required this.isHostViewer,
    required this.eventId,
  });

  final Event event;

  /// True when the authenticated user is the event's host.
  final bool isHostViewer;

  final String eventId;

  @override
  Widget build(BuildContext context) {
    // Scrollable content only — the sticky CTA is now Scaffold.bottomNavigationBar
    // on the outer Scaffold, which auto-insets the body by its exact rendered
    // height. No Stack, no Positioned, no manual height estimation.
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroImage(event: event),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleBlock(event: event),
                const SizedBox(height: 20),
                _MetaRows(event: event),
                const SizedBox(height: 24),
                _AboutSection(description: event.description),
                const SizedBox(height: 16),
                _CapacityLine(event: event),
                const SizedBox(height: 8),
                // Host-only: pending requests section (B2a) + attending section.
                if (isHostViewer) ...[
                  const SizedBox(height: 16),
                  _PendingRequestsSection(eventId: eventId),
                  const SizedBox(height: 8),
                  _AttendingSection(eventId: eventId),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width hero image with a 3:2 aspect ratio (§E).
/// Category badge sits bottom-left overlaid on the image.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder backdrop — v1 has no imageUrl on the Event entity.
          // When the API ships imageUrl, swap in Image.network(...) here.
          Container(
            color: TribelyColors.paperBorderSubtle,
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: TribelyColors.paperInkSecondary.withValues(alpha: 0.4),
            ),
          ),
          // Gradient scrim so the AppBar back button stays legible.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Category badge — bottom-left (§E).
          Positioned(
            bottom: 12,
            left: 12,
            child: _CategoryBadge(category: event.category.displayName),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TribelyColors.paperPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: TribelyType.caption(TribelyColors.paperSurface),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Text(
      event.title,
      style: TribelyType.displayM(TribelyColors.paperInkPrimary),
    );
  }
}

/// Meta rows: datetime (SGT), venue, host name (§E).
/// Avatar deferred per v1 trim (API doesn't ship avatarUrl yet).
class _MetaRows extends StatelessWidget {
  const _MetaRows({required this.event});

  final Event event;

  // Singapore timezone offset: UTC+8.
  static final _sgtOffset = const Duration(hours: 8);

  @override
  Widget build(BuildContext context) {
    final startsAtSgt = event.startsAt.toUtc().add(_sgtOffset);
    final endsAtSgt = event.endsAt.toUtc().add(_sgtOffset);

    final dayOfWeek = DateFormat('EEE').format(startsAtSgt);
    final date = DateFormat('d MMM y').format(startsAtSgt);
    final startTime = DateFormat('h:mm a').format(startsAtSgt);
    final endTime = DateFormat('h:mm a').format(endsAtSgt);
    final datetimeLabel = '$dayOfWeek, $date · $startTime–$endTime SGT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetaRow(icon: Icons.schedule_outlined, label: datetimeLabel),
        const SizedBox(height: 10),
        _MetaRow(
          icon: Icons.location_on_outlined,
          label: '${event.venue.address}, ${event.venue.city}',
        ),
        const SizedBox(height: 10),
        // Host row: icon + "Hosted by <name>" + optional VerifiedPill (TRI-66).
        // Uses a Wrap so the pill collapses to zero width when isVerified=false
        // (VerifiedPill returns SizedBox.shrink()), producing no whitespace gap.
        // Mirrors the TRI-65 placement template (requester_profile_sheet.dart:201-216).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_outline,
              size: 20,
              color: TribelyColors.paperInkSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Hosted by ${event.hostDisplayName ?? 'Host'}',
                    style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
                  ),
                  VerifiedPill(isVerified: event.hostIsVerified),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: TribelyColors.paperInkSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    if (description == null || description!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this event',
          style: TribelyType.headline(TribelyColors.paperInkPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          description!,
          style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
        ),
      ],
    );
  }
}

/// Capacity copy rules (§E + brief V1 trims):
///   - goingCount absent → "{capacity} spots total" (graceful fallback)
///   - going == capacity → "Full" in paperAccent
///   - going == capacity - 1 → "1 spot left" in paperAccent
///   - otherwise → "{going} of {capacity} spots filled"
///
/// The Event entity in v1 has no goingCount field — we always hit the
/// fallback case. When the API ships goingCount, add it to the entity and
/// the branch below will light up.
class _CapacityLine extends StatelessWidget {
  const _CapacityLine({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    // v1: goingCount is not on the entity. Render capacity-only gracefully.
    final label = '${event.capacity} spots total';
    final color = TribelyColors.paperInkSecondary;

    return Row(
      children: [
        Icon(Icons.group_outlined, size: 20, color: color),
        const SizedBox(width: 10),
        Text(label, style: TribelyType.bodyM(color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pending requests section — host branch only (B2a)
// ---------------------------------------------------------------------------

/// Section that renders the host's list of pending join requests inline within
/// the event detail scroll body.
///
/// Hidden entirely when zero pending (PM AC: no empty section header).
/// Error handling: full-load failures show a [BannerMessage] with retry;
/// action-level failures (approve/decline) show an inline section banner while
/// keeping the row list intact.
class _PendingRequestsSection extends ConsumerStatefulWidget {
  const _PendingRequestsSection({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_PendingRequestsSection> createState() =>
      _PendingRequestsSectionState();
}

class _PendingRequestsSectionState
    extends ConsumerState<_PendingRequestsSection> {
  // Track which rows have been "dismissed" (approved/declined) so we can
  // run the slide-out animation before removal.
  final Set<String> _dismissingIds = {};

  @override
  Widget build(BuildContext context) {
    final pendingState = ref.watch(
      hostPendingListControllerProvider(widget.eventId),
    );
    final controller = ref.read(
      hostPendingListControllerProvider(widget.eventId).notifier,
    );

    // Listen for race-condition conflicts: show a toast then clear.
    ref.listen<HostPendingListState>(
      hostPendingListControllerProvider(widget.eventId),
      (prev, next) {
        if (next is HostPendingListLoaded && next.raceConflictId != null) {
          controller.clearRaceConflict();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This request was already handled.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );

    return switch (pendingState) {
      HostPendingListLoading() => const _PendingLoadingRow(),
      HostPendingListError(:final failure) => _PendingErrorSection(
        message: failure.message,
        onRetry: controller.retry,
      ),
      HostPendingListLoaded(items: final items) when items.isEmpty =>
        const SizedBox.shrink(), // hide entire section at zero pending
      HostPendingListLoaded(
        :final items,
        :final sectionError,
        :final actionInFlightId,
      ) =>
        _PendingLoadedSection(
          eventId: widget.eventId,
          items: items,
          sectionError: sectionError,
          actionInFlightId: actionInFlightId,
          dismissingIds: _dismissingIds,
          onApprove: (id) => _handleApprove(controller, id),
          onDeclineRequest: (item) =>
              _handleDeclineRequest(context, controller, item),
          onClearSectionError: controller.clearSectionError,
          onTapRequester: (userId) =>
              showRequesterProfileSheet(context, userId),
        ),
    };
  }

  Future<void> _handleApprove(
    HostPendingListController controller,
    String joinRequestId,
  ) async {
    setState(() => _dismissingIds.add(joinRequestId));
    await controller.approve(joinRequestId);
    if (mounted) setState(() => _dismissingIds.remove(joinRequestId));
  }

  Future<void> _handleDeclineRequest(
    BuildContext context,
    HostPendingListController controller,
    JoinRequestWithRequester item,
  ) async {
    await showDeclineReasonSheet(
      context,
      requesterDisplayName: item.requester.displayName,
      onSubmit: (reason) async {
        setState(() => _dismissingIds.add(item.joinRequest.id));
        await controller.decline(item.joinRequest.id, reason: reason);
        if (mounted) setState(() => _dismissingIds.remove(item.joinRequest.id));
        // If there's a sectionError after decline, return it; otherwise null.
        final st = ref.read(hostPendingListControllerProvider(widget.eventId));
        if (st is HostPendingListLoaded && st.sectionError != null) {
          return st.sectionError;
        }
        return null;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pending section sub-widgets
// ---------------------------------------------------------------------------

class _PendingLoadingRow extends StatelessWidget {
  const _PendingLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PendingErrorSection extends StatelessWidget {
  const _PendingErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerMessage(
          message: message,
          action: BannerAction(label: 'Retry', onTap: onRetry),
        ),
      ],
    );
  }
}

class _PendingLoadedSection extends StatelessWidget {
  const _PendingLoadedSection({
    required this.eventId,
    required this.items,
    required this.sectionError,
    required this.actionInFlightId,
    required this.dismissingIds,
    required this.onApprove,
    required this.onDeclineRequest,
    required this.onClearSectionError,
    required this.onTapRequester,
  });

  final String eventId;
  final List<JoinRequestWithRequester> items;
  final String? sectionError;
  final String? actionInFlightId;
  final Set<String> dismissingIds;
  final ValueChanged<String> onApprove;
  final ValueChanged<JoinRequestWithRequester> onDeclineRequest;
  final VoidCallback onClearSectionError;
  final ValueChanged<String> onTapRequester;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: "REQUESTS (N)" — caption/13, paperInkSecondary,
        // uppercase. Per PM AC: hidden at zero (caller guards this).
        Semantics(
          header: true,
          child: Text(
            'REQUESTS (${items.length})',
            style: TribelyType.caption(
              TribelyColors.paperInkSecondary,
            ).copyWith(letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        // Inline section error (action failures: network, capacity-full).
        if (sectionError != null) ...[
          BannerMessage(message: sectionError!, onDismiss: onClearSectionError),
          const SizedBox(height: 12),
        ],
        // Pending rows with slide-out animation on removal.
        ...items.map((item) {
          final isDismissing = dismissingIds.contains(item.joinRequest.id);
          return _AnimatedPendingRow(
            key: ValueKey(item.joinRequest.id),
            item: item,
            isDismissing: isDismissing,
            isInFlight: actionInFlightId == item.joinRequest.id,
            onApprove: () => onApprove(item.joinRequest.id),
            onDecline: (_) => onDeclineRequest(item),
            onTapRequester: () => onTapRequester(item.requester.id),
          );
        }),
      ],
    );
  }
}

/// Wraps [PendingRequestRow] in a slide-left + fade-out animation when
/// [isDismissing] transitions to true.
class _AnimatedPendingRow extends StatefulWidget {
  const _AnimatedPendingRow({
    required this.item,
    required this.isDismissing,
    required this.isInFlight,
    required this.onApprove,
    required this.onDecline,
    required this.onTapRequester,
    super.key,
  });

  final JoinRequestWithRequester item;
  final bool isDismissing;
  final bool isInFlight;
  final VoidCallback onApprove;
  final ValueChanged<String> onDecline;
  final VoidCallback onTapRequester;

  @override
  State<_AnimatedPendingRow> createState() => _AnimatedPendingRowState();
}

class _AnimatedPendingRowState extends State<_AnimatedPendingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: TribelyMotion.easeIn));
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: TribelyMotion.easeIn));
  }

  @override
  void didUpdateWidget(_AnimatedPendingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDismissing && !oldWidget.isDismissing) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: PendingRequestRow(
          item: widget.item,
          onApprove: widget.onApprove,
          onDecline: widget.onDecline,
          isInFlight: widget.isInFlight,
          onTapRequester: widget.onTapRequester,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attending section — host branch only
// ---------------------------------------------------------------------------

/// Section that renders the host's list of approved (attending) join requests
/// inline within the event detail scroll body.
///
/// Hidden entirely when N=0 (PM AC: no empty section header).
/// Automatically refreshed when [HostPendingListController.approve] succeeds
/// via [ref.invalidate(hostAttendingListControllerProvider(eventId))].
class _AttendingSection extends ConsumerWidget {
  const _AttendingSection({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendingState = ref.watch(
      hostAttendingListControllerProvider(eventId),
    );
    final controller = ref.read(
      hostAttendingListControllerProvider(eventId).notifier,
    );

    return switch (attendingState) {
      HostAttendingListLoading() => const SizedBox.shrink(),
      HostAttendingListError(:final failure) => _AttendingErrorSection(
        message: failure.message,
        onRetry: controller.retry,
      ),
      HostAttendingListLoaded(items: final items) when items.isEmpty =>
        const SizedBox.shrink(), // hide when no attendees
      HostAttendingListLoaded(:final items) => _AttendingLoadedSection(
        items: items,
      ),
    };
  }
}

class _AttendingErrorSection extends StatelessWidget {
  const _AttendingErrorSection({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerMessage(
          message: message,
          action: BannerAction(label: 'Retry', onTap: onRetry),
        ),
      ],
    );
  }
}

class _AttendingLoadedSection extends StatelessWidget {
  const _AttendingLoadedSection({required this.items});

  final List<JoinRequestWithRequester> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: "ATTENDING (N)" — caption/13, paperInkSecondary,
        // uppercase. Matches the "REQUESTS (N)" pattern in the pending section.
        Semantics(
          header: true,
          child: Text(
            'ATTENDING (${items.length})',
            style: TribelyType.caption(
              TribelyColors.paperInkSecondary,
            ).copyWith(letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => AttendingRequestRow(
            key: ValueKey(item.joinRequest.id),
            item: item,
            onTapRequester: () =>
                showRequesterProfileSheet(context, item.requester.id),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky bottom bar — state-aware, non-host branch only (B1a)
// ---------------------------------------------------------------------------

/// Sticky bottom bar for non-host viewers. Renders one of:
///   - No request: PrimaryButton("Request to join") → opens ConfirmJoinSheet
///   - Pending: StatusPill(pending) + "Sent to {host}" + withdraw link
///   - Approved: StatusPill(approved)
///   - Declined: StatusPill(declined) + decisionReason caption
///   - Withdrawn (event not past): PrimaryButton("Request to join") → re-request
///   - Event past or capacity full: disabled PrimaryButton + inline reason
///   - EmailNotVerified: BannerMessage above bar + "Verify now" link
///
/// [emailNotVerifiedBanner]: when true, shows the verify-email inline banner
/// above the button instead of navigating the user away.
class _StickyJoinBar extends ConsumerWidget {
  const _StickyJoinBar({
    required this.event,
    required this.joinState,
    required this.effectiveRequest,
    required this.emailNotVerifiedBanner,
  });

  final Event event;
  final RequestToJoinState joinState;
  final JoinRequest? effectiveRequest;
  final bool emailNotVerifiedBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      requestToJoinControllerProvider(event.id).notifier,
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final hostName = event.hostDisplayName ?? 'Host';

    // Determine whether the event is past or cancelled.
    final now = DateTime.now().toUtc();
    final isEventPast =
        event.endsAt.toUtc().isBefore(now) || event.status == 'cancelled';

    Widget content;

    if (emailNotVerifiedBanner) {
      content = _VerifyEmailBanner(event: event, controller: controller);
    } else if (effectiveRequest != null &&
        effectiveRequest!.status == JoinRequestStatus.withdrawn &&
        !isEventPast) {
      // Withdrawn → re-request CTA. PM verdict: same affordance as never-
      // requested; tapping opens ConfirmJoinSheet which creates a new
      // JoinRequest. No cooldown, no per-event cap.
      // Note: capacity-full / cancelled are covered by isEventPast above.
      final isSubmitting = joinState is RequestToJoinSubmitting;
      content = PrimaryButton(
        label: 'Request to join',
        state: isSubmitting
            ? PrimaryButtonState.loading
            : PrimaryButtonState.idle,
        onPressed: isSubmitting
            ? null
            : () => showConfirmJoinSheet(
                context,
                eventId: event.id,
                hostName: hostName,
                eventTitle: event.title,
                startsAt: event.startsAt,
                endsAt: event.endsAt,
              ),
      );
    } else if (effectiveRequest != null) {
      content = _RequestStatusContent(
        request: effectiveRequest!,
        hostName: hostName,
        controller: controller,
        isWithdrawing: joinState is RequestToJoinWithdrawing,
      );
    } else if (isEventPast) {
      // Disabled CTA: event has ended. Per feedback_disabled_cta_must_explain_blocker —
      // never silently disable; always render inline reason text.
      content = const _DisabledCta(reason: 'Event has ended');
    } else {
      // No existing request: show the primary CTA.
      final isSubmitting = joinState is RequestToJoinSubmitting;
      content = PrimaryButton(
        label: 'Request to join',
        state: isSubmitting
            ? PrimaryButtonState.loading
            : PrimaryButtonState.idle,
        onPressed: isSubmitting
            ? null
            : () => showConfirmJoinSheet(
                context,
                eventId: event.id,
                hostName: hostName,
                eventTitle: event.title,
                startsAt: event.startsAt,
                endsAt: event.endsAt,
              ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurface,
        border: Border(
          top: BorderSide(color: TribelyColors.paperBorderSubtle, width: 1),
        ),
      ),
      child: content,
    );
  }
}

/// StatusPill + caption + optional withdraw link for pending/approved/
/// declined/withdrawn request states.
///
/// Note: the Withdrawn-with-re-request CTA is handled upstream in
/// [_StickyJoinBar] — this widget only sees Withdrawn when the event is
/// past/cancelled (in which case no re-request action is shown).
class _RequestStatusContent extends StatelessWidget {
  const _RequestStatusContent({
    required this.request,
    required this.hostName,
    required this.controller,
    required this.isWithdrawing,
  });

  final JoinRequest request;
  final String hostName;
  final RequestToJoinController controller;
  final bool isWithdrawing;

  @override
  Widget build(BuildContext context) {
    final pillState = switch (request.status) {
      JoinRequestStatus.pending => StatusPillState.pending,
      JoinRequestStatus.approved => StatusPillState.approved,
      JoinRequestStatus.declined => StatusPillState.declined,
      JoinRequestStatus.withdrawn => StatusPillState.withdrawn,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Centred pill.
        Center(child: StatusPill(state: pillState)),
        // Context caption.
        if (request.status == JoinRequestStatus.pending) ...[
          const SizedBox(height: 4),
          Text(
            'Sent to $hostName',
            textAlign: TextAlign.center,
            style: TribelyType.caption(TribelyColors.paperInkSecondary),
          ),
          const SizedBox(height: 8),
          // Withdraw text link.
          Center(
            child: isWithdrawing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : GestureDetector(
                    onTap: () => _showWithdrawDialog(context),
                    child: Text(
                      'Withdraw request',
                      style: TribelyType.caption(
                        TribelyColors.paperPrimary,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
          ),
        ] else if (request.status == JoinRequestStatus.declined &&
            request.decisionReason != null) ...[
          const SizedBox(height: 4),
          Text(
            request.decisionReason!,
            textAlign: TextAlign.center,
            style: TribelyType.caption(TribelyColors.paperInkSecondary),
          ),
        ],
      ],
    );
  }

  Future<void> _showWithdrawDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw your request?'),
        content: const Text(
          'You can request again later if you change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.withdraw(request.id);
    }
  }
}

/// Disabled CTA with inline reason text.
/// Per feedback_disabled_cta_must_explain_blocker — always explain why disabled.
class _DisabledCta extends StatelessWidget {
  const _DisabledCta({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          label: reason,
          onPressed: null,
          state: PrimaryButtonState.idle,
        ),
      ],
    );
  }
}

/// EMAIL_NOT_VERIFIED inline banner. Shown above the (disabled) CTA when the
/// server returns a 403 with code EMAIL_NOT_VERIFIED.
class _VerifyEmailBanner extends StatelessWidget {
  const _VerifyEmailBanner({required this.event, required this.controller});

  final Event event;
  final RequestToJoinController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BannerMessage(
          message: 'Verify your email to request events',
          action: BannerAction(
            label: 'Verify now',
            onTap: () => context.push('/verify-email'),
          ),
        ),
        const SizedBox(height: 12),
        const PrimaryButton(
          label: 'Request to join',
          onPressed: null,
          state: PrimaryButtonState.idle,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error body (§I)
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: TribelyColors.paperInkSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Not-found body
// ---------------------------------------------------------------------------

class _NotFoundBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 56,
                color: TribelyColors.paperInkSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'This event no longer exists.',
                textAlign: TextAlign.center,
                style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
