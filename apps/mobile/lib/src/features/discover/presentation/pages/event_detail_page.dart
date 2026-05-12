import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../events/domain/entities/event.dart';
import '../providers/event_detail_providers.dart';
import '../state/event_detail_state.dart';

/// Read-only event detail page. Accessed via `/events/:id`.
///
/// Renders outside the bottom-nav shell (parentNavigatorKey: _rootNavigatorKey
/// in app_router.dart) so the nav bar is hidden on this screen (§E).
///
/// CTA: "Request to join" is always visible + tappable. Tapping fires a
/// SnackBar communicating temporal unavailability (§F inert-CTA pattern).
/// The actual join-request submission is TRI-28.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  static const String _ctaSnackBarMessage =
      'Join requests are coming soon — you\'ll be first to know.';
  static const Duration _ctaSnackBarDuration = Duration(seconds: 3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventDetailControllerProvider(eventId));

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
          onJoinPressed: () => _showJoinSnackBar(context),
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

  void _showJoinSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_ctaSnackBarMessage),
        duration: _ctaSnackBarDuration,
      ),
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

    return Column(
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
    );
  }
}

// ---------------------------------------------------------------------------
// Loaded body
// ---------------------------------------------------------------------------

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.event, required this.onJoinPressed});

  final Event event;
  final VoidCallback onJoinPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrollable content.
        SingleChildScrollView(
          // Bottom padding = sticky bar height (80dp) + safe area bottom,
          // so content isn't occluded by the sticky CTA.
          padding: EdgeInsets.only(
            bottom: 80 + MediaQuery.paddingOf(context).bottom,
          ),
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
        // Sticky bottom CTA (§E + §F).
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _StickyJoinBar(onPressed: onJoinPressed),
        ),
      ],
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
        _MetaRow(
          icon: Icons.person_outline,
          // v1 trim: no avatar (API doesn't ship avatarUrl). Display host ID
          // as a placeholder until TRI-28 / users API wires host name.
          label: 'Hosted by ${event.hostId}',
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

/// Sticky bottom bar — always visible, always tappable. Toast on tap (§F).
class _StickyJoinBar extends StatelessWidget {
  const _StickyJoinBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurface,
        border: Border(
          top: BorderSide(color: TribelyColors.paperBorderSubtle, width: 1),
        ),
      ),
      child: PrimaryButton(
        label: 'Request to join',
        state: PrimaryButtonState.idle,
        onPressed: onPressed,
      ),
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
