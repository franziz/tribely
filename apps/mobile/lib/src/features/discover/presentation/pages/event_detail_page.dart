import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/category_image_placeholder.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../auth/presentation/state/sign_in_intent.dart';
import '../../../auth/presentation/widgets/sign_in_gate_sheet.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/string_assets/cancel_event_copy.dart';
import '../../../events/presentation/widgets/cancel_event_sheet.dart';
import '../../../join_requests/domain/entities/join_request.dart';
import '../../../join_requests/domain/entities/join_request_with_requester.dart';
import '../../../join_requests/presentation/controllers/host_pending_list_controller.dart';
import '../../../join_requests/presentation/controllers/request_to_join_controller.dart';
import '../../../join_requests/presentation/providers/join_requests_providers.dart';
import '../../../join_requests/presentation/state/host_attending_list_state.dart';
import '../../../join_requests/presentation/state/host_pending_list_state.dart';
import '../../../join_requests/presentation/state/request_to_join_state.dart';
import '../../../join_requests/presentation/controllers/host_attending_list_controller.dart';
import '../../../join_requests/presentation/widgets/attending_request_row.dart';
import '../../../join_requests/presentation/widgets/confirm_join_sheet.dart';
import '../../../join_requests/presentation/widgets/decline_reason_sheet.dart';
import '../../../join_requests/presentation/widgets/pending_request_row.dart';
import '../../../join_requests/presentation/widgets/remove_attendee_sheet.dart';
import '../../../join_requests/presentation/widgets/safety_reminder_sheet.dart';
import '../../../my_events/presentation/controllers/hosting_tab_controller.dart';
import '../../../reviews/domain/entities/review_eligibility.dart';
import '../../../reviews/presentation/providers/review_providers.dart';
import '../../../users/presentation/providers/capability_providers.dart';
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
///   - 403 EMAIL_NOT_VERIFIED / PHONE_NOT_VERIFIED → BannerMessage above bar + "Verify now" link
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

    final verificationFailure = switch (joinState) {
      RequestToJoinFailed(:final failure)
          when failure is EmailNotVerifiedFailure ||
              failure is PhoneNotVerifiedFailure =>
        failure,
      _ => null,
    };

    // Determine if we should show the sticky join bar.
    final showStickyBar =
        !isHostViewer && state is EventDetailLoaded && joinState != null;

    // Show the host kebab only when the viewer is the host AND the event is
    // not yet cancelled. isHostViewer already implies state is EventDetailLoaded,
    // so we use a switch expression to safely downcast without a redundant check.
    final showHostKebab = switch (state) {
      EventDetailLoaded(:final event) when isHostViewer =>
        event.status != 'cancelled',
      _ => false,
    };

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
        // Host kebab — shown only when the viewer is the host AND the event
        // is not yet cancelled (already-cancelled events have no cancel action).
        actions: showHostKebab ? [_HostKebabButton(eventId: eventId)] : null,
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
            verificationFailure: verificationFailure,
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
    // Hero: full-width 16:9 aspect ratio (designer-confirmed TRI-49 Brief 4).
    final heroHeight = screenWidth * 9 / 16;

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
                // Cancelled badge — shown to ALL viewers (host and non-host)
                // when the event status is 'cancelled'. Canonical event-level
                // indicator; 12dp vertical spacing on both sides.
                if (event.status == 'cancelled') ...[
                  const SizedBox(height: 12),
                  const StatusPill(
                    state: StatusPillState.cancelled,
                    semanticsPrefix: 'Event status',
                  ),
                  const SizedBox(height: 12),
                ] else
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
                  _AttendingSection(eventId: eventId, eventTitle: event.title),
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

/// Full-width hero image with a 16:9 aspect ratio (designer-confirmed TRI-49).
/// Category badge sits bottom-left overlaid on the image.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // 16:9 matches the feed card thumbnail ratio (designer-confirmed).
    final heroHeight = screenWidth * 9 / 16;

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover photo: real image with fade-in when URL is present;
          // shared category placeholder on failure or when absent.
          if (event.coverPhotoUrl != null)
            CachedNetworkImage(
              imageUrl: event.coverPhotoUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => CategoryImagePlaceholder(
                category: event.category,
              ),
              errorWidget: (context, url, error) =>
                  CategoryImagePlaceholder(category: event.category),
              fadeInDuration: const Duration(milliseconds: 200),
            )
          else
            CategoryImagePlaceholder(category: event.category),
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
          // Category badge — bottom-left (§E). No text overlay on hero per AC.
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
  const _AttendingSection({required this.eventId, required this.eventTitle});

  final String eventId;
  final String eventTitle;

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
        eventId: eventId,
        eventTitle: eventTitle,
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

