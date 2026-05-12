import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../controllers/discover_filter_controller.dart';
import '../state/discover_state.dart';

/// Centered empty state widget per §G.
///
/// Two flavors driven by [DiscoverEmptyReason]:
///
/// - [DiscoverEmptyReason.noEventsMatchFilters]: headline + body +
///   "Reset filters" secondary button.
/// - [DiscoverEmptyReason.noEventsInArea]: headline + body +
///   "Create an event" primary button routed to `/events/new`.
///
/// [filterNotifier] is required only for the reset-filters flavor; pass null
/// for [DiscoverEmptyReason.noEventsInArea].
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.reason,
    this.filterNotifier,
    super.key,
  });

  final DiscoverEmptyReason reason;

  /// Required for [DiscoverEmptyReason.noEventsMatchFilters] to call [reset].
  final DiscoverFilterController? filterNotifier;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 56,
              color: TribelyColors.paperInkSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _headline,
              style: TribelyType.headline(TribelyColors.paperInkPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _body,
              style: TribelyType.bodyM(TribelyColors.paperInkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildCta(context),
          ],
        ),
      ),
    );
  }

  String get _headline => switch (reason) {
    DiscoverEmptyReason.noEventsMatchFilters => 'Nothing here yet',
    DiscoverEmptyReason.noEventsInArea => 'No events in Singapore yet',
  };

  String get _body => switch (reason) {
    DiscoverEmptyReason.noEventsMatchFilters =>
      'Try a different time or category.',
    DiscoverEmptyReason.noEventsInArea => 'Be the first to host something.',
  };

  Widget _buildCta(BuildContext context) => switch (reason) {
    DiscoverEmptyReason.noEventsMatchFilters => SecondaryButton(
      label: 'Reset filters',
      onPressed: () => filterNotifier?.reset(),
    ),
    DiscoverEmptyReason.noEventsInArea => PrimaryButton(
      label: 'Create an event',
      onPressed: () => context.go('/events/new'),
    ),
  };
}
