# Tribely In-App Selector Spec (TRI-61)

## Summary

Create-event is Tribely's primary host-conversion surface. The current Step 1 category field is a stock Flutter `DropdownButtonFormField` — a system-rendered overlay control that breaks visual continuity with the Equatorial Editorial design language. The current Step 3 date/time pickers chain stock `showDatePicker` + `showTimePicker` — Material calendar and clock widgets that read as generic Android-era UI on both iOS and Android. Both patterns were acceptable scaffolding; neither is acceptable at launch quality.

This spike establishes two reusable bottom-sheet selector patterns — **Pattern A (single-select)** and **Pattern B (date + time)** — implemented in design language only. No Flutter/Dart code appears in this document. A downstream implementation ticket will build them. The spec is self-contained: a cold software-engineer with no prior context should be able to build both patterns from this document without follow-up.

---

## Adopting surfaces (named) + TRI-59 coordination stance

| Surface | Pattern | Field | Notes |
|---|---|---|---|
| Create-event Step 1 | Pattern A — Single-select | `category` → `EventCategory?` | Replaces `DropdownButtonFormField` |
| Create-event Step 3 | Pattern B — Date | `startsAt` / `endsAt` (date component) | Replaces `showDatePicker` |
| Create-event Step 3 | Pattern B — Time | `startsAt` / `endsAt` (time component) | Replaces `showTimePicker` |

**TRI-59 (venue picker) — YES, co-adopts Pattern A vocabulary.**

The venue picker is a selection sheet where the user picks a place from a list (search results or recent). It shares the same structural needs: a bottom sheet, a list of selectable rows, a single-select interaction, a dismiss-on-tap pattern. It differs only in row content (place name + address sub-label instead of icon + category name) and in having a search field in the sheet header.

TRI-59 must adopt the same drag handle dimensions, top-corner radius, header divider, row minimum height, selected-state indicator, and safe-area padding defined in Pattern A below. The sheet header can extend Pattern A's header zone with a search `TribelyTextField` between the headline and the divider — that extension does not require a new guideline ask, as it is additive within the same bottom-sheet container vocabulary.

**TRI-58 (map tile polish)** — different surface, no direct interaction with either pattern. No coordination required.

**TRI-54 (native "Done" keyboard dismissal)** — the keyboard-on-sheet-open L-risk answer below is explicitly consistent with TRI-54. Both patterns call `FocusManager.instance.primaryFocus?.unfocus()` before opening a sheet.

---

## Pattern A — Single-select (category)

### Layout + hierarchy

The trigger is a tappable row that replaces the `DropdownButtonFormField` in Step 1. The row uses the same border/radius/padding conventions as `EventFormField` for visual rhythm — the form reads as one consistent input vocabulary.

**Trigger row (inline in Step 1 scroll)**

```
┌─────────────────────────────────────────────────┐
│  [icon 18dp]  Category label     [chevron_right] │   56dp min height
│               Selected value or "Tap to select"  │   HorzPad 16, VertPad 14
└─────────────────────────────────────────────────┘
  border: paperBorderSubtle 1.5dp, radius 12
  on error: paperAccent 1.5dp (matches EventFormField error border)
  on filled (value set): border stays paperBorderSubtle (not primary — this is not focused)
```

Top label is `caption/13 medium` in `paperInkSecondary`. Value text is `bodyM/15` in `paperInkPrimary` when a value is set; `paperInkSecondary` when empty ("Tap to select"). Leading icon: `Icons.category_outlined` at 18dp in `paperPrimary` when a value is set; `paperInkSecondary` when empty. Trailing `Icons.chevron_right` at 20dp in `paperInkSecondary` always.

**Bottom sheet**

Sheet occupies `isScrollControlled: true`, with `initialChildSize: 0.5`, `minChildSize: 0.4`, `maxChildSize: 0.65` if using `DraggableScrollableSheet`. In practice for 7 items the sheet will be intrinsic-height — the full list fits without scroll on any phone ≥375pt wide. Use a fixed-height non-scrollable `Column` with `mainAxisSize: MainAxisSize.min` wrapped in a `SafeArea`-aware container. Do NOT use `DraggableScrollableSheet` — the fixed height is appropriate and avoids scroll conflicts with the list.

```
┌──────────────────────────────────────────┐
│               ▬▬▬▬              ← drag handle: 32×4dp, paperBorderSubtle, radius 2, top pad 12, bottom pad 4
│  Choose a category              ← headline/22 semibold, paperInkPrimary, left pad 24, top pad 16
│──────────────────────────────────────────│  ← 1dp Divider, paperBorderSubtle
│  🍺  Drinks                   [✓]        │  ← selected row
│──────────────────────────────────────────│
│  🍜  Food                                │  ← unselected row
│──────────────────────────────────────────│
│  🥾  Hike                                │
│──────────────────────────────────────────│
│  🏛  Museum                              │
│──────────────────────────────────────────│
│  ⚽  Sports                              │
│──────────────────────────────────────────│
│  🌙  Nightlife                           │
│──────────────────────────────────────────│
│  …   Other                               │
│──────────────────────────────────────────│
│                                          │
│  [safe-area bottom pad]                  │
└──────────────────────────────────────────┘
```

