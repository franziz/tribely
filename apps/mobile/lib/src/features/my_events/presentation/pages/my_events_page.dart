import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/state/auth_state.dart';
import '../../../discover/domain/entities/discover_filters.dart';
import '../../../discover/domain/usecases/browse_events_usecase.dart';
import '../../../discover/presentation/providers/browse_events_usecase_provider.dart';
import '../controllers/hosting_pending_count_controller.dart';
import 'hosting_tab.dart';
import 'my_join_requests_tab.dart';

/// My Events page — segmented-control tabbed shell.
///
/// Tabs:
///   0 — Hosting: [HostingTab] — full implementation in B2b.
///   1 — Requested: [MyJoinRequestsTab] — full implementation in B1b.
///
/// The "Hosting" tab label shows an 8dp [TribelyColors.paperAccent] filled dot
/// when ≥1 hosted event has ≥1 pending request. The dot is derived from
/// [HostingPendingCountController] and clears at zero.
class MyEventsPage extends ConsumerStatefulWidget {
  const MyEventsPage({super.key});

  @override
  ConsumerState<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends ConsumerState<MyEventsPage> {
  int _selectedTab = 0;
  List<String> _hostedEventIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHostedEventIds());
  }

  /// Fetches the current user's hosted event IDs once so [_TabLabel] can
  /// derive the notification dot count via [HostingPendingCountController].
  ///
  /// Failures are silently ignored — the dot simply won't show rather than
  /// crashing the page. The tab content itself handles error states with retry.
  Future<void> _loadHostedEventIds() async {
    try {
      final session = ref.read(sessionControllerProvider);
      if (session is! SessionAuthenticated) return;

      final useCase = ref.read(browseEventsUseCaseProvider);
      final result = await useCase(
        const BrowseEventsParams(filters: DiscoverFilters(hostUserId: 'me')),
      );
      if (!mounted) return;

      result.fold(
        (_) => null, // silent failure — dot just stays invisible
        (page) => setState(() {
          _hostedEventIds = page.events.map((e) => e.id).toList();
        }),
      );
    } catch (_) {
      // Swallow all errors — the dot stays invisible, not worth crashing.
    }
  }

  /// Called when the Hosting tab is re-selected — invalidates the pending
  /// count provider so it refetches fresh data.
  void _onTabSelected(int index) {
    setState(() => _selectedTab = index);
    if (index == 0 && _hostedEventIds.isNotEmpty) {
      ref.invalidate(hostingPendingCountControllerProvider(_hostedEventIds));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Derive notification dot count from the pending count controller.
    // When _hostedEventIds is empty (initial load or no events) the watch
    // returns the default state with total=0, which is correct.
    final pendingCountState = ref.watch(
      hostingPendingCountControllerProvider(_hostedEventIds),
    );
    final totalPending = pendingCountState.total;

    return Scaffold(
      backgroundColor: TribelyColors.paperSurface,
      appBar: AppBar(
        backgroundColor: TribelyColors.paperSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'My Events',
          style: TribelyType.headline(TribelyColors.paperInkPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: TribelyColors.paperPrimary),
            tooltip: 'Create event',
            onPressed: () => context.push('/events/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented control with notification dot on Hosting tab.
          _SegmentedControl(
            selectedIndex: _selectedTab,
            labels: [
              _TabLabel(
                label: 'Hosting',
                badgeCount: totalPending,
                semanticsLabel: totalPending > 0
                    ? 'Hosting, $totalPending pending request${totalPending == 1 ? '' : 's'}'
                    : 'Hosting',
              ),
              const _TabLabel(label: 'Requested'),
            ],
            onTabSelected: _onTabSelected,
          ),
          // Tab content.
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [
                // Tab 0 — Hosting (B2b).
                HostingTab(),
                // Tab 1 — Requested (B1b).
                MyJoinRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented control
// ---------------------------------------------------------------------------

/// A pill-style segmented control used to switch between tabs.
///
/// Cleanly parameterized — B2 can supply custom [_TabLabel] instances with
/// badge overlays without touching this widget's structure.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selectedIndex,
    required this.labels,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final List<_TabLabel> labels;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TribelyColors.paperBorderSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TribelyColors.paperSurfaceHigh
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: labels[index]._build(context, isSelected: isSelected),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab label slot (B2 attachment point)
// ---------------------------------------------------------------------------

/// A tab label widget with an optional notification-dot overlay.
///
/// Construct with a non-zero [badgeCount] to render an 8dp
/// [TribelyColors.paperAccent] filled dot top-right of the label text.
/// The dot is positioned via a [Stack] so the label width is unaffected.
///
/// [semanticsLabel] overrides the a11y label when the dot is visible.
/// Pass `"Hosting, N pending requests"` to satisfy PM AC.
class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    this.badgeCount = 0,
    this.semanticsLabel,
  });

  final String label;

  /// When > 0, an 8dp accent dot is shown top-right of the label.
  final int badgeCount;

  /// Accessibility label override. When null, falls back to [label].
  final String? semanticsLabel;

  Widget _build(BuildContext context, {required bool isSelected}) {
    final textColor = isSelected
        ? TribelyColors.paperInkPrimary
        : TribelyColors.paperInkSecondary;

    final textWidget = Text(
      label,
      textAlign: TextAlign.center,
      style: TribelyType.caption(
        textColor,
      ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
    );

    if (badgeCount <= 0) {
      return Semantics(
        label: semanticsLabel ?? label,
        excludeSemantics: semanticsLabel != null,
        child: textWidget,
      );
    }

    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          textWidget,
          // 8dp accent dot — top-right of the label text.
          Positioned(
            top: -2,
            right: -8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: TribelyColors.paperAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The _build method is called by _SegmentedControl with isSelected context.
    // When used standalone (e.g. in tests), render in the non-selected style.
    return _build(context, isSelected: false);
  }
}
