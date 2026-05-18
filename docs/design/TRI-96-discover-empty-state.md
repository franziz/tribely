# TRI-96 — Discover Empty-State Visual Cleanup

*Spec version 1.0 — 2026-05-18 — design deliverable.*
*Author: ui-ux-designer agent.*

---

## Summary

Four visual defects on the Discover tab when the event list is empty (`DiscoverEmptyReason.noEventsInArea`). This is the MVP launch reality for Singapore (CEO "Path A" on TRI-33). The defects share a single fix surface — the Discover feature widget tree — so one designer pass covers all four. No new screens, no scope changes, no copy strategy rewrites.

**In scope:** `empty_state.dart`, `discover_page.dart` sticky container, `discover_tab_switcher.dart`, `filter_chip_row.dart`.
**Out of scope:** The `noEventsMatchFilters` flavor of `EmptyState`, the Map tab, any navigation or routing, anything currently working.

---

## Defect 1 — Two redundant "Create event" primary CTAs

### Current state

`EmptyState` (line 79) renders a full-width `PrimaryButton` labeled "Create an event" as the hero CTA in the centered block. `_StickyBottomContainer` in `discover_page.dart` (lines 150–155) always renders a second full-width `PrimaryButton` labeled "Create event" directly above `DiscoverTabSwitcher`. When the list is empty, both are simultaneously visible and visually identical — two dark-teal 56dp buttons stacked on one screen.

### Decision: keep the sticky CTA, convert the hero CTA to a text link

**The sticky bottom CTA survives.** It already satisfies the TRI-27 CEO binding ("Create event CTA above the fold") — it sits above the fold on every device. It is also the correct architectural home: `_StickyBottomContainer` is always present regardless of list state, which means the CTA survives transitions from empty→populated without a widget swap. Removing it would require wiring conditional visibility into the sticky container and re-testing the non-empty state.

**The hero CTA downgrades to a text link** (`TextButton` / inline tappable text, not a second `PrimaryButton`). Its role in the empty state is to reinforce the invitation to host — a secondary nudge, not a competing primary action. Treating it as a text link preserves the CTA meaning without competing with the sticky button's visual weight.

**Copy change:** The hero block text link reads "Start hosting" (not "Create an event" / "Create event" — the duplication of copy reinforced the visual confusion). This also reads more warmly in the empty-state context: "Be the first to host something. Start hosting →".

**Why not remove the hero CTA entirely?** The hero CTA gives users something actionable inside the content zone, which reduces the "dead screen" feeling. On a fully empty screen (no cards, no content), a user who misses the sticky CTA at the bottom — possible when eyes are drawn to the centered content — would have no affordance. The text link costs nothing visually and provides a safety net.

**Why not remove the sticky CTA?** It persists when events exist (users can always create from Discover), it satisfies TRI-27 above-the-fold binding, and it is the more discoverable affordance on first launch.