**Sheet container:** `paperSurfaceHigh` background (matches `confirm_join_sheet.dart` exactly), `borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))`. No bottom rounded corners — sheet sits flush against the bottom edge.

**Row anatomy per category item:**

```
[row: 56dp min height, HorzPad 24]
  Leading: Icon 22dp — see icon map below — color: paperPrimary (selected) / paperInkSecondary (unselected)
  Gap: 16dp
  Label: bodyM/15, paperInkPrimary (selected) / paperInkSecondary (unselected)
  Trailing (selected only): Icons.check, 20dp, paperPrimary
  Trailing (unselected): nothing
```

**Category icon map (Material Icons):**

| Category | Icon |
|---|---|
| drinks | `Icons.local_bar_outlined` |
| food | `Icons.restaurant_outlined` |
| hike | `Icons.terrain` |
| museum | `Icons.account_balance_outlined` |
| sports | `Icons.sports_outlined` |
| nightlife | `Icons.nightlife` (`nightlight_round` as fallback) |
| other | `Icons.category_outlined` |

Row separator: 1dp `Divider` in `paperBorderSubtle` between every row. No separator after the last row before safe-area.

**Row pressed state:** `InkWell` with `splashColor: paperPrimary.withAlpha(20)`, `highlightColor: paperPrimary.withAlpha(10)`, `borderRadius: BorderRadius.zero` (full-width row). This matches the `InkWell` treatment in `_DateTimePicker` in Step 3.

### States

**Default (no value selected):** Trigger row shows "Tap to select" in `paperInkSecondary`. Leading icon in `paperInkSecondary`. No error border. Sheet rows show all 7 items unselected.

**Filled (value selected):** Trigger row shows `category.displayName` in `paperInkPrimary`. Leading icon switches to selected category's icon in `paperPrimary`. Sheet row for the selected item shows `paperPrimary` icon + label + trailing checkmark. Trigger row border remains `paperBorderSubtle` — there is no "focused" state for a non-text input trigger.

**Error:** Trigger row border switches to `paperAccent` 1.5dp. Error text `caption/13` in `paperAccent` appears below the trigger row with 4dp top gap and 12dp left inset — matching `EventFormField`'s error text placement. This state is entered when the user attempts to advance from Step 1 without selecting a category.

**Disabled:** Trigger row border at `paperBorderSubtle.withAlpha(128)`. Leading icon and chevron at `paperInkSecondary.withAlpha(128)`. Row tap does nothing. This state is not used in the MVP launch flow but is specified for completeness (e.g., if the controller enters a non-editing state).

**Loading:** Not applicable. Category list is static — see "Category list: static or fetched" answer below.

**Empty:** Not applicable. The list always has 7 items; there is no zero-item state.

### Dismiss interaction

**Tap on a row:** Immediately calls `controller.updateField(field: 'category', value: selectedCategory)`, then calls `Navigator.of(context).pop()`. The sheet closes in the standard bottom-sheet-out animation (medium/250ms, easeInCubic per Tribely motion system). No "Confirm" button is needed — single-select list with immediate dismiss is the convergent mobile pattern (iOS action sheet, Google Sheets category picker, Airbnb amenity filter, Uber category selector all use tap-to-select-and-dismiss).

**Drag to dismiss:** Enabled (`isDismissible: true`, `enableDrag: true`). If the user drags to dismiss without selecting, the current value (previously set or null) is unchanged. The sheet closes without calling `updateField`.

**Barrier tap:** Closes the sheet (same as drag to dismiss — no selection change).

**Back button (Android) / swipe back gesture (iOS):** Closes the sheet. Same as barrier tap.

### Visual reference (ASCII annotated)

