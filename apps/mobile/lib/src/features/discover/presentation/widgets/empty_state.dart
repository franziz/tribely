import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../auth/presentation/state/sign_in_intent.dart';
import '../../../auth/presentation/widgets/sign_in_gate_sheet.dart';
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
///
/// TRI-72 Brief C: the "Create an event" CTA for [DiscoverEmptyReason.noEventsInArea]
/// is signed-out-reachable (Discover feed is public). Signed-out taps open the
/// sign-in gate sheet; on successful auth the app pushes `/events/new` so the
/// phone-gate redirect fires as normal.
class EmptyState extends ConsumerWidget {
  const EmptyState({required this.reason, this.filterNotifier, super.key});

  final DiscoverEmptyReason reason;

  /// Required for [DiscoverEmptyReason.noEventsMatchFilters] to call [reset].
  final DiscoverFilterController? filterNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _buildCta(context, ref),
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

  Widget _buildCta(BuildContext context, WidgetRef ref) => switch (reason) {
    DiscoverEmptyReason.noEventsMatchFilters => SecondaryButton(
      label: 'Reset filters',
      onPressed: () => filterNotifier?.reset(),
    ),
    DiscoverEmptyReason.noEventsInArea => PrimaryButton(
      label: 'Create an event',
      onPressed: () => _onCreateEventTapped(context, ref),
    ),
  };

  // TRI-72 Brief C: intercept signed-out taps on the empty-state "Create an
  // event" CTA. Discover feed is public (signed-out reachable), so this CTA
  // needs the same gate as the sticky bottom container CTA.
  Future<void> _onCreateEventTapped(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionControllerProvider);
    if (session is SessionUnauthenticated) {
      final didSignIn = await showSignInGateSheet(
        context,
        intent: const SignInIntentCreateEvent(),
      );
      if (!context.mounted) return;
      if (didSignIn) context.go('/events/new');
      return;
    }
    context.go('/events/new');
  }
}
