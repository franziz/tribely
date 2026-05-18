# TRI-97 — Bottom-Nav Indicator Theme Fix

*Spec version 1.0 — 2026-05-18 — design deliverable.*
*Author: ui-ux-designer agent.*

---

## Summary

Material 3's `NavigationBar` renders its selected-destination indicator as a filled pill using `ColorScheme.secondaryContainer` by default. In `AppTheme`, `secondaryContainer` is not overridden in the `ColorScheme` constructor — the `ColorScheme.light(secondary: TribelyColors.paperAccent, ...)` call lets M3 auto-generate `secondaryContainer` from `secondary` (ember coral, `#D85730`). M3 generates `secondaryContainer` as a light tint of the secondary — approximately a warm orange-peach (`#FCE4DC`, which is `paperAccentSoft`). On `paperSurface`, an orange-peach pill behind each selected nav icon clashes with the calm cream/teal palette established by TRI-87, TRI-88, and TRI-61.

This spec defines a single `navigationBarTheme:` block in `AppTheme._build()` that brings the nav-bar indicator in line with the Equatorial Editorial language. One file, one theme block, no new tokens.

---

## Current state (annotated)

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ╔═══════════════════╗                                  │  ← selected indicator pill:
│  ║   [compass icon]  ║   [event icon]  [person icon]   │    secondaryContainer auto-gen ≈ #FCE4DC
│  ║   Discover        ║   My Events     Profile          │    (warm orange-peach — clashes with palette)
│  ╚═══════════════════╝                                  │
│                                                         │
│  Bottom nav height: M3 default (80dp)                   │
│  Nav background: not overridden → ColorScheme.surface   │
└─────────────────────────────────────────────────────────┘
```

---

## Decision: teal-tinted indicator pill

### Chosen treatment

The selected indicator uses a low-opacity tint of `paperPrimary` (dark teal, #1B3D3A) — consistent with how `DiscoverTabSwitcher` renders its selected pill. The vocabulary is already established: `paperPrimary @ 0.12–0.18 alpha` on a surface background = "selected element in a navigation control."

**Indicator color: `paperPrimary.withValues(alpha: 0.12)`**

At this opacity the indicator on `paperSurface` (#FAF6EF) renders as a subtle warm-teal tint (#E7EDEC). It is visually distinct from the unselected destinations without introducing a strong accent. The selected icon and label switch to `paperPrimary` (full opacity), providing the primary contrast signal. Color is never the sole signal — the selected destination also receives the filled icon variant (`selectedIcon` in `NavigationDestination`).

### Nav bar background

M3's `NavigationBar` background defaults to `ColorScheme.surfaceContainer`. This is not mapped in `AppTheme`'s `ColorScheme`, so it may resolve to a Material 3 generated tint. Override to `paperSurface` explicitly so the nav bar reads as an extension of the screen surface, not a separate panel. (On dark mode: `nightSurface`.)

A 1dp top border in `paperBorderSubtle` (light) / `nightBorderSubtle` (dark) replaces M3's default elevation shadow and provides a clean edge between the nav bar and the screen body — consistent with how `_StickyBottomContainer` in `discover_page.dart` uses `Container(height: 1, color: borderSubtle)` as a top divider.

### Label behavior

M3's `NavigationBar` defaults to `labelBehavior: NavigationDestinationLabelBehavior.alwaysShow`. Keep this. Hiding labels (`onlyShowSelected` or `alwaysHide`) reduces discoverability on a 3-destination bar — especially at MVP when users are learning what the tabs contain.

**Selected label style:** `TribelyType.caption(TribelyColors.paperPrimary)` — 13sp/w500, teal.
**Unselected label style:** `TribelyType.caption(TribelyColors.paperInkSecondary)` — 13sp/w500, muted.

### Icon treatment

**Selected icon:** filled variant, `paperPrimary`. Already using `selectedIcon: Icon(Icons.explore)` (filled) vs `icon: Icon(Icons.explore_outlined)` in `app_shell.dart` — this is correct and requires no change.
**Unselected icon:** outlined variant, `paperInkSecondary`. Requires color override in the theme.

### Dark mode

The same theme block handles dark mode via the brightness-aware `_build()` factory. Values:

| Property | Light | Dark |
|---|---|---|
| Indicator color | `paperPrimary @ 0.12` | `nightPrimary @ 0.18` |
| Background | `paperSurface` | `nightSurface` |
| Selected icon | `paperPrimary` | `nightPrimary` |
| Selected label | `paperPrimary` | `nightPrimary` |
| Unselected icon | `paperInkSecondary` | `nightInkSecondary` |
| Unselected label | `paperInkSecondary` | `nightInkSecondary` |

Dark mode note: `nightPrimary` is burnished brass (#D5A86F), not teal — the Equatorial Night palette swaps the primary for a warm brass to maintain editorial warmth in the dark theme. This is correct; do not force dark-teal in dark mode.

Dark mode indicator uses `nightPrimary @ 0.18` (slightly higher than light's 0.12) because the `nightSurface` (#131110) provides less contrast to a tinted pill — a slightly higher opacity is needed to maintain readability of the selected state.

---

## Specified layout — after fix

```
LIGHT MODE
┌─────────────────────────────────────────────────────────┐
│  ── 1dp border: paperBorderSubtle ─────────────────────  │
│                                                         │
│       ╔═══════════╗                                     │  ← indicator: paperPrimary @ 12% alpha
│       ║  [compass]║   [event-outline]  [person-outline] │    teal-tinted pill (subtle, not orange)
│       ║  Discover ║   My Events        Profile          │
│       ╚═══════════╝                                     │
│         (teal)       (muted)            (muted)          │  ← label colors
│                                                         │
│  Background: paperSurface (#FAF6EF)                     │
└─────────────────────────────────────────────────────────┘

DARK MODE
┌─────────────────────────────────────────────────────────┐
│  ── 1dp border: nightBorderSubtle ─────────────────────  │
│                                                         │
│       ╔═══════════╗                                     │  ← indicator: nightPrimary @ 18% alpha
│       ║  [compass]║   [event-outline]  [person-outline] │    warm brass tint
│       ║  Discover ║   My Events        Profile          │
│       ╚═══════════╝                                     │
│         (brass)      (muted)            (muted)          │
│                                                         │
│  Background: nightSurface (#131110)                     │
└─────────────────────────────────────────────────────────┘
```

---

## State coverage

| State | Indicator fill | Icon | Label |
|---|---|---|---|
| Selected (light) | `paperPrimary` @ 12% alpha | `paperPrimary` (filled icon) | `paperPrimary`, w600 |
| Unselected (light) | none (transparent) | `paperInkSecondary` (outlined icon) | `paperInkSecondary`, w500 |
| Selected (dark) | `nightPrimary` @ 18% alpha | `nightPrimary` (filled icon) | `nightPrimary`, w600 |
| Unselected (dark) | none (transparent) | `nightInkSecondary` (outlined icon) | `nightInkSecondary`, w500 |
| Pressed (any) | indicator color @ +8% alpha (M3 state layer) | unchanged | unchanged |

The pressed state uses M3's built-in state-layer ripple mechanism — no custom interaction needs to be specified. `NoSplash.splashFactory` is applied globally in `AppTheme` (`splashFactory: NoSplash.splashFactory`), which suppresses the ink ripple. The M3 `NavigationBar` uses a `Container`-based hover/press highlight separate from the ink — confirm whether `NoSplash` suppresses this too. If the pressed indicator overlay disappears entirely (no visual feedback on tap), the SWE should apply a separate `overlayColor` on the `NavigationBarTheme` using `WidgetStateProperty` to restore a subtle tap state.

---

## Token mapping for the `navigationBarTheme:` block

| M3 `NavigationBarThemeData` property | Light value | Dark value |
|---|---|---|
| `backgroundColor` | `paperSurface` | `nightSurface` |
| `indicatorColor` | `paperPrimary.withValues(alpha: 0.12)` | `nightPrimary.withValues(alpha: 0.18)` |
| `indicatorShape` | `RoundedRectangleBorder(radius: 16)` | same |
| `iconTheme` — selected | `IconThemeData(color: paperPrimary, size: 24)` | `IconThemeData(color: nightPrimary, size: 24)` |
| `iconTheme` — unselected | `IconThemeData(color: paperInkSecondary, size: 24)` | `IconThemeData(color: nightInkSecondary, size: 24)` |
| `labelTextStyle` — selected | `TribelyType.caption(paperPrimary).copyWith(fontWeight: FontWeight.w600)` | `TribelyType.caption(nightPrimary).copyWith(fontWeight: FontWeight.w600)` |
| `labelTextStyle` — unselected | `TribelyType.caption(paperInkSecondary)` | `TribelyType.caption(nightInkSecondary)` |
| `labelBehavior` | `NavigationDestinationLabelBehavior.alwaysShow` | same |
| `elevation` | `0` (border handles separation) | `0` |
| `surfaceTintColor` | `Colors.transparent` | same |
| `shadowColor` | `Colors.transparent` | same |

`iconTheme` takes a `WidgetStateProperty<IconThemeData>` that resolves against `WidgetState.selected`. The SWE should use `WidgetStateProperty.resolveWith(...)` to return the selected vs. unselected `IconThemeData` based on whether `states.contains(WidgetState.selected)`.

Same pattern for `labelTextStyle`.

**Indicator pill radius:** M3 default is a stadium (fully rounded) pill — `StadiumBorder()`. This spec overrides to `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` — a 16dp rounded rectangle rather than a full stadium. Rationale: the `DiscoverTabSwitcher` pill uses `BorderRadius.circular(10)` and `PrimaryButton` uses a full-rounded shape. A 16dp rounded rect for the nav indicator sits between these two extremes, reading as a navigation-tier element (larger than a tab pill, less rounded than a full-bleed button). If the M3 stadium default is preferred for its simplicity, this is a judgment call for the EL — flag as an open question.

---

## The 1dp border implementation

M3 `NavigationBar` does not natively support a top border through its theme. The SWE has two options:

**Option A (preferred):** Wrap the `NavigationBar` in a `DecoratedBox` that adds a `BoxDecoration` with `border: Border(top: BorderSide(color: borderSubtle, width: 1))`. The `Scaffold.bottomNavigationBar` accepts any widget — the `DecoratedBox` wrapping `NavigationBar` is valid.

**Option B:** Override `AppShell` to render the `NavigationBar` inside a `Column` with a `Container(height: 1, color: borderSubtle)` above it — same pattern as `_StickyBottomContainer` in `discover_page.dart`. This is more readable for other engineers unfamiliar with `DecoratedBox` on the nav bar.

Either option is acceptable. The SWE should pick based on Flutter version/M3 API behavior at implementation time. Do not use a `BoxShadow` or `elevation` to fake the border — shadow softness reads differently from the crisp 1dp divider used elsewhere in the app.

---

## `app_shell.dart` — expected changes

The `AppShell` body currently passes `NavigationBar` directly to `Scaffold.bottomNavigationBar` with no theme overrides inline. After this change:

- No inline `NavigationBarTheme.data(...)` wrapper is needed in `app_shell.dart` — the root theme handles it.
- If any theme override was previously added to `app_shell.dart` to patch the orange indicator, remove it. Let the root theme be the sole source of truth.
- Add the 1dp top border wrapping (per the implementation choice above — either `DecoratedBox` or `Column` wrapper).
- No other changes to `app_shell.dart`.

---

## Reuse signals

| Element | Reusing | Source |
|---|---|---|
| Indicator fill logic (primary @ 12% alpha) | Yes — identical to `DiscoverTabSwitcher` pill | `discover_tab_switcher.dart` line 92 |
| Top border / divider pattern | Yes — identical to `_StickyBottomContainer` divider | `discover_page.dart` line 148 |
| `TribelyType.caption` for labels | Yes — existing token | `typography.dart` |
| All color tokens | Yes — all existing | `colors.dart` |

No new tokens required. No new design system guideline entry required. This is a theme application, not a new pattern.

---

## Rationale vs. alternatives

**Alternative 1: keep `secondaryContainer` orange; rely on icon differentiation only.** Rejected — the orange pill is the defect. The filled/outlined icon switch already handles icon-only differentiation; the filled pill's purpose is to communicate the selected destination at a glance before the user reads the label. An orange pill on a teal-primary app reads as accidental, not intentional.

**Alternative 2: no indicator pill; rely on icon fill + label weight alone.** Acceptable on iOS (iOS 17's tab bar has no pill). Rejected for M3/Android — removing the indicator would deviate from Material 3's navigation bar spec and the mental model Android users have for selected state. Also rejected because the spec already uses a pill indicator on `DiscoverTabSwitcher` — consistency within the app argues for keeping the pill at the nav level.

**Alternative 3: solid `paperPrimary` pill (no alpha).** Rejected — a solid dark-teal pill on `paperSurface` would dominate the nav bar, making the selected icon nearly invisible (the filled icon sits on a very dark fill). The low-alpha tint keeps the icon legible while marking the selected state.

**Alternative 4: `paperSurfaceHigh` (#FFFFFF) white pill.** Considered. A white pill on the warm beige surface reads cleanly, is zero-ambiguity about being a selection indicator, and has strong precedent (Google Maps bottom nav). Rejected in favor of the teal tint because a white pill on `paperSurface` would look like an elevated card element, conflating selection with elevation. The teal tint is more semantically precise.

---

## Accessibility

**Color is not the sole signal.** Selected state is conveyed by: (1) filled vs. outlined icon, (2) teal vs. muted label color, (3) teal pill indicator, (4) `NavigationDestination` semantics (M3 automatically marks selected destination in the accessibility tree). Removing any one of these signals leaves the others intact.

**Label contrast:** `paperPrimary` (#1B3D3A) on `paperSurface` (#FAF6EF) ≈ 10.5:1. Passes WCAG AA. `paperInkSecondary` (#5C544A) on `paperSurface` ≈ 5.7:1. Passes WCAG AA.

**Touch targets:** M3 `NavigationDestination` tap targets are 48dp minimum by the M3 spec. The `NavigationBar` height default (56–80dp) satisfies this. No additional padding needed.

---

## Open questions

**EL (technical):** Confirm that `NoSplash.splashFactory` (globally applied in `AppTheme`) does not suppress the M3 `NavigationBar` pressed state overlay entirely. If it does, the SWE must add an `overlayColor: WidgetStateProperty.resolveWith(...)` in `NavigationBarThemeData` to restore a perceptible press state (suggested: `paperPrimary.withValues(alpha: 0.08)` on pressed for light mode).

**EL (technical):** The indicator pill radius override (`BorderRadius.circular(16)` vs. `StadiumBorder()`) is a minor aesthetic call. If the M3 stadium default is simpler to implement cleanly, the stadium shape is acceptable — the critical fix is the color, not the corner radius.

---

## Handoff notes for SWE

**File to edit:** `apps/mobile/lib/src/core/theme/app_theme.dart`

Add a `navigationBarTheme:` property to the `ThemeData(...)` returned by `_build()`. The theme block should be brightness-aware — the existing `_build()` signature receives `brightness`, `scheme`, `surface`, `ink`, and `inkSecondary`. Add `primary` and `primaryHover` color parameters, or derive them inside `_build()` using `brightness == Brightness.light ? TribelyColors.paperPrimary : TribelyColors.nightPrimary`.

**File to edit (minor):** `apps/mobile/lib/src/core/router/app_shell.dart`

Add the 1dp top border wrapper around the `NavigationBar` widget per the chosen implementation option (A or B above). Remove any inline `NavigationBarTheme` wrappers if they exist (confirm with `grep NavigationBarTheme apps/mobile/lib/src/core/router/app_shell.dart` — currently the file shows none, so this step may be a no-op).

**No changes to:**
- `NavigationDestination` definitions in `app_shell.dart` — icons, labels, routes all remain.
- `go_router` branch configuration.
- Any other theme block in `AppTheme`.

---

*TRI-97 spec — closes the bottom-nav orange indicator defect, app-wide.*
*Implementation effort: XS (one `ThemeData` property block in one file; minor wrapper in app_shell).*