class _AttendingLoadedSection extends ConsumerWidget {
  const _AttendingLoadedSection({
    required this.items,
    required this.eventId,
    required this.eventTitle,
  });

  final List<JoinRequestWithRequester> items;
  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      hostAttendingListControllerProvider(eventId).notifier,
    );

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
            onTapRemove: () => _handleRemoveRequest(context, controller, item),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRemoveRequest(
    BuildContext context,
    HostAttendingListController controller,
    JoinRequestWithRequester item,
  ) async {
    await showRemoveAttendeeSheet(
      context,
      eventTitle: eventTitle,
      requesterDisplayName: item.requester.displayName,
      onSubmit: (reason) => controller.removeAttendee(
        item: item,
        eventTitle: eventTitle,
        reason: reason,
      ),
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
///   - EmailNotVerified/PhoneNotVerified: inline banner above bar + "Verify now"
///
/// [verificationFailure]: non-null when the server returned EMAIL_NOT_VERIFIED
/// or PHONE_NOT_VERIFIED; shows the appropriate inline banner instead of the CTA.
class _StickyJoinBar extends ConsumerWidget {
  const _StickyJoinBar({
    required this.event,
    required this.joinState,
    required this.effectiveRequest,
    required this.verificationFailure,
  });

  final Event event;
  final RequestToJoinState joinState;
  final JoinRequest? effectiveRequest;
  final Failure? verificationFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      requestToJoinControllerProvider(event.id).notifier,
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final hostName = event.hostDisplayName ?? 'Host';

    // Determine whether the event is past (end-time only — cancelled is
    // handled separately below with a dedicated UI, not the generic "ended" copy).
    final now = DateTime.now().toUtc();
    final isEventPast = event.endsAt.toUtc().isBefore(now);

    // TRI-290: read session here so we can (a) guard the myCapabilitiesProvider
    // read and (b) branch the CTA tap handler on signed-out vs signed-in.
    final session = ref.watch(sessionControllerProvider);
    final isSignedOut = session is SessionUnauthenticated;

    // Sanctioned cross-feature import per CLAUDE.md mobile rules —
    // myCapabilitiesProvider is app-global session state in users/.
    // Default false when unreachable → show safety sheet (safer: over-show
    // a safety reminder than skip it — Brief G offline ruling).
    //
    // TRI-290: skip reading myCapabilitiesProvider when signed out — the
    // provider fires GET /users/me/capabilities which returns 401. Signed-out
    // viewers never reach the safety-vs-confirm branch so false is correct.
    final safetyReminderSeen = isSignedOut
        ? false // signed-out: never reaches the safety-reminder branch
        : ref
              .watch(myCapabilitiesProvider)
              .when(
                data: (caps) => caps.safetyReminderSeen,
                loading: () => false,
                error: (e, st) => false,
              );

    // TRI-302: review eligibility — signed-out viewers never fire the GET.
    // The provider is autoDispose + family so it is created only on demand here.
    // loading → null (fall through to existing bar); error → null (fall through).
    final ReviewEligibility? eligibility = isSignedOut
        ? null
        : ref
              .watch(reviewEligibilityProvider(event.id))
              .when(
                data: (e) => e,
                loading: () => null,
                error: (e, st) => null,
              );

    Widget content;

    // Removed-by-host viewers: silent suppression — no CTA, no status pill.
    // Per AC: the joiner's "removed_by_host" state is surfaced via
    // my_join_request_row.dart (Brief 8); this page shows nothing.
    if (effectiveRequest?.status == JoinRequestStatus.removedByHost) {
      return const SizedBox.shrink();
    }

    // Cancelled event: read-only badge + caption for ALL non-host viewers.
    // Dominates all request-status branches — a cancelled event supersedes
    // pending/approved/declined/withdrawn state.
    if (event.status == 'cancelled') {
      content = const _CancelledEventContent();
    } else if (verificationFailure != null) {
      content = _VerificationBanner(
        event: event,
        controller: controller,
        failure: verificationFailure!,
      );
    } else if (eligibility != null && eligibility.eligible) {
      // TRI-302: eligible reviewer — replace join/ended bar with review entry.
      // Sanctioned cross-feature import: reviews/presentation/providers (4th
      // exception) read from discover/ event-detail (same verb-view-read shape
      // as the sanctioned discover→join_requests import).
      content = _ReviewEntryBar(event: event, eligibility: eligibility);
    } else if (effectiveRequest != null &&
        effectiveRequest!.status == JoinRequestStatus.withdrawn &&
        !isEventPast) {
      // Withdrawn → re-request CTA. PM verdict: same affordance as never-
      // requested; tapping opens the appropriate sheet (safety or confirm)
      // based on safetyReminderSeen. No cooldown, no per-event cap.
      // Note: capacity-full is covered by isEventPast; cancelled is handled
      // by the branch above (event.status == 'cancelled').
      final isSubmitting = joinState is RequestToJoinSubmitting;
      content = PrimaryButton(
        label: 'Request to join',
        state: isSubmitting
            ? PrimaryButtonState.loading
            : PrimaryButtonState.idle,
        onPressed: isSubmitting
            ? null
            : () => _openJoinSheet(
                context,
                eventId: event.id,
                hostName: hostName,
                eventTitle: event.title,
                startsAt: event.startsAt,
                endsAt: event.endsAt,
                safetyReminderSeen: safetyReminderSeen,
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
      // TRI-72: signed-out tap opens the in-place sign-in gate sheet; on
      // successful auth the join sheet opens immediately (Tier 1 + Tier 2).
      // No POST is fired before auth — preserved from TRI-290.
      final isSubmitting = joinState is RequestToJoinSubmitting;
      content = PrimaryButton(
        label: 'Request to join',
        state: isSubmitting
            ? PrimaryButtonState.loading
            : PrimaryButtonState.idle,
        onPressed: isSubmitting
            ? null
            : isSignedOut
            ? () async {
                final didSignIn = await showSignInGateSheet(
                  context,
                  intent: SignInIntentRequestJoin(
                    eventId: event.id,
                    eventTitle: event.title,
                    hostName: hostName,
                    startsAt: event.startsAt,
                    endsAt: event.endsAt,
                  ),
                );
                if (!context.mounted) return;
                if (didSignIn) {
                  // TRI-294: re-read capabilities now that the user is
                  // authenticated — the top-of-build safetyReminderSeen was
                  // computed while signed-out (hardcoded false). A returning
                  // user who already acknowledged the reminder would otherwise
                  // be shown it again.
                  //
                  // .future is required: myCapabilitiesProvider.build() has not
                  // run yet (signed-out guard skipped ref.watch above), so a
                  // bare ref.read() returns AsyncLoading — not data. .future
                  // awaits build() and yields the real UserCapabilities.
                  //
                  // Fail-safe: ANY outcome other than a confirmed
                  // safetyReminderSeen == true resolves to false → show the
                  // reminder. Never silently skip on error or loading.
                  bool resumeSafetyReminderSeen;
                  try {
                    final caps = await ref.read(myCapabilitiesProvider.future);
                    resumeSafetyReminderSeen = caps.safetyReminderSeen;
                  } catch (_) {
                    resumeSafetyReminderSeen = false;
                  }
                  // Second mounted guard — the await above is a new suspension
                  // point; the widget may have been disposed since the first.
                  if (!context.mounted) return;
                  _openJoinSheet(
                    context,
                    eventId: event.id,
                    hostName: hostName,
                    eventTitle: event.title,
                    startsAt: event.startsAt,
                    endsAt: event.endsAt,
                    safetyReminderSeen: resumeSafetyReminderSeen,
                  );
                }
              }
            : () => _openJoinSheet(
                context,
                eventId: event.id,
                hostName: hostName,
                eventTitle: event.title,
                startsAt: event.startsAt,
                endsAt: event.endsAt,
                safetyReminderSeen: safetyReminderSeen,
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

// ---------------------------------------------------------------------------
// Review entry bar (TRI-302) — eligible reviewer affordance
// ---------------------------------------------------------------------------

/// Sticky bar content rendered when the signed-in user is within the 24h–7d
/// review window for this event's host.
///
/// States:
///   (A) not-reviewed → [SecondaryButton] "Write a review"
///   (B) already-reviewed → non-interactive "✓ You reviewed this host" row
///   Transition A→B via [AnimatedSwitcher] keyed on [_hasReviewed].
///
/// State-B trigger: after `context.push('/reviews/write?...')` returns,
/// [_hasReviewed] flips true (immediate visual) and
/// `ref.invalidate(reviewEligibilityProvider)` triggers a server re-fetch
/// (durable state-B confirmation — eligible=false from server causes the
/// outer [_StickyJoinBar] to eventually swap away from this widget entirely).
///
/// Session-expired/signed-out tap → [showSignInGateSheet] with
/// [SignInIntentWriteReview]; on success → re-check eligibility and push
/// composer; if no longer eligible → snackbar notice.
///
/// Feature-local widget; NOT promoted to core/.
class _ReviewEntryBar extends ConsumerStatefulWidget {
  const _ReviewEntryBar({required this.event, required this.eligibility});

  final Event event;
  final ReviewEligibility eligibility;

  @override
  ConsumerState<_ReviewEntryBar> createState() => _ReviewEntryBarState();
}

class _ReviewEntryBarState extends ConsumerState<_ReviewEntryBar> {
  bool _hasReviewed = false;

  Future<void> _pushComposer(
    String ratedUserId,
    String hostName, {
    bool requiresAuth = false,
  }) async {
    if (requiresAuth) {
      // Session-expired / signed-out path: show gate first.
      final didSignIn = await showSignInGateSheet(
        context,
        intent: SignInIntentWriteReview(
          eventId: widget.event.id,
          hostId: ratedUserId,
          hostDisplayName: hostName,
        ),
      );
      if (!mounted) return;
      if (!didSignIn) return; // dismissed — no action

      // Re-check eligibility after auth (the 24h–7d window may have closed).
      ReviewEligibility? fresh;
      try {
        fresh = await ref.read(
          reviewEligibilityProvider(widget.event.id).future,
        );
      } catch (_) {
        fresh = null;
      }
      if (!mounted) return;
      if (fresh == null || !fresh.eligible) {
        // Window closed while the user was at the sign-in gate.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This review is no longer available.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      // Proceed with the authenticated ratedUserId from the fresh eligibility.
      final freshRatedUserId = fresh.ratedUserId ?? ratedUserId;
      await context.push(
        '/reviews/write?eventId=${widget.event.id}&ratedUserId=$freshRatedUserId',
      );
    } else {
      await context.push(
        '/reviews/write?eventId=${widget.event.id}&ratedUserId=$ratedUserId',
      );
    }
    if (!mounted) return;
    // State-B immediate visual update + durable cache invalidation.
    setState(() => _hasReviewed = true);
    ref.invalidate(reviewEligibilityProvider(widget.event.id));
  }

  @override
  Widget build(BuildContext context) {
    final ratedUserId = widget.eligibility.ratedUserId ?? '';
    final hostName = widget.eligibility.hostDisplayName ?? 'Host';
    final session = ref.watch(sessionControllerProvider);
    final isSignedOut = session is SessionUnauthenticated;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: TribelyMotion.short,
          child: _hasReviewed
              ? const _ReviewedConfirmationRow(key: ValueKey('reviewed'))
              : Semantics(
                  key: const ValueKey('write-review'),
                  label: 'Write a review for $hostName',
                  child: SecondaryButton(
                    label: 'Write a review',
                    onPressed: () => _pushComposer(
                      ratedUserId,
                      hostName,
                      requiresAuth: isSignedOut,
                    ),
                    fullWidth: true,
                  ),
                ),
        ),
        if (!_hasReviewed) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(
              'Share how your meetup went.',
              textAlign: TextAlign.center,
              style: TribelyType.caption(TribelyColors.paperInkSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Non-interactive "✓ reviewed" confirmation row shown after the user
/// submits a review and the eligibility provider is invalidated.
///
/// Displayed via [AnimatedSwitcher] inside [_ReviewEntryBarState].
class _ReviewedConfirmationRow extends StatelessWidget {
  const _ReviewedConfirmationRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You have already reviewed this host',
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: TribelyColors.paperSuccess,
          ),
          const SizedBox(width: 8),
          Text(
            'You reviewed this host',
            style: TribelyType.caption(TribelyColors.paperInkSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join sheet dispatch helper
// ---------------------------------------------------------------------------

/// Opens [SafetyReminderSheet] when [safetyReminderSeen] is false (first-timer
/// path, TRI-34), otherwise opens [ConfirmJoinSheet] directly.
///
/// Offline / capabilities-unreachable default: [safetyReminderSeen] == false
/// → show the safety sheet (safer to over-show a reminder than skip it).
void _openJoinSheet(
  BuildContext context, {
  required String eventId,
  required String hostName,
  required String eventTitle,
  required DateTime startsAt,
  required DateTime endsAt,
  required bool safetyReminderSeen,
}) {
  if (!safetyReminderSeen) {
    showSafetyReminderSheet(context, eventId: eventId);
  } else {
    showConfirmJoinSheet(
      context,
      eventId: eventId,
      hostName: hostName,
      eventTitle: eventTitle,
      startsAt: startsAt,
      endsAt: endsAt,
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
      // removedByHost is suppressed upstream in _StickyJoinBar (no CTA shown).
      // This arm is kept for exhaustiveness; it should never be reached.
      JoinRequestStatus.removedByHost => StatusPillState.declined,
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

/// Read-only cancelled state shown in the sticky join bar for non-host viewers
/// when the event status is 'cancelled'.
///
/// Renders a [StatusPill(cancelled)] + the caption "This event has been
/// cancelled." — no CTA, no action affordance.
class _CancelledEventContent extends StatelessWidget {
  const _CancelledEventContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(
          child: StatusPill(
            state: StatusPillState.cancelled,
            semanticsPrefix: 'Event status',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This event has been cancelled.',
          textAlign: TextAlign.center,
          style: TribelyType.caption(TribelyColors.paperInkSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Host kebab button — AppBar trailing slot (Brief D)
// ---------------------------------------------------------------------------

/// A single-item kebab button rendered in the AppBar trailing slot for the
/// host of a non-cancelled loaded event.
///
/// Tapping opens a [showModalBottomSheet] action sheet with "Cancel event"
/// as the only item. Selecting it opens [CancelEventSheet]; on success the
/// event-detail and hosting-tab providers are invalidated so the page refreshes.
class _HostKebabButton extends ConsumerWidget {
  const _HostKebabButton({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      tooltip: 'More options',
      onPressed: () => _showActionSheet(context, ref),
    );
  }

  Future<void> _showActionSheet(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<_HostAction>(
      context: context,
      backgroundColor: TribelyColors.paperSurfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: TribelyColors.paperBorderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              title: Text(
                CancelEventCopy.actionSheetLabel,
                style: TribelyType.bodyM(TribelyColors.paperAccent),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_HostAction.cancelEvent),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == _HostAction.cancelEvent && context.mounted) {
      await showCancelEventSheet(
        context,
        eventId: eventId,
        onSuccess: () {
          ref.invalidate(eventDetailControllerProvider(eventId));
          // Cross-feature invalidate — EL pre-ruled: fire-and-forget refresh
          // is acceptable (invalidate, not a watch of feature state).
          ref.invalidate(hostingTabControllerProvider);
        },
      );
    }
  }
}

enum _HostAction { cancelEvent }

/// Inline verification banner. Shown above the (disabled) CTA when the
/// server returns a 403 with code EMAIL_NOT_VERIFIED or PHONE_NOT_VERIFIED.
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.event,
    required this.controller,
    required this.failure,
  });

  final Event event;
  final RequestToJoinController controller;
  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final isEmail = failure is EmailNotVerifiedFailure;
    final message = isEmail
        ? 'Verify your email to request events'
        : 'Verify your phone to request events';
    final route = isEmail ? '/verify-email' : '/auth/phone/entry';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BannerMessage(
          message: message,
          action: BannerAction(
            label: 'Verify now',
            onTap: () => context.push(route),
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