```
TRIGGER ROW — Step 1 form, between Title field and Next button

  ┌─────────────────────────────────────────────────────┐
  │  [category_outlined: 18dp, inkSecondary]            │
  │  Category                         [chevron_right]   │   ← caption/13, inkSecondary
  │  Tap to select                                      │   ← bodyM/15, inkSecondary
  └─────────────────────────────────────────────────────┘
  border: paperBorderSubtle 1.5dp, radius 12

  [after selection, e.g. "Food"]
  ┌─────────────────────────────────────────────────────┐
  │  [restaurant_outlined: 18dp, paperPrimary]          │
  │  Category                         [chevron_right]   │   ← caption/13, inkSecondary
  │  Food                                               │   ← bodyM/15, inkPrimary
  └─────────────────────────────────────────────────────┘

  [error state, no value]
  ┌─────────────────────────────────────────────────────┐
  │  ...same layout...                                  │
  └─────────────────────────────────────────────────────┘  ← accent 1.5dp border
    Category is required                                    ← caption/13, paperAccent, left 12dp

BOTTOM SHEET

  ┌──────────────────────────────────────────────────────┐
  │                    ▬▬▬▬                              │  top:12, handle: 32×4, paperBorderSubtle
  │                                                      │
  │  Choose a category                                   │  headline/22, inkPrimary, left:24, top:16, bottom:12
  ├──────────────────────────────────────────────────────┤  Divider, paperBorderSubtle
  │  [local_bar]  Drinks                        [check]  │  56dp min, selected: icon+label paperPrimary, check shown
  ├──────────────────────────────────────────────────────┤
  │  [restaurant] Food                                   │  unselected: icon+label inkSecondary
  ├──────────────────────────────────────────────────────┤
  │  [terrain]    Hike                                   │
  ├──────────────────────────────────────────────────────┤
  │  [account_balance]  Museum                           │
  ├──────────────────────────────────────────────────────┤
  │  [sports]     Sports                                 │
  ├──────────────────────────────────────────────────────┤
  │  [nightlife]  Nightlife                              │
  ├──────────────────────────────────────────────────────┤
  │  [category]   Other                                  │
  └──────────────────────────────────────────────────────┘
     [safe-area bottom inset: MediaQuery.paddingOf(context).bottom + 8]
```

---

## Pattern B — Date + time

### Coupled or separated (and why)

**Decision: SEPARATED sheets. Date sheet first, then time sheet.**

Rationale:

The EL brief named the coupled approach as the "secretly-M" trap: if a single sheet collects both date and time, the cross-field validators (`validateStartsAt` and `validateEndsAt`) must fire inside the sheet — meaning the sheet itself must know about the sibling field's value, the 5-minute lead-time rule, and the end-must-be-after-start rule. That is controller logic leaking into a view component. The sheet becomes stateful in a way that isn't expressible in the existing `FormField`-plus-`updateField` wiring without rewriting the controller or passing it into the sheet.

Separated sheets avoid this entirely: the sheet surfaces a single value (a `DateTime?`), the user taps Confirm, the sheet pops and returns the value, the caller calls `controller.updateField(field: 'startsAt', value: dt)`, the controller runs `validateStartsAt` and `validateEndsAt` against the existing draft, and the cross-field error surfaces as it does today — on the trigger row via `errorText`. No cross-field logic touches the sheet.

A secondary benefit: separated sheets are narrower UI. The date sheet can use a compact calendar-style picker widget (CupertinoDatePicker or an equivalent compact widget — see Layout below) without also crowding in time controls. Time can be a clean list of 15-minute-increment rows that are faster to tap on than a clock wheel.

The two-step flow (date → time opens automatically after date confirm) keeps the total tap count identical to a coupled sheet while preserving separation of concerns.

### Layout + hierarchy

**Trigger rows (two, stacked, in Step 3 — one for "Starts at", one for "Ends at")**

These already exist as `_DateTimePicker` rows in `create_event_step3_when_page.dart`. The trigger row design is solid — 56dp min height, 16px HorzPad, `calendar_today_outlined` leading icon, label + value stacked column, `chevron_right` trailing. **Retain the existing trigger row layout exactly.** Only the picker that opens on tap changes.

The trigger now opens a **date sheet** (not `showDatePicker`). After the date sheet confirms, a **time sheet** opens automatically (chained, no additional user action required).

**Date sheet**

```
┌──────────────────────────────────────────────────────┐
│                    ▬▬▬▬                              │  drag handle: 32×4dp, top:12
│                                                      │
│  Pick a date                                         │  headline/22, inkPrimary, left:24, top:16
├──────────────────────────────────────────────────────┤  Divider
│                                                      │
│   [CupertinoDatePicker — dateOnly mode]              │  constrained height: 200dp
│                                                      │
│   Mode: CupertinoDatePickerMode.date                 │
│   Constraint: firstDate = DateTime.now() + 5min      │
│               lastDate  = DateTime.now() + 2 years   │
│   Use CupertinoDatePicker in dateOnly mode.          │
│   backgroundColor: paperSurfaceHigh                  │
│                                                      │
├──────────────────────────────────────────────────────┤  Divider
│  [PrimaryButton "Confirm date"]                      │  full-width, horiz pad 24, top:16
│  [TextButton    "Cancel"     ]                       │  body/15 inkSecondary, top:8
│                                                      │
│  [safe-area bottom inset]                            │  MediaQuery.paddingOf(context).bottom + 8
└──────────────────────────────────────────────────────┘
```

