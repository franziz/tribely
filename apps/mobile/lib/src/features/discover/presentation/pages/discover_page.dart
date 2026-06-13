import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../auth/presentation/state/sign_in_intent.dart';
import '../../../auth/presentation/widgets/sign_in_gate_sheet.dart';
import '../widgets/discover_tab_switcher.dart';
import '../widgets/filter_chip_row.dart';
import 'discover_list_tab.dart';
import 'discover_map_tab.dart';

// ---------------------------------------------------------------------------
// DiscoverPage — full Discover screen scaffold
// ---------------------------------------------------------------------------

/// Discover screen scaffold per §2 designer spec.
///
/// Vertical zones (top → bottom):
///   1. Safe-area top + screen title "Discover".
///   2. [FilterChipRow] — hoisted here so it persists across List/Map tab
///      switches. Both tabs see the same chip row.
///   3. [IndexedStack] over [DiscoverListTab] (index 0) and [DiscoverMapTab]
///      (index 1) — both children stay mounted so list scroll position and
///      map camera survive tab toggles.
///   4. Sticky bottom container: "Create event" [PrimaryButton] CTA above
///      [DiscoverTabSwitcher].
///
/// Tab-switch state ([_selectedTab]) is owned here. Neither tab routes nor
/// [TabBarView] is used — [DiscoverTabSwitcher] drives the [IndexedStack].
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  /// 0 = List, 1 = Map.
  DiscoverTab _selectedTab = DiscoverTab.list;

  void _onTabChanged(DiscoverTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  // TRI-72 Brief C: intercept signed-out create-event taps with the sign-in
  // gate sheet. On successful auth, push /events/new so the phone-gate redirect
  // in app_router.dart fires as normal. Auth-walled entry points (my_events,
  // hosting_tab) use context.push('/events/new') directly — no gate needed.
  Future<void> _onCreateEvent() async {
    final session = ref.read(sessionControllerProvider);
    if (session is SessionUnauthenticated) {
      final didSignIn = await showSignInGateSheet(
        context,
        intent: const SignInIntentCreateEvent(),
      );
      if (!context.mounted) return;
      if (didSignIn) context.push('/events/new');
      return;
    }
    context.push('/events/new');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurface
        : TribelyColors.paperSurface;
    final inkPrimary = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        bottom: false, // bottom safe area handled inside the sticky container
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Zone 1: Screen title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Discover', style: TribelyType.headline(inkPrimary)),
            ),

            // ── Zone 2: Filter chip row (persists across both tabs) ──
            const FilterChipRow(),
            const SizedBox(height: 8),

            // ── Zone 3: Tab content — IndexedStack keeps both tabs mounted ──
            Expanded(
              child: IndexedStack(
                index: _selectedTab == DiscoverTab.list ? 0 : 1,
                children: const [DiscoverListTab(), DiscoverMapTab()],
              ),
            ),

            // ── Zone 4: Sticky bottom container ──
            _StickyBottomContainer(
              selectedTab: _selectedTab,
              onTabChanged: _onTabChanged,
              onCreateEvent: _onCreateEvent,
              borderSubtle: borderSubtle,
              surface: surface,
              dark: dark,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky bottom container — CTA + tab switcher
// ---------------------------------------------------------------------------

/// Sticky container at the bottom of the Discover scaffold.
///
/// Structure (top → bottom):
///   - 1dp divider (paperBorderSubtle / nightBorderSubtle).
///   - "Create event" [PrimaryButton] CTA, 56dp.
///   - 8dp gap.
///   - [DiscoverTabSwitcher].
///   - Safe-area bottom padding.
///
/// On Map tab: elevation 2 with subtle shadow (nightBorderSubtle at 12%
/// opacity) so the container lifts above the map edge per §2.
class _StickyBottomContainer extends StatelessWidget {
  const _StickyBottomContainer({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onCreateEvent,
    required this.borderSubtle,
    required this.surface,
    required this.dark,
  });

  final DiscoverTab selectedTab;
  final ValueChanged<DiscoverTab> onTabChanged;
  final Future<void> Function() onCreateEvent;
  final Color borderSubtle;
  final Color surface;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isMap = selectedTab == DiscoverTab.map;

    // Shadow color: nightBorderSubtle at 12% opacity on map tab, none on list.
    final shadowColor = TribelyColors.nightBorderSubtle.withValues(alpha: 0.12);

    return Material(
      elevation: isMap ? 2 : 0,
      color: surface,
      shadowColor: isMap ? shadowColor : Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1dp top divider
          Container(height: 1, color: borderSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: PrimaryButton(
              label: 'Create event',
              onPressed: () => onCreateEvent(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DiscoverTabSwitcher(
              selectedTab: selectedTab,
              onTabChanged: onTabChanged,
            ),
          ),
          // Safe-area bottom padding
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }
}
