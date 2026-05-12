import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../events/domain/entities/event_category.dart';
import '../../domain/entities/discover_filters.dart';
import '../controllers/discover_filter_controller.dart';
import '../providers/discover_filter_providers.dart';
import '../state/discover_filter_state.dart';

// ---------------------------------------------------------------------------
// Chip dimensions (§B spec)
// ---------------------------------------------------------------------------

/// Chip pill height per §B: 36dp visible, 40dp tap target (4dp invisible pad).
const double _kChipHeight = 36.0;
const double _kChipTapTargetPadding = 4.0;

/// Chip corner radius: pill shape → 18dp.
const double _kChipRadius = 18.0;


/// Distance chip options in kilometres.
const List<double> _kDistanceOptions = [1, 3, 5, 10, 20];

/// Separator: 1dp wide, 20dp tall, paperBorderSubtle, 8dp horizontal margin.
class _ChipSeparator extends StatelessWidget {
  const _ChipSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 1,
        height: 20,
        child: ColoredBox(color: TribelyColors.paperBorderSubtle),
      ),
    );
  }
}

/// Horizontally-scrollable filter chip row per §B.
///
/// Layout L→R: time chips (single-select) | separator | category chips
/// (multi-select) | [separator | distance chips (single-select)] when
/// location permission has been granted.
///
/// Right edge has a ShaderMask fade-out gradient to hint at more content.
///
/// Reads state from [discoverFilterControllerProvider] (D1).
/// Writes via [DiscoverFilterController] mutations.
///
/// [showDistanceChips] controls distance-chip visibility. The parent is
/// responsible for deriving this from location permission state.
class FilterChipRow extends ConsumerWidget {
  const FilterChipRow({this.showDistanceChips = false, super.key});

  final bool showDistanceChips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(discoverFilterControllerProvider);
    // filterState is always DiscoverFiltersActive in v1 single-subclass design.
    final active = filterState as DiscoverFiltersActive;
    final notifier = ref.read(discoverFilterControllerProvider.notifier);

    return SizedBox(
      height: _kChipHeight + _kChipTapTargetPadding * 2,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, 0.85, 1.0],
          colors: [Colors.white, Colors.white, Colors.transparent],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 40),
          child: Row(
            children: [
              // ── Time chips (single-select) ──
              _SingleSelectChip(
                label: 'Anytime',
                isSelected: active.timeWindow == TimeWindow.anytime,
                onTap: () => notifier.setTimeWindow(TimeWindow.anytime),
              ),
              const SizedBox(width: 8),
              _SingleSelectChip(
                label: 'Tonight',
                isSelected: active.timeWindow == TimeWindow.tonight,
                onTap: () => notifier.setTimeWindow(TimeWindow.tonight),
              ),
              const SizedBox(width: 8),
              _SingleSelectChip(
                label: 'This week',
                isSelected: active.timeWindow == TimeWindow.thisWeek,
                onTap: () => notifier.setTimeWindow(TimeWindow.thisWeek),
              ),

              // ── Separator ──
              const _ChipSeparator(),

              // ── Category chips (multi-select) ──
              ...EventCategory.values.map((category) {
                final isSelected = active.categories.contains(category);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MultiSelectChip(
                    label: category.displayName,
                    isSelected: isSelected,
                    onTap: () => notifier.toggleCategory(category),
                  ),
                );
              }),

              // ── Distance chips (single-select, shown only with permission) ──
              if (showDistanceChips) ...[
                const _ChipSeparator(),
                ..._kDistanceOptions.map((km) {
                  final label = '${km.toInt()} km';
                  final isSelected = active.maxDistanceKm == km;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SingleSelectChip(
                      label: label,
                      isSelected: isSelected,
                      onTap: () => notifier.setMaxDistanceKm(
                        isSelected ? null : km,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single-select chip (time / distance): paperPrimary fill + white label when
// selected, outlined default state.
// ---------------------------------------------------------------------------

class _SingleSelectChip extends StatelessWidget {
  const _SingleSelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? TribelyColors.paperPrimary
        : Colors.transparent;
    final labelColor = isSelected
        ? TribelyColors.paperSurfaceHigh
        : TribelyColors.paperInkSecondary;
    final borderColor = isSelected
        ? TribelyColors.paperPrimary
        : TribelyColors.paperBorderSubtle;

    return _ChipBase(
      label: label,
      bg: bg,
      labelColor: labelColor,
      borderColor: borderColor,
      borderWidth: 1.0,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-select chip (category): paperAccentSoft fill + paperAccent border +
// paperAccent label when selected.
// ---------------------------------------------------------------------------

class _MultiSelectChip extends StatelessWidget {
  const _MultiSelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? TribelyColors.paperAccentSoft
        : Colors.transparent;
    final labelColor = isSelected
        ? TribelyColors.paperAccent
        : TribelyColors.paperInkSecondary;
    final borderColor = isSelected
        ? TribelyColors.paperAccent
        : TribelyColors.paperBorderSubtle;
    final borderWidth = isSelected ? 1.5 : 1.0;

    return _ChipBase(
      label: label,
      bg: bg,
      labelColor: labelColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Base chip implementation
// ---------------------------------------------------------------------------

class _ChipBase extends StatelessWidget {
  const _ChipBase({
    required this.label,
    required this.bg,
    required this.labelColor,
    required this.borderColor,
    required this.borderWidth,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color labelColor;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 40dp tap target with 4dp invisible padding around 36dp visible chip.
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(_kChipTapTargetPadding),
        child: Container(
          height: _kChipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_kChipRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TribelyType.caption(labelColor),
          ),
        ),
      ),
    );
  }
}
