import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/entities/event_category.dart';

/// Bottom sheet card displayed when the user taps a single event pin.
///
/// Spec §D Map bottom-sheet card:
///   - Drag handle bar: 36 × 4dp, [TribelyColors.paperBorderSubtle].
///   - Category icon + label (caption, [TribelyColors.paperInkSecondary]).
///   - Event title (bodyL semibold).
///   - Datetime (caption, [TribelyColors.paperInkSecondary]).
///   - "View details →" row (bodyM, [TribelyColors.paperPrimary]).
///   - Background: [TribelyColors.paperSurfaceHigh], top-corner radius 20.
///   - Fixed peek height ~140dp; NOT expandable.
///   - "View details" routes to `/events/:id`.
///   - Sheet dismisses on outside tap or upward drag.
///   - Appear animation: slide up 200ms easeOut.
///
/// Usage:
///   ```dart
///   showMapEventBottomSheet(context, event);
///   ```
class MapEventBottomSheet extends StatelessWidget {
  const MapEventBottomSheet({required this.event, super.key});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TribelyColors.paperSurfaceHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      // Fixed peek: 16 drag-handle zone + 16 top pad + content + 16 bottom pad.
      // Target ~140dp total.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const _DragHandle(),
          // Content area — 16dp horizontal + vertical padding after handle.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CategoryRow(category: event.category),
                const SizedBox(height: 6),
                _TitleRow(title: event.title),
                const SizedBox(height: 6),
                _DatetimeRow(startsAt: event.startsAt, endsAt: event.endsAt),
                const SizedBox(height: 10),
                _ViewDetailsRow(eventId: event.id),
              ],
            ),
          ),
          // Bottom safe area padding so content isn't obscured on iPhone notch.
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public show-helper
// ---------------------------------------------------------------------------

/// Shows [MapEventBottomSheet] for [event] using [showModalBottomSheet].
///
/// Spec §D: slide-up 200ms easeOut appear animation. Flutter's default modal
/// bottom sheet uses a 250ms ease-in-out curve; the 200ms easeOut variant is
/// achieved by passing a custom [transitionAnimationController].
///
/// [vsync] must be provided by the caller (a [TickerProvider] from the
/// enclosing [State]) so the controller is tied to a live vsync source.
///
/// Returns the result of [showModalBottomSheet].
Future<void> showMapEventBottomSheet(
  BuildContext context,
  Event event, {
  required TickerProvider vsync,
}) {
  final controller = AnimationController(
    vsync: vsync,
    duration: const Duration(milliseconds: 200),
  );

  return showModalBottomSheet<void>(
    context: context,
    // Fixed peek — do not set isScrollControlled=true (that enables expansion).
    backgroundColor: Colors.transparent,
    // Dismiss on outside tap (default behaviour).
    isDismissible: true,
    // Upward drag to dismiss.
    enableDrag: true,
    // Slide-up 200ms easeOut per spec §D.
    transitionAnimationController: controller,
    builder: (_) => MapEventBottomSheet(event: event),
  ).whenComplete(controller.dispose);
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Drag handle bar: 36 × 4dp, [TribelyColors.paperBorderSubtle].
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: TribelyColors.paperBorderSubtle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Category icon + label row (caption, [TribelyColors.paperInkSecondary]).
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final EventCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          _iconForCategory(category),
          size: 14,
          color: TribelyColors.paperInkSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          category.displayName,
          style: TribelyType.caption(TribelyColors.paperInkSecondary),
        ),
      ],
    );
  }

  static IconData _iconForCategory(EventCategory category) {
    return switch (category) {
      EventCategory.drinks => Icons.local_bar_outlined,
      EventCategory.food => Icons.restaurant_outlined,
      EventCategory.hike => Icons.terrain_outlined,
      EventCategory.museum => Icons.museum_outlined,
      EventCategory.sports => Icons.sports_outlined,
      EventCategory.nightlife => Icons.nightlife_outlined,
      EventCategory.other => Icons.event_outlined,
    };
  }
}

/// Event title (bodyL semibold).
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TribelyType.bodyL(
        TribelyColors.paperInkPrimary,
      ).copyWith(fontWeight: FontWeight.w600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Datetime row (caption, [TribelyColors.paperInkSecondary]).
/// Displays start date + time in SGT (UTC+8).
class _DatetimeRow extends StatelessWidget {
  const _DatetimeRow({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;

  static const _sgtOffset = Duration(hours: 8);

  @override
  Widget build(BuildContext context) {
    final startSgt = startsAt.toUtc().add(_sgtOffset);
    final endSgt = endsAt.toUtc().add(_sgtOffset);

    final date = DateFormat('EEE, d MMM').format(startSgt);
    final startTime = DateFormat('h:mm a').format(startSgt);
    final endTime = DateFormat('h:mm a').format(endSgt);

    return Row(
      children: [
        const Icon(
          Icons.schedule_outlined,
          size: 14,
          color: TribelyColors.paperInkSecondary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$date · $startTime–$endTime',
            style: TribelyType.caption(TribelyColors.paperInkSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// "View details →" row (bodyM, [TribelyColors.paperPrimary], right-aligned
/// chevron). Tapping routes to `/events/:id`.
class _ViewDetailsRow extends StatelessWidget {
  const _ViewDetailsRow({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.push('/events/$eventId');
        Navigator.of(context).maybePop(); // dismiss sheet after push
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'View details',
            style: TribelyType.bodyM(TribelyColors.paperPrimary),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: TribelyColors.paperPrimary,
          ),
        ],
      ),
    );
  }
}
