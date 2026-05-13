import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import 'my_join_requests_tab.dart';

/// My Events page — segmented-control tabbed shell.
///
/// Tabs:
///   0 — Hosting: placeholder for B2. Replace [_HostingTabPlaceholder] with
///       the actual hosting list when B2 lands. The tab label slot is exposed
///       via [_TabLabel] so B2 can overlay a notification dot without
///       restructuring the segmented control.
///   1 — Requested: [MyJoinRequestsTab] — full implementation in B1b.
///
/// B2 attachment contract:
///   - Replace `const _HostingTabPlaceholder()` with the real hosting widget.
///   - Wrap the "Hosting" label in a Stack/Badge overlay for the notification
///     dot by providing a custom [_TabLabel] with [badgeCount] set.
///   - No restructuring of the segmented control itself is required.
class MyEventsPage extends ConsumerStatefulWidget {
  const MyEventsPage({super.key});

  @override
  ConsumerState<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends ConsumerState<MyEventsPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
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
          // Create event FAB is replaced by an action icon in the AppBar
          // so it doesn't interfere with the hosting list (B2 may place a
          // FAB if needed — this is the minimal non-floating version for now).
          IconButton(
            icon: const Icon(Icons.add, color: TribelyColors.paperPrimary),
            tooltip: 'Create event',
            onPressed: () => context.push('/events/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented control — cleanly parameterized so B2 can override labels.
          _SegmentedControl(
            selectedIndex: _selectedTab,
            labels: const [
              // B2: replace with _TabLabel(label: 'Hosting', badgeCount: pendingCount)
              // to overlay a notification dot without restructuring.
              _TabLabel(label: 'Hosting'),
              _TabLabel(label: 'Requested'),
            ],
            onTabSelected: (index) => setState(() => _selectedTab = index),
          ),
          // Tab content.
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [
                // Tab 0 — Hosting (B2 will replace this).
                _HostingTabPlaceholder(),
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

/// A tab label widget with an optional badge count overlay.
///
/// B2 attachment: construct with a non-zero [badgeCount] to render a
/// notification dot over the label. The dot sits top-right of the text,
/// rendered via a [Stack] so the label width is unaffected.
class _TabLabel extends StatelessWidget {
  // ignore: unused_element_parameter — B2 will pass badgeCount for the Hosting tab.
  const _TabLabel({required this.label, this.badgeCount = 0});

  final String label;

  /// When > 0, a small red dot is shown top-right of the label.
  /// B2 sets this to the number of pending requests for the Hosting tab.
  final int badgeCount;

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
      return textWidget;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        textWidget,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // The _build method is called by _SegmentedControl with isSelected context.
    // When used standalone (e.g. in tests), render in the non-selected style.
    return _build(context, isSelected: false);
  }
}

// ---------------------------------------------------------------------------
// Hosting tab placeholder (B2 will replace this)
// ---------------------------------------------------------------------------

/// Placeholder for the Hosting tab content.
///
/// B2 attachment: replace this widget assignment in [_MyEventsPageState.build]
/// with the actual hosting list widget. This const class is intentionally
/// minimal — it's a named slot marker, not a real content widget.
class _HostingTabPlaceholder extends StatelessWidget {
  const _HostingTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Hosting tab coming soon'));
  }
}
