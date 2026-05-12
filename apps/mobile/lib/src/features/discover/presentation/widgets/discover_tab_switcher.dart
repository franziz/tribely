import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';

/// Which tab is currently selected in [DiscoverTabSwitcher].
enum DiscoverTab { list, map }

/// Segmented 2-tab switcher per §3:
/// - Selected segment: paperPrimary at 12% opacity fill, paperPrimary text.
/// - Unselected: paperInkSecondary text, no fill.
/// - Height 36dp, border-radius 10.
/// - Animated pill indicator slides between segments in 150ms easeOut.
/// - Each segment has 44pt min tap target width.
///
/// D5 wires [selectedTab] and [onTabChanged]. D4 imports this widget.
class DiscoverTabSwitcher extends StatefulWidget {
  const DiscoverTabSwitcher({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final DiscoverTab selectedTab;
  final ValueChanged<DiscoverTab> onTabChanged;

  @override
  State<DiscoverTabSwitcher> createState() => _DiscoverTabSwitcherState();
}

class _DiscoverTabSwitcherState extends State<DiscoverTabSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pillPosition;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pillPosition = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: TribelyMotion.easeOut),
    );

    // Sync initial position to the selected tab without animation.
    if (widget.selectedTab == DiscoverTab.map) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DiscoverTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      if (widget.selectedTab == DiscoverTab.list) {
        _ctrl.reverse();
      } else {
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: TribelyColors.paperBorderSubtle.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedBuilder(
        animation: _pillPosition,
        builder: (context, _) {
          return CustomMultiChildLayout(
            delegate: _TabSwitcherLayout(pillPosition: _pillPosition.value),
            children: [
              // ── Animated pill ──
              LayoutId(
                id: _TabSwitcherSlot.pill,
                child: Container(
                  decoration: BoxDecoration(
                    color: TribelyColors.paperPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // ── List segment ──
              LayoutId(
                id: _TabSwitcherSlot.list,
                child: _SegmentButton(
                  label: 'List',
                  icon: Icons.view_list_outlined,
                  isSelected: widget.selectedTab == DiscoverTab.list,
                  onTap: () => widget.onTabChanged(DiscoverTab.list),
                ),
              ),
              // ── Map segment ──
              LayoutId(
                id: _TabSwitcherSlot.map,
                child: _SegmentButton(
                  label: 'Map',
                  icon: Icons.map_outlined,
                  isSelected: widget.selectedTab == DiscoverTab.map,
                  onTap: () => widget.onTabChanged(DiscoverTab.map),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout delegate — positions the pill under the selected segment
// ---------------------------------------------------------------------------

enum _TabSwitcherSlot { pill, list, map }

class _TabSwitcherLayout extends MultiChildLayoutDelegate {
  _TabSwitcherLayout({required this.pillPosition});

  /// 0.0 = list segment, 1.0 = map segment.
  final double pillPosition;

  @override
  void performLayout(Size size) {
    final segmentWidth = size.width / 2;
    final segmentConstraints = BoxConstraints.tight(
      Size(segmentWidth, size.height),
    );

    // Layout segments.
    layoutChild(_TabSwitcherSlot.list, segmentConstraints);
    layoutChild(_TabSwitcherSlot.map, segmentConstraints);

    // Layout pill at the same size as a segment.
    layoutChild(
      _TabSwitcherSlot.pill,
      BoxConstraints.tight(Size(segmentWidth, size.height)),
    );

    // Position pill — interpolate between list (0) and map (segmentWidth).
    final pillLeft = segmentWidth * pillPosition;
    positionChild(_TabSwitcherSlot.pill, Offset(pillLeft, 0));

    // Segment positions are fixed.
    positionChild(_TabSwitcherSlot.list, Offset.zero);
    positionChild(_TabSwitcherSlot.map, Offset(segmentWidth, 0));
  }

  @override
  bool shouldRelayout(_TabSwitcherLayout oldDelegate) =>
      pillPosition != oldDelegate.pillPosition;
}

// ---------------------------------------------------------------------------
// Individual segment button
// ---------------------------------------------------------------------------

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? TribelyColors.paperPrimary
        : TribelyColors.paperInkSecondary;

    // 44pt min tap target wrapped around the 36dp visible height.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TribelyType.caption(color).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