### Specified layout — hero block

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│              [explore_outlined: 48dp]                  │  ← see Defect 4 for vertical rhythm
│                   paperInkSecondary                    │
│                                                        │
│           No events in Singapore yet                   │  ← headline/22 semibold, paperInkPrimary
│                                                        │
│      Be the first to host something.                   │  ← bodyM/15, paperInkSecondary
│                                                        │  ← 16dp gap
│              Start hosting →                           │  ← caption/13 medium, paperPrimary
│                                                        │    underline decoration, tap target 44pt min
└────────────────────────────────────────────────────────┘
```

**"Start hosting →" text link spec:**
- Style: `TribelyType.caption(TribelyColors.paperPrimary)` with `decoration: TextDecoration.underline`, `decorationColor: TribelyColors.paperPrimary`.
- Arrow: appended inline as a Unicode right arrow `→` (U+2192), not a trailing icon widget — keeps the hit target clean.
- Tap target: wrap in `GestureDetector` or `InkWell` with `padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16)` to achieve 40dp+ tap height on a 13sp text link.
- Route: same as the existing hero CTA — `context.go('/events/new')`.
- Semantics: `Semantics(label: 'Start hosting, link', button: true)`.

### Token reuse

| Element | Token | Notes |
|---|---|---|
| Link text color | `paperPrimary` (#1B3D3A) | Existing token |
| Link underline | `paperPrimary` | Same |
| Body text | `paperInkSecondary` | Existing — no change |

No new tokens. The `PrimaryButton` import in `empty_state.dart` can be removed once the hero CTA converts to a text link.

---

## Defect 2 — List/Map toggle reads washed-out / disabled

### Current state

`DiscoverTabSwitcher` uses `TribelyColors.paperBorderSubtle.withValues(alpha: 0.50)` as the track background (line 78) and `TribelyColors.paperPrimary.withValues(alpha: 0.12)` as the animated pill fill (line 92). The result: selected state is a barely-visible pale green tint on a beige background — insufficient contrast against the `_StickyBottomContainer` which sits directly above on `paperSurface`. The toggle reads as disabled, not as a selectable control.

### Root cause analysis

The alpha-0.12 pill was chosen to be "subtle" but reads too close to the track's own alpha-0.50 beige. On `paperSurface` (#FAF6EF), both tints are warm and low-contrast. The toggle also competes with the `PrimaryButton` directly above it in the sticky container — two heavyweight elements stacked. Softening the toggle was the right instinct; the execution undershoots.

### Decision: raise pill contrast; keep the existing segmented-pill shape

The pill shape and animation (150ms, `easeOut`, sliding pill) are good — they match current-year segmented control patterns (iOS 16+, Material 3 `SegmentedButton`). The problem is purely the fill opacity. Two targeted changes:

1. **Pill fill:** raise from `paperPrimary.withValues(alpha: 0.12)` to `paperPrimary.withValues(alpha: 0.18)`. This gives the selected segment a clearly distinct background without turning the toggle into a heavy element below the primary CTA. At 0.18 alpha, `paperPrimary` (#1B3D3A) on `paperSurface` (#FAF6EF) renders as approximately #E5ECEA — adequate contrast from the track color.

2. **Track background:** change from `paperBorderSubtle.withValues(alpha: 0.50)` to `paperBorderSubtle` (no alpha). The current half-opacity track makes the pill-to-track contrast doubly weak — reducing track opacity was inadvertently making the track near-invisible too. At full opacity `paperBorderSubtle` (#E8DFD0) is a clean warm beige that reads as a distinct control boundary on `paperSurface`.

3. **Selected label weight:** already at `FontWeight.w600` in the selected state (line 206 — `isSelected ? FontWeight.w600 : FontWeight.w500`). Keep this. The weight delta is part of the differentiation hierarchy.

No changes to: pill shape, border-radius, height (36dp), animation duration, icon set, or label copy.

### State coverage

| State | Track bg | Pill fill | Label color | Label weight |
|---|---|---|---|---|
| Selected | `paperBorderSubtle` | `paperPrimary` @ 0.18 alpha | `paperPrimary` | w600 |
| Unselected | `paperBorderSubtle` | none (transparent) | `paperInkSecondary` | w500 |
| Pressed (transitioning) | `paperBorderSubtle` | interpolated 0–0.18 | interpolated | — |
| Disabled | not used in MVP | — | — | — |

### ASCII reference

```
BEFORE (current — washed-out)
┌─────────────────────────────────────────────┐  height: 36dp
│ ╔══════════════════╗                         │  track: borderSubtle @ 50% opacity
│ ║  ≡ List          ║   🗺 Map                │  pill: paperPrimary @ 12% opacity
│ ╚══════════════════╝                         │  selected label: paperPrimary w600
└─────────────────────────────────────────────┘