The Confirm button is enabled as long as a date is selected (it always starts with a selected date — the current draft value or today's date as the initial scroll position). It does NOT dismiss the sheet — it closes the date sheet and immediately opens the time sheet.

**Time sheet**

```
┌──────────────────────────────────────────────────────┐
│                    ▬▬▬▬                              │  drag handle: 32×4dp, top:12
│                                                      │
│  Pick a time                                         │  headline/22, inkPrimary, left:24, top:16
│  [date label: "Wed 14 May"]                          │  caption/13, inkSecondary, left:24, top:2, bottom:12
├──────────────────────────────────────────────────────┤  Divider
│                                                      │
│  [Scrollable list of time rows]                      │
│                                                      │
│   12:00 AM                                           │  56dp row, bodyM/15
│   12:15 AM                                           │    inkPrimary (available)
│   ...                                                │    inkSecondary.withAlpha(80) (past/unavailable)
│   [selected time row shows trailing check +          │
│    paperPrimary text color]                          │
│   ...                                                │
│   11:45 PM                                           │
│                                                      │
├──────────────────────────────────────────────────────┤  Divider
│  [PrimaryButton "Confirm time"]                      │  full-width, horiz pad 24, top:16
│  [TextButton    "Cancel"     ]                       │  top:8
│  [safe-area bottom inset]                            │
└──────────────────────────────────────────────────────┘
```

The time sheet is a scrollable list — NOT a wheel/drum roller. Each row is a 56dp `ListTile`-equivalent row with the time string in `bodyM/15`. 96 rows total (24 hours × 4 increments of 15 minutes). The list scrolls; the sheet height is fixed at approximately 60% of screen height with `isScrollControlled: true`.

**Time increment:** 15 minutes. Times displayed in 12-hour format with AM/PM (matches the existing `DateFormat('EEE d MMM y, h:mm a')` format used on the trigger row). Display as: `12:00 AM`, `12:15 AM`, `12:30 AM`, `12:45 AM`, `1:00 AM`, … `11:45 PM`.

**Initial scroll position:** On open, the list scrolls to center the currently-selected time (or the nearest 15-minute increment to the current time of day if no value is set). Use a `ScrollController` with `jumpTo` after the first frame to position the list without animation on open.

**Past time rows (for the current date):** If the picked date is today, times that are in the past (plus the 5-minute lead-time buffer) are rendered in `paperInkSecondary.withAlpha(80)` and are not tappable (`onTap: null`). Tapping a disabled row does nothing. If the picked date is any future date, all 96 rows are enabled.

**Time row tap:** Immediately updates the in-sheet selection state (trailing check + `paperPrimary` text). The user must then tap "Confirm time" to close the sheet and commit the value. This is intentional — an accidental tap on a list row should not fire `updateField`. The Confirm button is disabled until a time row is selected.

**Time selected then Confirm tapped:** The sheet pops and returns `DateTime(pickedDate.year, pickedDate.month, pickedDate.day, selectedHour, selectedMinute)`. The caller calls `controller.updateField(field: 'startsAt' (or 'endsAt'), value: combinedDateTime)`.

**Cancel on either sheet:** No value is set or changed. The entire date+time selection is abandoned. If the field already had a value, it is unchanged.

### States

**Trigger row — default (no value):** Existing `_DateTimePicker` unset state. "Tap to select" placeholder. Calendar icon in `paperPrimary`. No change needed.

**Trigger row — filled:** Existing format `DateFormat('EEE d MMM y, h:mm a')`. No change needed.

**Trigger row — error:** Existing `hasError` styling (accent border 2dp, error text in accent below row). No change needed.

**Date sheet — initial open (field has existing value):** CupertinoDatePicker scrolled to existing date. Confirm button enabled.

**Date sheet — initial open (field null, startsAt):** CupertinoDatePicker scrolled to tomorrow at the nearest 15-minute increment to now. Confirm button enabled.

**Date sheet — initial open (field null, endsAt):** If `startsAt` is set: tomorrow at `startsAt` time + 1 hour, rounded to nearest 15 minutes. If `startsAt` is not set: same as startsAt default.

**Time sheet — no selection yet:** Confirm button disabled (`PrimaryButton` with `onPressed: null` → disabled style). List scrolled to best-guess position. No row shows trailing check.

**Time sheet — row selected:** Confirm button enabled. Selected row: `paperPrimary` text + trailing `Icons.check` 20dp in `paperPrimary`. Previously-selected row (if any) reverts to unselected.

**Time sheet — past/unavailable row:** `paperInkSecondary.withAlpha(80)` text, `onTap: null`, no `InkWell` splash. No trailing check even if it is the closest to a previously stored value.

### Cross-field validator interaction (separated sheets)

Because the sheets are separated and return a single `DateTime?`, cross-field validation happens entirely in the existing controller on the trigger row's error display — not inside the sheet.

Sequence for "Starts at" field:
1. User taps "Starts at" trigger → date sheet opens.
2. User picks date, taps "Confirm date" → date sheet closes, time sheet opens (date passed as local state from sheet to sheet, never touching the controller).
3. User picks time, taps "Confirm time" → time sheet closes, `controller.updateField(field: 'startsAt', value: combinedDateTime)` fires.
4. Controller runs `validateStartsAt(combinedDateTime)` (5-minute lead-time check) and `validateEndsAt(draft.endsAt, combinedDateTime)` (end-after-start check).
5. `fieldErrors['startsAt']` and `fieldErrors['endsAt']` update. Both trigger rows re-render their error text inline.

No validator logic enters the sheet. The sheet is a pure value-picker that surfaces a `DateTime?` and pops. This is the key reason separated beats coupled for this codebase.

The time-decay problem (user sets `startsAt` = "in 10 minutes", lingers on later steps until it decays past the 5-minute buffer) is already handled by `refreshBlockingFields()` called on step transitions and on Step 5 resume. No new behavior needed.

### Visual reference

```
TRIGGER ROWS — Step 3 (existing layout, no visual change)

  ┌─────────────────────────────────────────────────────┐
  │  [calendar_today: 18dp, paperPrimary]               │
  │  Starts at                          [chevron_right] │
  │  Tap to select                                      │   inkSecondary
  └─────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────┐
  │  [calendar_today: 18dp, paperPrimary]               │
  │  Ends at                            [chevron_right] │
  │  Wed 14 May 2025, 7:30 PM                           │   inkPrimary (value set)
  └─────────────────────────────────────────────────────┘
  End time must be after start time                        ← caption/13, paperAccent, left:12

DATE SHEET

  ╔══════════════════════════════════════════════════════╗
  ║                    ▬▬▬▬                             ║  handle, top:12
  ║  Pick a date                                         ║  headline/22, left:24, top:16, bottom:12
  ╠══════════════════════════════════════════════════════╣  Divider
  ║                                                      ║
  ║    May   14   2026                                   ║  CupertinoDatePicker, h:200dp
  ║    ───   ──   ────                                   ║  dateOnly mode, paperSurfaceHigh bg
  ║    Jun   15   2027                                   ║
  ║                                                      ║
  ╠══════════════════════════════════════════════════════╣  Divider
  ║  [     Confirm date     ]                            ║  PrimaryButton, horiz pad:24, top:16
  ║          Cancel                                      ║  TextButton, inkSecondary, top:8
  ║  [safe-area bottom pad]                              ║
  ╚══════════════════════════════════════════════════════╝

TIME SHEET

  ╔══════════════════════════════════════════════════════╗
  ║                    ▬▬▬▬                             ║  handle, top:12
  ║  Pick a time                                         ║  headline/22, left:24, top:16
  ║  Wed 14 May                                          ║  caption/13, inkSecondary, left:24, top:2, bottom:12
  ╠══════════════════════════════════════════════════════╣  Divider
  ║  ...                                                 ║
  ║  6:00 AM    [past — muted inkSecondary, no tap]      ║  56dp row, horiz pad:24
  ║  6:15 AM    [past — muted]                           ║
  ║  6:30 AM    [past — muted]                           ║
  ║  6:45 AM    [past — muted]                           ║
  ║  7:00 AM    [SELECTED — paperPrimary text + check]   ║  ← trailing Icons.check, 20dp, paperPrimary
  ║  7:15 AM    [available]                              ║  inkPrimary text
  ║  7:30 AM    [available]                              ║
  ║  ...                                                 ║
  ╠══════════════════════════════════════════════════════╣  Divider
  ║  [     Confirm time     ]                            ║  PrimaryButton (enabled when row selected)
  ║          Cancel                                      ║  TextButton, top:8
  ║  [safe-area bottom pad]                              ║
  ╚══════════════════════════════════════════════════════╝

  Time rows: 56dp min height, Divider between rows (same as Pattern A rows)
  List height: fixed ~60% of screen, scrollable
  Initial scroll: jumpTo() after first frame to center selected or best-guess time
```

---

## A11y minimums (both patterns)

### Touch targets

Minimum 44pt on iOS, 48dp on Android. All interactive rows are 56dp min height — compliant on both platforms. Trigger rows are 56dp min height — compliant. Confirm button is `PrimaryButton` at 56dp — compliant. Cancel `TextButton` is 44dp min height by Material spec.

### Semantic labels on rows

**Pattern A (category rows):**

Each row must be wrapped in:

```
Semantics(
  label: "${category.displayName}${isSelected ? ', selected' : ''}",
  button: true,
  child: ...InkWell...
)
```

The selected state is announced via the label suffix, not via color alone. `button: true` ensures the row is identified as interactive. The sheet itself should be announced as a dialog on open: wrap the sheet root in `Semantics(label: "Choose a category", explicitChildNodes: true)`.

**Pattern B (time rows):**

Each time row:
```
Semantics(
  label: "${formattedTime}${isSelected ? ', selected' : ''}${isUnavailable ? ', unavailable' : ''}",
  button: isAvailable,
  enabled: isAvailable,
  child: ...
)
```

Unavailable/past rows: `button: false`, `enabled: false` on the Semantics node so screen readers announce them as non-interactive ("dimmed" or "unavailable" depending on platform).

The date sheet: `Semantics(label: "Pick a date dialog", explicitChildNodes: true)`. The `CupertinoDatePicker` has built-in accessibility — no additional wrapping needed.

### Focus order on open

When the sheet opens, focus should move to the first interactive element inside the sheet. Wrap the sheet's root Column in an `ExcludeFocus` (false) with a `FocusScope` that requests focus on the first row (Pattern A) or the date picker (Pattern B) after the first frame using `WidgetsBinding.instance.addPostFrameCallback`.

For Pattern A: first focus goes to the currently-selected row (if any) or the first row. This allows VoiceOver/TalkBack users to swipe-navigate from the selected item outward rather than from the top of the list.

For Pattern B date sheet: CupertinoDatePicker manages its own focus internally.

For Pattern B time sheet: first focus goes to the selected time row (or the first available row if none selected). Same rationale as Pattern A.

### Focus return on dismiss

When the sheet closes (any dismiss path — confirm, cancel, drag, barrier), focus must return to the trigger row that opened it. This is standard `Navigator.pop()` behavior on Flutter — the route below regains focus. No extra work needed as long as the trigger row is a `Focus`-able widget. Both `InkWell` and the existing `_DateTimePicker` container satisfy this.

### Screen-reader announcement of selection change

**Pattern A:** The act of tapping a row fires `Navigator.pop()` immediately. The selected value becomes visible in the trigger row. Announce the selection on the trigger row: use `SemanticsService.announce("${category.displayName} selected", TextDirection.ltr)` called immediately before the pop, so the announcement fires before the sheet closes. Do not rely on the trigger row rebuild alone — the rebuild timing is not guaranteed to beat the focus-return transition.

**Pattern B time sheet:** When the user taps a time row (before confirming), announce the selection: `SemanticsService.announce("$formattedTime selected", TextDirection.ltr)`. The row's Semantics label also updates (see above). On Confirm, no additional announcement is needed — the trigger row's updated value will be read when focus returns.

### Contrast

`paperPrimary` (#1B3D3A) on `paperSurfaceHigh` (#FFFFFF): contrast ratio ≈ 10.5:1 — passes WCAG AA (4.5:1 for normal text, 3:1 for large text). `paperInkSecondary` (#5C544A) on `paperSurfaceHigh` (#FFFFFF): contrast ratio ≈ 5.7:1 — passes WCAG AA. `paperAccent` (#D85730) on `paperSurfaceHigh` (#FFFFFF): contrast ratio ≈ 3.5:1 — passes WCAG AA for large text (error text is `caption/13 medium` — 13sp medium is borderline; 14sp would be safer; acceptable at launch). No contrast violations in the specified token combinations.

---

## L-risk call-outs (the three EL flagged)

### L-risk 1: Keyboard dismissal on sheet open

**Situation:** Create-event Step 1 has a `TribelyTextField` for the event title. The user may tap the title field, type, and then tap the "Category" trigger row without first dismissing the keyboard. If the keyboard is visible when the category sheet opens, the bottom sheet slides up behind the keyboard on some Android configurations, truncating its content.

**Specified behavior:** The trigger row's `onTap` handler (the InkWell's tap callback) must call `FocusManager.instance.primaryFocus?.unfocus()` **before** calling `showModalBottomSheet`. This is the identical pattern used in `CreateEventController.nextStep()` and `previousStep()`, which call `FocusManager.instance.primaryFocus?.unfocus()` before any state mutation. Apply the same call at the tap site on the trigger row — not in the controller, because the controller does not manage keyboard state for view-layer events.

This is consistent with TRI-54 (native "Done" keyboard dismissal). TRI-54 adds a "Done" button to the keyboard toolbar to dismiss the keyboard from a text field; this spec adds an imperative unfocus on picker trigger tap. The two coexist without conflict — TRI-54 handles keyboard-to-next-field navigation; this spec handles keyboard-to-picker navigation. Both result in keyboard dismissal before focus moves.

**For Step 3:** Step 3 has no text fields, so keyboard-on-sheet-open cannot occur in the normal flow. However, the `_DateTimePicker` trigger row should still call `FocusManager.instance.primaryFocus?.unfocus()` for defensive correctness (e.g., if the step page is navigated to with a keyboard already open from a different step).

**Implementation note:** Call order must be: `FocusManager.instance.primaryFocus?.unfocus()`, then `showModalBottomSheet(...)`. The unfocus call schedules a keyboard hide; the sheet open is synchronous. On iOS this is fine — the keyboard hide and sheet rise animate simultaneously, which is visually acceptable. On Android with `WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE`, the sheet will correctly occupy the full screen height after keyboard dismissal.

### L-risk 2: Screen-reader labels on bottom-sheet rows

**Specified behavior:** See "A11y minimums" section above for the complete Semantics specification per row and per sheet.

Key points for the engineer:
- Every tappable row gets a `Semantics` node with `label`, `button: true`, and `enabled` set.
- Selected state is in the label string suffix (", selected"), NOT conveyed by color alone.
- Unavailable time rows (past times in Pattern B) are non-interactive and announced as such via `enabled: false` and label suffix ", unavailable".
- `SemanticsService.announce(...)` fires on selection in Pattern A (before pop) and on time row tap in Pattern B.
- The sheet root carries a `label` describing the dialog purpose.
- No custom `CustomSemanticsAction` is needed — the above covers both VoiceOver (iOS) and TalkBack (Android).

### L-risk 3: iOS safe-area padding

**Specified behavior:** Both sheets must apply bottom padding equal to `MediaQuery.paddingOf(context).bottom + 8` to the last element's bottom margin (or as a `SizedBox` at the bottom of the Column). This is the exact pattern used in `confirm_join_sheet.dart` (line 199: `SizedBox(height: MediaQuery.paddingOf(context).bottom + 8)`). Do not use `SafeArea` widget — it adds padding to all sides, which conflicts with the full-bleed sheet background that sits flush to the screen edge. Apply only bottom padding manually.

**Confirm button placement:** The Confirm button and Cancel text link sit above this safe-area padding block, separated from the list/picker by a 1dp Divider. The footer zone (Divider + Confirm button + Cancel link + safe-area SizedBox) has a fixed visual height regardless of safe-area inset on devices without home indicators (iPhone SE, older Androids) — the safe-area `SizedBox` collapses to `0 + 8 = 8dp` on those devices, which is visually clean.

**The home indicator does NOT sit on top of the Confirm button** on any supported device when this pattern is followed. The `MediaQuery.paddingOf(context).bottom` on iPhone 14/15 Pro (with home indicator) is 34dp; the total bottom clearance becomes 42dp, which is above the indicator zone.

---

## Open questions PM asked, answered

### Category list: static or fetched

**Static. Confirmed.**

`EventCategory` is a Dart enum with 7 values (`drinks`, `food`, `hike`, `museum`, `sports`, `nightlife`, `other`). It is defined in `apps/mobile/lib/src/features/events/domain/entities/event_category.dart` and is the client-side SoT, kept in sync with the server enum. The comment in that file says "Wire values are snake_case strings matching the server enum exactly" — changes to the category list require coordinated deploy of both server and client.

Consequence for this spec: **the loading state, empty state, and error state for the category sheet are not applicable and must not be implemented.** The sheet renders `EventCategory.values` directly as a compile-time list. No async fetch, no skeleton, no retry. Spec the disabled/error states on the trigger row (for form-validation purposes) but not a data-loading state on the sheet content.

### Spec format: markdown vs. Figma

**Markdown, committed to the repo. This is the right call.**

The PM's reasoning is correct and matches how this codebase operates: `software-engineer` and `architecture-reviewer` agents work from the file tree, not from Figma. A spec that lives at `docs/design/tri-61-selector-spec.md` (suggested path) is searchable, diffable, lives next to the code it specifies, and survives Figma access rotation. It can be linked from Linear comments.

Figma would add value for pixel-perfect visual exploration or for a design system with many contributors. At Tribely's current team size and tooling (single Flutter codebase, agent-based workflow), the friction cost of a Figma source-of-truth outweighs the benefit. If a Figma component library is established in a future sprint, this spec can be backfilled as a component reference then.

**Suggested committed path:** `docs/design/tri-61-selector-spec.md`

The orchestrator should route a follow-up to an SWE to commit this spec at that path on branch `chore/TRI-61-modernize-selectors-spec`, then create implementation tickets per surface (Step 1 category, Step 3 date+time) as separate Linear issues.

---

## Out-of-scope (restated to prevent SWE drift)

The following are explicitly out of scope for TRI-61 and must not be implemented in the downstream implementation tickets that reference this spec:

1. **Custom wheel/drum-roller pickers** for time or date. EL-flagged as L cost. Post-launch consideration only.
2. **Custom date grid renderer** (bespoke month calendar). EL-flagged as L cost. `CupertinoDatePicker` in dateOnly mode is the specified solution.
3. **Bespoke sheet open/close animations.** Use stock `showModalBottomSheet` transitions (Flutter default). No custom `AnimationController` for sheet motion.
4. **Dark mode variants.** Out of scope for this design cycle. The spec uses light-mode tokens only. Dark mode will be a separate pass across all components.
5. **Multi-select.** No launch flow requires it. Pattern A is single-select only. Do not add a "select multiple" variant.
6. **Generalized design-system package abstraction.** These components live in `features/events/presentation/widgets/` (or `core/widgets/` if a third consumer emerges at implementation time — but that decision requires a new guideline ask per the two-consumer rule). Do not create a standalone `tribely_pickers` package in this ticket.
7. **TRI-59 venue picker implementation.** TRI-59 adopts Pattern A vocabulary (stated above) but is its own ticket. Do not implement the venue picker as part of TRI-61's implementation work.
8. **Timezone picker.** Times are displayed in Singapore Time (UTC+8); no timezone selection UI. The existing `_TimezoneLabel` widget in Step 3 remains unchanged.
9. **Time increments smaller than 15 minutes.** 15-minute increments are the specified granularity. 5-minute or 1-minute precision is not needed for event scheduling at launch.

---

## Handoff notes

These notes are for the implementing SWE. Read the full spec above before starting.

**New widgets to create (suggested file locations):**

- `apps/mobile/lib/src/features/events/presentation/widgets/category_selector_field.dart` — The trigger row + sheet-opening logic for Pattern A. Wraps in `FormField<EventCategory>`. Calls `FocusManager.instance.primaryFocus?.unfocus()` before opening sheet.
- `apps/mobile/lib/src/features/events/presentation/widgets/category_sheet.dart` — The bottom-sheet content widget for Pattern A. Stateless widget; takes the current `EventCategory?` and an `onSelected` callback.
- `apps/mobile/lib/src/features/events/presentation/widgets/date_time_picker_field.dart` — The replacement for `_DateTimePicker` in Step 3. Same trigger row layout as current; new sheet-opening behavior. Calls `FocusManager.instance.primaryFocus?.unfocus()` before opening sheets.
- `apps/mobile/lib/src/features/events/presentation/widgets/date_picker_sheet.dart` — Date sheet content widget. Contains `CupertinoDatePicker` in dateOnly mode.
- `apps/mobile/lib/src/features/events/presentation/widgets/time_picker_sheet.dart` — Time sheet content widget. Contains the scrollable 96-row time list.

**What stays unchanged:**

- `CreateEventController` — no changes. `updateField` signature and behavior are identical. Cross-field validators are unchanged.
- `EventCategory` enum — no changes.
- `event_validators.dart` — no changes.
- Step 3 trigger row layout — the `_DateTimePicker` trigger row (border, icon, label/value stacked layout, error text) is preserved exactly. Only the `_pick()` async method changes (replaces `showDatePicker` + `showTimePicker` with the new sheets).

**Key icon dependency:** The icons listed in the category icon map (`Icons.local_bar_outlined`, `Icons.restaurant_outlined`, `Icons.terrain`, `Icons.account_balance_outlined`, `Icons.sports_outlined`, `Icons.nightlife`) must be verified to exist in the version of `material_icons` included by the Flutter SDK in this project. `Icons.nightlife` may require SDK 2.10+. Use `Icons.nightlight_round` as a verified fallback if `Icons.nightlife` is not resolved by the analyzer.

**`showModalBottomSheet` call parameters (both patterns):**

```
isScrollControlled: true
backgroundColor: Colors.transparent
isDismissible: true
enableDrag: true
useRootNavigator: false  (let the in-page navigator handle it, not the root app navigator)
```

**Copy assets (no Figma needed — all text is in this spec):**

- Sheet header, Pattern A: "Choose a category"
- Sheet header, Pattern B date: "Pick a date"
- Sheet header, Pattern B time: "Pick a time" (sub-label: formatted date string from the date just confirmed)
- Confirm button, date sheet: "Confirm date"
- Confirm button, time sheet: "Confirm time"
- Cancel link (both sheets): "Cancel"

**Controller wiring — category:**

The new `CategorySelectorField` must wrap in `FormField<EventCategory>` with:
- `initialValue: draft.category`
- `onSaved: (v) => controller.updateField(field: 'category', value: v)`
- `validator: (v) => validateCategory(v)`
- `autovalidateMode: AutovalidateMode.onUserInteraction`

The sheet's `onSelected` callback calls `controller.updateField(field: 'category', value: category)` directly and then `Navigator.pop(context)`. The `FormField` wrapper ensures validation + draft-persistence hooks remain intact.

**Controller wiring — date+time:**

The new `DateTimePickerField` takes `onPicked: ValueChanged<DateTime>` — same signature as the existing `_DateTimePicker`. Wiring in Step 3 is unchanged: `onPicked: (dt) => controller.updateField(field: 'startsAt', value: dt)`.

---

*Spec version 1.0 — 2026-05-14 — TRI-61 design spike deliverable.*
*Author: ui-ux-designer agent.*
*Implementation tickets to be filed by PM following orchestrator Step 10.*
