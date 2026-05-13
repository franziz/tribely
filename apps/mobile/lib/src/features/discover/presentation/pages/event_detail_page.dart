import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
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
import '../../../join_requests/presentation/controllers/request_to_join_controller.dart';
import '../../../join_requests/presentation/providers/join_requests_providers.dart';
import '../../../join_requests/presentation/state/request_to_join_state.dart';
import '../../../join_requests/presentation/widgets/confirm_join_sheet.dart';
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
///   - Withdrawn request → StatusPill(withdrawn)
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

class _LoadedBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final joinState = ref.watch(requestToJoinControllerProvider(eventId));

    // Determine effective request: prefer submitted result, else existing from idle.
    final effectiveRequest = switch (joinState) {
      RequestToJoinSubmitted(:final joinRequest) => joinRequest,
      RequestToJoinIdle(:final existingRequest) => existingRequest,
      RequestToJoinWithdrawing(:final withdrawingRequest) => withdrawingRequest,
      _ => null,
    };

    // Check if there is a pending email-not-verified failure to show the banner.
    final emailNotVerifiedFailure = switch (joinState) {
      RequestToJoinFailed(:final failure)
          when failure is EmailNotVerifiedFailure =>
        failure,
      _ => null,
    };

    // When the host is viewing their own event, drop the sticky-bar reservation —
    // no CTA, no empty layout artifact.
    final bottomPadding = isHostViewer
        ? MediaQuery.paddingOf(context).bottom
        : _stickyBarHeight(effectiveRequest, emailNotVerifiedFailure) +
              MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // Scrollable content.
        SingleChildScrollView(
          // Bottom padding reserves space for the sticky CTA when visible.
          padding: EdgeInsets.only(bottom: bottomPadding),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        // Sticky bottom bar. Hidden for host viewers — B2 will wire host-side
        // management. Non-host branch is the real CTA.
        if (!isHostViewer)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StickyJoinBar(
              event: event,
              joinState: joinState,
              effectiveRequest: effectiveRequest,
              emailNotVerifiedBanner: emailNotVerifiedFailure != null,
            ),
          ),
        // B2 attachment point: host-side management slot.
        // Replace _HostBranchPlaceholder with actual host CTA when B2 lands.
      ],
    );
  }

  /// Estimated sticky bar height for scroll-padding calculation.
  /// Varies based on whether extra content (banner, withdraw link) is present.
  double _stickyBarHeight(
    JoinRequest? request,
    EmailNotVerifiedFailure? emailFailure,
  ) {
    if (emailFailure != null) return 140;
    if (request == null) return 80;
    return switch (request.status) {
      JoinRequestStatus.pending => 100,
      JoinRequestStatus.declined => 100,
      _ => 80,
    };
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
        _MetaRow(
          icon: Icons.person_outline,
          // host.displayName is now wired from the eventWithHostResponseSchema
          // wrapper. Falls back to 'Host' if absent (defensive parse).
          // Avatar deferred to TRI-19 (API doesn't ship avatarUrl in v1).
          label: 'Hosted by ${event.hostDisplayName ?? 'Host'}',
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
// Sticky bottom bar — state-aware, non-host branch only (B1a)
// ---------------------------------------------------------------------------

/// Sticky bottom bar for non-host viewers. Renders one of:
///   - No request: PrimaryButton("Request to join") → opens ConfirmJoinSheet
///   - Pending: StatusPill(pending) + "Sent to {host}" + withdraw link
///   - Approved: StatusPill(approved)
///   - Declined: StatusPill(declined) + decisionReason caption
///   - Withdrawn: StatusPill(withdrawn)
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