AFTER (specified)
┌─────────────────────────────────────────────┐  height: 36dp (unchanged)
│ ╔══════════════════╗                         │  track: borderSubtle (full opacity)
│ ║  ≡ List          ║   🗺 Map                │  pill: paperPrimary @ 18% opacity → readable teal tint
│ ╚══════════════════╝                         │  selected label: paperPrimary w600 (unchanged)
└─────────────────────────────────────────────┘
```

### Rationale vs. alternatives

**Alternative considered: solid white pill with `paperPrimary` text.** Rejected — a solid white pill on a beige track would read as a floating element competing with the `PrimaryButton` above it. The goal is a subordinate control that's readable but not dominant.

**Alternative considered: `paperPrimary` border on the track.** Rejected — adds a second strong-teal element directly below the already teal `PrimaryButton`. The track should be neutral.

---

## Defect 3 — Filter chip row separator is semantically ambiguous

### Current state

`_ChipSeparator` (lines 27–41) renders a 1dp × 20dp vertical bar in `paperBorderSubtle` with 8dp horizontal margin. The row reads: `Anytime | Tonight | This week ┃ Drinks | Food | Hike …`. The vertical bar is the sole visual signal that time and category chips belong to different filter groups. It has no label. A new user sees a horizontal list of pills with a small divider of unknown meaning.

### Why this matters for Singapore launch

Tribely's empty state at launch is the only thing new users see. The filter row is the first interactive surface they touch. If they don't understand that "Anytime / Tonight / This week" are time filters and "Drinks / Food" are category filters, they may not use the row at all — and miss that categories are multi-selectable while time is single-select.

### Decision: retain the separator; add a section label above the chip row on first visible render only

**The separator itself is kept** — it is a correct semantic boundary. The problem is not the separator; it is the absence of a label for either group. Adding floating labels above a horizontal scroll row is impractical (they would scroll with the chips and anchor oddly). The pragmatic fix: a non-scrolling header line sits above the chip row, visible only on the initial view before scroll.

However, adding a persistent header line above the chip row would add 18dp of permanent height — vertical space that is already at a premium above the empty state. The better approach is to add a `tooltip`-style group label that lives outside the scroll viewport.

**Revised approach: two labeled rows instead of one horizontal scroll.**

Replace the single `FilterChipRow` horizontal scroll with two stacked rows:
- **Row 1 (time):** `Anytime`, `Tonight`, `This week` — single-select, no scroll (three chips fit on the narrowest supported width of 320pt).
- **Row 2 (category):** horizontally scrollable, full chip set with ShaderMask fade at right edge.

A group label (`caption/13`, `paperInkSecondary`) precedes each row in the vertical stack. The separator widget is removed — it becomes unnecessary when groups are stacked.

```
┌────────────────────────────────────────────────────────┐
│  When                                                  │  ← caption/13, paperInkSecondary, left: 16
│  [Anytime]  [Tonight]  [This week]                     │  ← 36dp chips, single-select, no scroll
│                                                        │  ← 8dp gap
│  Category                                              │  ← caption/13, paperInkSecondary, left: 16
│  [Drinks] [Food] [Hike] [Museum] [Sports] ...  ↣       │  ← 36dp chips, multi-select, scrollable + fade
└────────────────────────────────────────────────────────┘
```

**Height budget:** Two-row layout height = (18dp label + 4dp gap + 44dp chip row) × 2 + 8dp between groups = ~142dp. Current single-row layout = 44dp. Net addition: ~98dp. This is used toward the tighter vertical rhythm in Defect 4 — see below for how the overall vertical stack remains balanced.

**Group labels — verbatim copy:**
- Time row label: `When`
- Category row label: `Category`

These are the shortest unambiguous labels. "Time" reads as wall-clock time, not time window. "When" is the word used in the create-event form (Step 3 "When is it?") — consistent vocabulary.

**Distance chips:** When location permission is granted, distance chips (`_SingleSelectChip` variants) appear as a third row below Category with label `Distance`. The `showDistanceChips` prop on `FilterChipRow` remains the control gate. The separator is removed; the row follows the same pattern.

### Token reuse

All tokens are existing. The group label uses `TribelyType.caption(TribelyColors.paperInkSecondary)` — already used in the chip row area. No new tokens.

### State coverage

All chip states (selected / unselected / pressed) are unchanged from current implementation. `_SingleSelectChip`, `_MultiSelectChip`, and `_ChipBase` internals do not change. Only the layout containing them changes.

### Rationale vs. alternatives

**Alternative: tooltip on the separator (long-press reveals "Time | Category" label).** Rejected — discoverability is low. First-time users won't long-press a hairline divider.

**Alternative: static tab labels pinned left of the scroll viewport.** Rejected — the labels would overlay the scroll shadow, require layout rework of the `ShaderMask`, and create clipping ambiguity at the left edge.

**Alternative: keep single row, add Cupertino-style group header above entire row.** Partially considered. A single header "Filters" above the whole row does not distinguish the two groups — it just names the area. Rejected in favor of per-group labels.

---

## Defect 4 — Empty-state vertical rhythm

### Current state

`EmptyState.build()` uses `MainAxisAlignment.center` with fixed `SizedBox(height: 16)` between icon and headline, `SizedBox(height: 8)` between headline and body, and `SizedBox(height: 24)` between body and CTA (lines 32–60). On a 390pt-wide screen (iPhone 15 Pro), the content block is approximately 160dp tall and is absolutely centered in the available height. With the screen's available height after sticky bottom container (~600dp on a 844dp-tall screen), the content sits in the middle of a large beige void — ~220dp empty above, ~220dp empty below. This reads as sparse and unwelcoming.

### Decision: shift the content block upward and add a context hint below

Two changes:

1. **Vertical alignment: change from `MainAxisAlignment.center` to a padded column with explicit top offset.** Use a `Column` with `crossAxisAlignment: CrossAxisAlignment.center` inside a `Padding` with `top: 120dp, horizontal: 32dp`. This places the content block in the upper-middle third of the screen rather than the geometric center — the optical center for a single-focus screen (consistent with iOS splash screens, Airbnb empty states, Stripe empty dashboards). The bottom void becomes positive breathing room rather than dead space.

2. **Add a warm supporting hint line below the CTA.** A `caption/13 italicCaption` line in `paperInkSecondary` sits 20dp below the "Start hosting →" link:
   > "Events from Singapore travelers will appear here."
   
   This gives new users who are not ready to create an event a reason to come back — the screen promises future content rather than feeling like a dead end.

### Specified layout — full empty-state block (noEventsInArea)

```
┌────────────────────────────────────────────────────────┐
│  [screen top / safe area + zone 1 title + zone 2 filters]
│                                                        │
│  ↕ 120dp top padding                                   │
│                                                        │
│              [explore_outlined]                        │  ← 48dp icon, paperInkSecondary
│                                                        │  ← 20dp gap (was 16dp)
│           No events in Singapore yet                   │  ← headline/22 semibold, paperInkPrimary
│                                                        │  ← 10dp gap (was 8dp)
│      Be the first to host something.                   │  ← bodyM/15, paperInkSecondary
│                                                        │  ← 16dp gap (was 24dp — hero CTA was large)
│              Start hosting →                           │  ← caption/13 medium, paperPrimary, underlined
│                                                        │  ← 20dp gap
│   Events from Singapore travelers will appear here.    │  ← italicCaption/13, paperInkSecondary, center
│                                                        │
│  ↕ remaining space (flexible)                          │
│                                                        │
│  [sticky bottom container: PrimaryButton + toggle]     │
└────────────────────────────────────────────────────────┘
```

**Icon change:** Size reduces from 56dp (current) to 48dp. At 56dp the icon was the dominant element, competing with the headline. At 48dp it reads as a decorative accent. Token unchanged: `paperInkSecondary`.

**Supporting hint line — verbatim copy:**
> "Events from Singapore travelers will appear here."

Style: `TribelyType.italicCaption(TribelyColors.paperInkSecondary)`. `italicCaption` is an existing token in `TribelyType` — no new type token needed. `textAlign: TextAlign.center`. Horizontal padding inherited from the parent `Padding(horizontal: 32)`.

### What this achieves vs. adding illustration or art

Adding editorial illustration (compass rose, travel map, etc.) was considered and rejected. Illustrations require new assets, asset pipeline additions, and dark-mode variants. The two-row filter layout (Defect 3) already adds ~98dp of structured content above the empty state — the screen feels less empty once filters are legible. The italic hint line adds warmth at zero asset cost. This is the appropriate level of intervention for a cleanup ticket.

### Token reuse

| Element | Token | New? |
|---|---|---|
| Icon | `paperInkSecondary`, 48dp | No — size change only |
| Headline | `TribelyType.headline`, `paperInkPrimary` | No |
| Body | `TribelyType.bodyM`, `paperInkSecondary` | No |
| Text link | `TribelyType.caption`, `paperPrimary` | No |
| Hint line | `TribelyType.italicCaption`, `paperInkSecondary` | No — existing token |

No new tokens required.

---

## Combined "noEventsMatchFilters" flavor — unchanged

The `DiscoverEmptyReason.noEventsMatchFilters` flavor (headline "Nothing here yet", body "Try a different time or category.", CTA "Reset filters" `SecondaryButton`) is **not affected** by this spec. The defects described above apply only to the `noEventsInArea` flavor. The `_buildCta` switch and the `_headline` / `_body` switch in `empty_state.dart` must retain the existing `noEventsMatchFilters` branch without modification.

---

## Accessibility

**Text link touch target:** The "Start hosting →" caption text is 13sp — below the 44pt minimum. The wrapping `GestureDetector` or `InkWell` must apply `padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16)` to bring the total tap target to ≥40dp height. This matches the `_kChipTapTargetPadding` pattern already used in `filter_chip_row.dart`.

**Chip group labels:** The "When" and "Category" labels above each chip row must be excluded from focus order; they are presentational (`Semantics(excludeSemantics: true)`). The chips themselves already carry label semantics via their text content.

**Toggle contrast (Defect 2):** At `paperPrimary @ 0.18 alpha` on `paperBorderSubtle` track, the selected segment tint is approximately #E4EDEC. Against `paperSurfaceHigh` the contrast of the tint is low — but the contrast of the **text** (`paperPrimary` on `paperSurface`) is ≈10.5:1, well above WCAG AA. Color is never the sole signal — the label weight (w600 vs w500) differentiates selected from unselected for users who cannot distinguish the tint.

**Hint line:** `italicCaption` at 13sp italic may be borderline for very low-vision users. It is purely supplementary — removing it from the accessibility tree is not warranted, but ensure `paperInkSecondary` (#5C544A) on `paperSurface` (#FAF6EF) maintains its current contrast ratio (≈5.7:1 — passes WCAG AA for normal text).

---

## Handoff notes for SWE

**Files to edit:**

- `apps/mobile/lib/src/features/discover/presentation/widgets/empty_state.dart`
  - Defect 1: In `_buildCta`, replace `PrimaryButton` for `noEventsInArea` with a styled text link (`GestureDetector` + `Text`). Update `_body` for `noEventsInArea` to `'Be the first to host something.'` (remove period if currently without, add if absent — confirm current exact string).
  - Defect 4: Change `MainAxisAlignment.center` to `MainAxisAlignment.start`. Change outer `Padding` from `symmetric(horizontal: 32)` to `fromLTRB(32, 120, 32, 0)`. Adjust `SizedBox` heights per spec. Add hint line `Text` below the CTA. Change icon size from 56 to 48. Remove `PrimaryButton` import if no longer used.

- `apps/mobile/lib/src/features/discover/presentation/pages/discover_page.dart`
  - Defect 1: No change needed — sticky CTA survives as-is.
  - No other changes.

- `apps/mobile/lib/src/features/discover/presentation/widgets/discover_tab_switcher.dart`
  - Defect 2: Line 78 — change `paperBorderSubtle.withValues(alpha: 0.50)` to `TribelyColors.paperBorderSubtle` (remove alpha).
  - Defect 2: Line 92 — change `paperPrimary.withValues(alpha: 0.12)` to `TribelyColors.paperPrimary.withValues(alpha: 0.18)`.

- `apps/mobile/lib/src/features/discover/presentation/widgets/filter_chip_row.dart`
  - Defect 3: Replace single-row horizontal scroll with two labeled rows. Remove `_ChipSeparator` widget. Add group label `Text` widgets above each chip row. Time chips remain single-select (`_SingleSelectChip`). Category chips remain multi-select (`_MultiSelectChip`) in a `SingleChildScrollView` with `ShaderMask`. If `showDistanceChips` is true, add a third labeled row with label "Distance". Controller bindings and chip internal behavior are unchanged.

**Copy assets — verbatim:**

| Location | Old copy | New copy |
|---|---|---|
| `empty_state.dart` hero CTA | "Create an event" (button) | "Start hosting →" (text link) |
| `empty_state.dart` hint line | (new, did not exist) | "Events from Singapore travelers will appear here." |
| `filter_chip_row.dart` group label 1 | (new) | "When" |
| `filter_chip_row.dart` group label 2 | (new) | "Category" |
| `filter_chip_row.dart` group label 3 | (new, distance only) | "Distance" |

**What stays unchanged:**
- `discover_page.dart` sticky `PrimaryButton` — label, route, position, styling all unchanged.
- `empty_state.dart` `noEventsMatchFilters` flavor — headline, body, `SecondaryButton` CTA all unchanged.
- `_SingleSelectChip`, `_MultiSelectChip`, `_ChipBase` implementations — internal styling unchanged.
- `DiscoverTabSwitcher` animation controller, duration, curve, layout delegate — unchanged.
- All tokens in `colors.dart` and `typography.dart` — no additions, no changes.

---

## Open questions

**EL (technical):** The two-row `FilterChipRow` layout (Defect 3) changes the widget's intrinsic height from ~44dp to ~142dp. This propagates upward to `DiscoverPage`'s `Column`, which uses `FilterChipRow` as a non-expanded child (Zone 2, line 74). The expanded `IndexedStack` (Zone 3) will shrink proportionally. Confirm the Zone 3 shrink does not clip the `DiscoverListTab` content area in a way that hides content on short devices (320pt height / iPhone SE 1st gen). If it does, the filter row height budget needs revisiting with the EL.

**PM (scope):** The hint line "Events from Singapore travelers will appear here." is new copy. Does this require sign-off from the CEO/brand before shipping, or is this within the designer/PM purview for a cleanup ticket?

---

*TRI-96 spec — closes four visual defects on the Discover empty-state surface.*
*Implementation effort: S (all changes are in existing widgets; no new screens, no new routes, no new data).*
