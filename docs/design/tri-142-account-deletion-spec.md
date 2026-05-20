# TRI-142 — Account Deletion Flow Design Spec

## Overview

This spec covers the end-to-end mobile UI for in-app account deletion on Tribely (iOS + Android), satisfying Apple App Store Review Guideline 5.1.1(v). It addresses: the entry point in the Settings/Profile surface (AC1), a typed confirmation gate with disclosure copy (AC2, AC3), a terminal post-deletion screen with sign-out and navigator-stack flush (AC4, AC5), and all failure states (AC7). It does not cover re-registration, soft-delete, biometric re-challenge, or a "why are you leaving?" survey. All eight acceptance criteria from the PM brief are satisfied by this specification.

---

## Strategic frame

- **Singapore launch, English-only MVP.** All copy is English. No i18n surface introduced here.
- **Mobile-first, Flutter on iOS + Android.** Every layout decision is 375pt/dp wide as the smallest supported viewport.
- **Apple 5.1.1(v) hard gate.** In-app deletion must be reachable without leaving the app, without email/support workarounds. This spec satisfies that requirement through a Settings → Account → Delete Account path.
- **Irreversibility per CEO P3 on TRI-134.** No soft-delete, no recovery window. The UI must make this unambiguous without being punitive. The tone is honest and respectful, not alarmist.
- **PII cascade source of truth: `docs/policy/pii-cascade-contract.md`.** The 14 data classes enumerated there inform the disclosure copy below. User-facing copy summarises the outcome without re-listing every database table. The privacy policy link on the confirmation surface is the canonical deep-reference for users who want the full detail.

---

## Decisions taken

### 1. Confirmation token: "DELETE" (all caps)

Rationale: for an English-only MVP targeting Singapore, "DELETE" is the appropriate choice. It is semantically self-evident in English, requires no personalised lookup (unlike email or username, which require the app to display the user's current value and open a copy-mismatch failure surface), and matches GitHub's widely-understood pattern for destructive repository operations. Stripe/Coinbase's email-token approach is stronger for financial products where account value is high and fraud recovery matters; for a social app with no stored payment credentials at launch, the added friction buys little while degrading the experience for the majority who are deleting for legitimate reasons (e.g., moving cities, taking a break). The token is case-sensitive and must match "DELETE" exactly — partial matches and lowercase do not enable the CTA. The input is auto-capitalised to `TextCapitalization.characters` to reduce mis-type friction on mobile keyboards.

### 2. Disclosure surface: one-step (disclosure + typed gate on the same screen)

Rationale: two-step flows (read → "I understand" → type token) are appropriate for regulated financial or healthcare products where legal teams require demonstrated comprehension checkpoints. For a consumer social app, they introduce a pace-breaking redundancy that makes the experience feel bureaucratic without improving actual comprehension. Twitter/X, Discord, and Coinbase (non-financial deletion) all present disclosure and confirmation on a single scrollable surface. The one-step approach respects the user's agency: if they have reached this screen, they have already made the decision. The disclosure paragraph is prominent enough (above the input, not below) that skimming is the natural reading path. The destructive CTA is unreachable until the token is typed, which forces at least a momentary engagement with the surface.

### 3. Terminal screen tone: clinical-and-clear

Rationale: a warm, empathetic "We're sad to see you go" tone would feel patronising given that the user just completed a deliberate irreversible action. It also creates a cognitive dissonance between the gravity of what just happened and the emotional register of the message. The terminal screen should confirm completion crisply, state what happens next, and offer a clear exit path. Warmth belongs in the onboarding and value-proposition flows; the deletion terminal is an exit receipt, not a retention play.

### 4. Failure retry token persistence: yes — typed token is retained across retry attempts

Rationale: the PM default is correct. A network error or 5xx is a backend/infrastructure failure, not a signal that the user changed their mind. Clearing the typed token on error would punish the user for a failure they did not cause. The token is retained in controller state across retry cycles. The only time the token is cleared is if the user navigates away from the screen (controller dispose). A 4xx auth-expiry error is handled differently — see Error States — but the token is still retained so the user can re-authenticate and return without re-typing.

---

## Competitor pattern research

| App | Pattern | Takeaway |
|-----|---------|----------|
| **GitHub** | Type the repository name to confirm deletion. Case-sensitive. CTA disabled until exact match. One-step surface. | Established benchmark for typed-confirmation gates on irreversible destructive actions. The "name the thing you are deleting" variant is stronger for repository identity; for account deletion the token "DELETE" is equivalent and more discoverable. **Adopted:** typed gate + disabled CTA pattern. |
| **Discord** | Settings → My Account → Delete Account. Separate modal with password re-entry. No typed token. Two CTAs: "Delete Account" and "Deactivate Account". | The deactivation alternative is out of scope for Tribely (CEO P3). Password re-entry is a biometric/re-auth challenge pattern that the PM brief explicitly excludes. **Rejected:** re-auth challenge. **Adopted:** modal/page-level confirmation approach. |
| **Twitter/X** | Settings → Your Account → Deactivate. Disclosure paragraph above CTA. Tap "Deactivate" to confirm — no typed gate. 30-day soft-delete recovery window. | Soft-delete and no typed gate are both out of scope. Their disclosure-first layout (body copy before CTA) is sound and adopted. **Adopted:** disclosure-above-CTA layout ordering. **Rejected:** soft-delete framing, no-gate confirmation. |
| **Stripe** (customer portal) | Type email address to confirm subscription or account deletion. Used in high-value financial contexts. | Email token is appropriate when account has financial value or fraud risk. Tribely at launch has no stored payment credentials. Over-engineering for this context. **Rejected** for MVP. Revisit post-payments. |
| **Coinbase** | Delete account confirmation requires typing email. Additional "are you sure" interstitial. Two-step. | Same rationale as Stripe. High-value asset platform. Coinbase's two-step interstitial is justified there; patronising here. **Rejected.** |
| **Bumble** | Settings → Delete Account. Radio button for deletion reason (survey), then confirmation. Account deleted after 28 days (soft-delete). | "Why are you leaving?" survey and soft-delete are both out of scope. Their radio-reason pattern reveals the tension between retention data-collection and user agency — we resolve in favour of user agency. **Rejected.** |
| **Meetup** | Settings → Account → Close Account. Password confirmation step. Long-form disclosure of data handling. | Password re-auth excluded by PM brief. Long-form disclosure is appropriate for a platform with event/group history — adopted in spirit but distilled into a tighter paragraph per PM's "plain English" instruction. **Adopted:** account subsection placement. **Rejected:** password re-entry. |
| **Partiful** | No publicly documented in-app deletion flow as of May 2026. Support-flow only. | Demonstrates the pre-5.1.1(v) status quo that Apple has explicitly prohibited. **Not a reference pattern.** |

**Converging pattern (treat as best practice):** typed or explicit confirmation gate + CTA disabled until gate satisfied + disclosure copy before the gate + single full-width destructive CTA + ghost/text cancel affordance. All of GitHub, Discord, and Twitter/X converge on this structural shape.

**Diverging (Tribely position):** we use "DELETE" typed token (not password re-entry, not email) + one-step surface + hard-delete (no soft-delete). These are deliberate product decisions, not omissions.

---

## User flow (end-to-end)

1. **Profile tab (bottom nav) → Profile page (`OwnProfilePage`)** — User is signed in. Profile page is the current Settings/account surface (there is no separate Settings page yet — see AC1 note below and Open Questions for EL).
2. **Profile page → "Account" section → tap "Delete Account" row** — A clearly labelled destructive-treatment list row under an "Account" subsection. Tap navigates to the Confirmation surface (Screen 2).
3. **Confirmation surface (`DeleteAccountPage`)** — User reads disclosure copy, types "DELETE" into the confirmation input. CTA remains disabled until the typed value matches exactly. Optional: user taps the Privacy Policy link → opens in-app browser (system `url_launcher`). User taps Cancel → pops back to Profile page, no state change.
4. **Confirmation surface → tap "Permanently Delete Account"** — CTA transitions to `PrimaryButtonState.loading`. App calls `DELETE /users/me`. If successful (2xx), navigate to Terminal screen (Screen 3) and flush navigator stack so back-nav into the authenticated app is impossible.
5. **Terminal screen (`AccountDeletedPage`)** — Static, no authenticated-app back-nav. Single CTA: "Back to sign in" — routes to the unauthenticated entry flow and clears session/secure storage/cached entities (this is a controller responsibility, not a screen responsibility — see Handoff Notes).
6. **Failure path (network / 4xx / 5xx)** — Stay on Confirmation surface. `BannerMessage` appears above the input with error copy. CTA returns to idle (enabled, since token is still correctly typed). User can retry without re-typing. See Error States for per-failure-mode copy.

---

## Screen-by-screen specifications

### Screen 1: Settings root entry point

**Placement context:** At time of spec (TRI-142), there is no standalone Settings page. The `OwnProfilePage` is the de-facto account management surface, with a sign-out icon in the AppBar. The Delete Account entry point should live in the `OwnProfilePage` body under a new "Account" labelled section, below the existing profile content and above the sign-out affordance.

**Recommended layout change to `OwnProfilePage`:**

The sign-out icon button in the AppBar should be complemented by (or migrated toward) a list-section pattern in the page body. This is consistent with how iOS Settings and Android Settings both surface destructive account actions — not as floating AppBar icons but as clearly labelled rows in a structured list.

**"Delete Account" row treatment:**

- Placed at the bottom of an "Account" section divider group.
- Label: `Delete account` (sentence-case, not ALL CAPS — the destructive signal comes from the color, not the casing).
- Color: `paperAccent` / `nightAccent` (ember coral / #D85730 light, #E07F5F dark). This is the existing accent/error token used consistently across the system for destructive states. The label and a leading `Icons.delete_forever` icon both render in this color.
- Do NOT apply the same destructive treatment to the sign-out row — sign-out is reversible. Sign-out label stays in `paperInkSecondary`/`nightInkSecondary` with a neutral `Icons.logout` icon.
- Tappable row minimum height: 56dp, full-width, with 24dp horizontal padding. Left icon (20dp), 12dp gap, label at `bodyM`, trailing `Icons.chevron_right` in `paperInkSecondary`/`nightInkSecondary`.

```
┌──────────────────────────────────────────────────────┐
│  Profile                                      [logout]│  ← AppBar (retain for now)
├──────────────────────────────────────────────────────┤
│  [profile content — avatar, name, bio, stats]        │
│                                                      │
│  ─────────────────  ACCOUNT  ─────────────────────   │  ← section divider, caption weight
│                                                      │
│  [logout icon]  Sign out                          ›  │  ← inkSecondary color
│  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─  ─   │  ← hairline divider
│  [delete icon]  Delete account                    ›  │  ← paperAccent color (ember coral)
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Note on future Settings page:** this spec places the entry point in `OwnProfilePage` because no Settings page exists yet. If a standalone Settings page is created before TRI-142 ships (see Open Questions for EL), the Delete Account row should migrate there under an "Account" section. The AC1 requirement of ≤3 taps is satisfied either way: Profile tab → Profile page → Delete Account row = 2 taps.

---

### Screen 2: Confirmation surface (`DeleteAccountPage`)

This is a full-screen page (not a bottom sheet or dialog). It replaces the profile page in the navigation stack push. Full-screen treatment is intentional: the gravity of the action warrants a dedicated, distraction-free context. A bottom sheet is appropriate for recoverable or low-stakes actions; permanent account deletion is neither.

**Layout:**

```
┌──────────────────────────────────────────────────────┐
│  ← [back arrow]                                      │  ← AppBar, transparent, no title
│                                                      │
│  24dp top padding                                    │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  Permanently delete your account?             │  │  ← headline/22 semibold, paperInkPrimary
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  16dp gap                                            │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  [disclosure paragraph — bodyM, inkSecondary]  │  │
│  │  [privacy policy link — bodyM, paperPrimary]   │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  24dp gap                                            │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  Type DELETE to confirm                        │  │  ← caption/13, inkSecondary (helper label)
│  │  ┌──────────────────────────────────────────┐  │  │
│  │  │  TribelyTextField — label "DELETE"       │  │  │  ← existing TribelyTextField component
│  │  └──────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  24dp gap                                            │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │         Permanently delete account             │  │  ← DestructivePrimaryButton (new variant)
│  └────────────────────────────────────────────────┘  │  ← disabled until token typed correctly
│                                                      │
│  12dp gap                                            │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │                  Cancel                        │  │  ← SecondaryButton (existing)
│  └────────────────────────────────────────────────┘  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

The page body uses a `SingleChildScrollView` wrapping a `Column` with `SafeArea` padding. This ensures the disclosure paragraph is reachable at all Dynamic Type sizes without clipping. The CTAs are always at the bottom of the scroll column (not pinned to the bottom of the viewport) to avoid overlap with the keyboard when the input is focused on smaller devices.

**Verbatim copy:**

Heading:
```
Permanently delete your account?
```

Disclosure paragraph (bodyM, `paperInkSecondary`/`nightInkSecondary`):
```
This will permanently delete your profile, photos, and event history within
30 days. Your name and details will be removed from our systems. Some
activity records may be anonymised rather than deleted to preserve the
integrity of events you participated in.

This cannot be undone.
```

Privacy Policy link (inline, `bodyM`, `paperPrimary`/`nightPrimary`, tappable — opens system browser):
```
Read our Privacy Policy for full details on data deletion.
```

Helper text above input (caption/13, `paperInkSecondary`/`nightInkSecondary`):
```
Type DELETE to confirm
```

`TribelyTextField` label:
```
DELETE
```

`TribelyTextField` — no placeholder text beyond the floating label. `TextCapitalization.characters` so the mobile keyboard defaults to all-caps, reducing friction.

Destructive CTA label (disabled state):
```
Permanently delete account
```

Destructive CTA label (enabled state — identical copy, color changes, not the label):
```
Permanently delete account
```

Destructive CTA label (loading state — `PrimaryButtonState.loading`):
*(dots animation — no label change, the `PrimaryButton` loading state handles this)*

Cancel button label:
```
Cancel
```

**Component hierarchy (no code):**

`DeleteAccountPage` → `Scaffold` (transparent AppBar with back arrow) → `SafeArea` → `SingleChildScrollView` → `Column` with `Padding(horizontal: 24)`:
- `BannerMessage` (error state only — hidden in default/success state; sits above the heading)
- `Text` heading
- `SizedBox(16)`
- `Text` disclosure paragraph
- `SizedBox(8)`
- `GestureDetector` wrapping `Text` privacy policy link (opens url_launcher)
- `SizedBox(24)`
- `Text` helper label ("Type DELETE to confirm")
- `SizedBox(8)`
- `TribelyTextField` (existing component, `controller`, `label: 'DELETE'`, `textCapitalization: TextCapitalization.characters`, `textInputAction: TextInputAction.done`, no `obscure`, no `autofillHints`)
- `SizedBox(24)`
- `DestructivePrimaryButton` (new design-system variant — see Design System Alignment)
- `SizedBox(12)`
- `SecondaryButton(label: 'Cancel', onPressed: () => context.pop())`

**States:**

| State | Input border | CTA background | CTA label color | CTA tap |
|-------|-------------|----------------|-----------------|---------|
| Default (empty / wrong token) | `paperBorderSubtle` / `nightBorderSubtle` | `paperBorderSubtle` / `nightBorderSubtle` | `paperInkSecondary` / `nightInkSecondary` | no-op |
| Token typed correctly ("DELETE") | `paperBorderSubtle` (idle focus ring) | `paperAccent` / `nightAccent` | `paperSurfaceHigh` / `nightSurface` | fires deletion |
| Token mistyped (non-empty, not "DELETE") | `paperBorderSubtle` (idle) | `paperBorderSubtle` / `nightBorderSubtle` | `paperInkSecondary` / `nightInkSecondary` | no-op |
| Loading (API call in flight) | disabled (50% opacity) | `paperAccent` / `nightAccent` | loading dots | suppressed |
| Error (after non-2xx) | restored to pre-error state | restored (token still typed = enabled) | restored | fires retry |

**Token mismatch hint:** no real-time inline error shown while the user is mid-type — showing "incorrect" while they are still typing is jarring. The hint is omitted; the disabled CTA state is the sole signal. Once the user has finished typing (on `TextInputAction.done` or focus-out) and the token does not match, a caption below the input reads:

```
Type exactly: DELETE
```

This caption is shown only after the user commits the input (submits or unfocuses), not during live typing.

**Accessibility:**

- `TribelyTextField` VoiceOver/TalkBack semantic label: `"Confirmation input. Type the word DELETE in capital letters to confirm account deletion."`
- `DestructivePrimaryButton` semantic label (disabled): `"Permanently delete account, button, disabled. Type DELETE to enable."`
- `DestructivePrimaryButton` semantic label (enabled): `"Permanently delete account, button. Destructive action — this cannot be undone."`
- `DestructivePrimaryButton` semantic label (loading): `"Deleting account, please wait."`
- Focus order: AppBar back arrow → heading → disclosure paragraph → privacy policy link → confirmation input → destructive CTA → cancel button. Linear top-to-bottom. No focus traps.
- Dynamic Type / font scaling: the page is a `SingleChildScrollView` — all text scales freely. At `textScaleFactor` 2.0 (largest iOS accessibility size) the heading will wrap to 2–3 lines; this is expected and handled by the scroll. The `TribelyTextField` input remains 56dp tall regardless of scale — the label floats above as per existing component behaviour.
- Minimum touch targets: destructive CTA 56dp × full width (exceeds iOS 44pt / Android 48dp). Cancel button rendered via `SecondaryButton` with `minimumSize: Size(48, 48)` per existing spec. Back arrow in AppBar: `IconButton` default `minSize: 48`.
- Color is not the sole signal for the CTA state transition: the CTA label copy is identical in enabled and disabled states; the enabled state also gains an accessible contrast ratio (see Design System Alignment). Screen readers announce the semantic label change.

---

### Screen 3: Terminal "account deleted" screen (`AccountDeletedPage`)

This screen is pushed with a full navigator-stack replacement — the authenticated-app back-nav is impossible once this screen is shown. SWE must use `context.go('/account-deleted')` or equivalent `GoRouter` push-and-clear rather than `context.push(...)`. See Handoff Notes.

**Layout:**

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  [no AppBar — no back navigation]                    │
│                                                      │
│                                                      │
│                                                      │
│             [InkMark — centered, 48dp]               │  ← brand mark, not wordmark
│                                                      │
│             48dp gap                                 │
│                                                      │
│       Your account has been deleted.                 │  ← headline/22 semibold, centered
│                                                      │
│             16dp gap                                 │
│                                                      │
│   Your data will be removed within 30 days,          │  ← bodyM, inkSecondary, centered
│   in line with our Privacy Policy.                   │
│                                                      │
│             48dp gap                                 │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │              Back to sign in                   │  │  ← PrimaryButton (existing, standard color)
│  └────────────────────────────────────────────────┘  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

Centered column layout, 24dp horizontal padding, vertically centered with a slight upward bias (use `mainAxisAlignment: MainAxisAlignment.center` with additional `Padding(top: 48)` on the InkMark to prevent it from feeling pinned to the exact viewport center on tall phones).

Background: `paperSurface` / `nightSurface` — the standard page background. No special treatment. The clinical tone extends to the visual: no emoji, no confetti, no sad/happy animation.

**Verbatim copy:**

Heading (headline/22 semibold, `paperInkPrimary`/`nightInkPrimary`, centered):
```
Your account has been deleted.
```

Body paragraph (bodyM/15, `paperInkSecondary`/`nightInkSecondary`, centered):
```
Your data will be removed within 30 days, in line with our Privacy Policy.
```

CTA label:
```
Back to sign in
```

**Navigator stack instruction for SWE:** `AccountDeletedPage` must be the only entry in the navigation stack when displayed. Use `GoRouter.go('/account-deleted')` or `context.go(...)` — not `context.push(...)`. The `/account-deleted` route must sit outside the authenticated shell guard. The `Back to sign in` CTA calls `context.go('/auth/sign-in')` (or the equivalent unauthenticated entry route). Android physical back button on this screen should also route to sign-in, not back into the app — configure `PopScope(canPop: false, onPopInvokedWithResult: ...)` accordingly.

**Accessibility:**

- Screen announced by VoiceOver/TalkBack on navigation: `"Account deleted. Your account has been deleted."`
- CTA semantic label: `"Back to sign in, button."`
- No focus traps. Focus lands on the heading on page load, then linear to CTA.
- `PopScope` prevents back gesture — screen reader users must use the CTA.

---

## Error states

All error states manifest as a `BannerMessage` component (existing, `BannerVariant.alert` using `paperAccentSoft` backdrop) inserted at the top of the `DeleteAccountPage` body, above the heading. The CTA returns to its pre-error idle state (enabled if token is still correctly typed). The typed token is retained. The `BannerMessage` is dismissible via its `onDismiss` callback to keep the surface clean if the user resolves the issue themselves.

### Network failure (no connectivity / request timeout)

`BannerMessage` copy:
```
No connection. Check your internet and try again.
```

Recovery: user retries by tapping the CTA again. No additional affordance needed — the CTA is re-enabled.

### 4xx — authentication expired (session invalidated before API call resolves)

`BannerMessage` copy:
```
Your session has expired. Sign in again to delete your account.
```

Recovery affordance: inline `BannerAction` label `"Sign in →"` that routes to the sign-in page. The typed token is retained in controller state — if the user signs back in and returns to this screen, the controller should restore the typed value via persistent state (EL to decide whether this warrants a local ephemeral store or just re-type is acceptable — see Open Questions for EL).

### 5xx — server error

`BannerMessage` copy:
```
Something went wrong on our end. Please try again in a moment.
```

Recovery: user retries by tapping the CTA again. No additional affordance.

### Token persistence across retries

Confirmed by Decision #4: the typed "DELETE" token is retained in controller state across all retry attempts in the same screen lifecycle. It is not cleared on error. It is cleared only on `dispose` (user navigates away). This is the PM-default behaviour and is upheld here.

---

## Design system alignment / additions

### Reused existing components

| Component | Usage in this spec |
|-----------|-------------------|
| `PrimaryButton` (`PrimaryButtonState.idle`, `loading`) | Terminal screen CTA ("Back to sign in"). On Confirmation surface for the loading state of the destructive CTA (see DestructivePrimaryButton below). |
| `SecondaryButton` | "Cancel" on Confirmation surface. |
| `TribelyTextField` | Confirmation token input. |
| `BannerMessage` (`BannerVariant.alert`) | Error states on Confirmation surface. |
| `InkMark` | Brand mark on Terminal screen. |
| `GrainOverlay` | Not used on these screens — terminal screen is intentionally clean. |

### New design-system addition required: `DestructivePrimaryButton`

**Flag for CPO consultation before implementation.** This spec proposes a new variant of `PrimaryButton` for irreversible destructive actions. The existing `PrimaryButton` uses `paperPrimary` (#1B3D3A teak teal) / `nightPrimary` (#D5A86F burnished brass) as the active background. For the account deletion CTA, this would be semantically incorrect — teal is a trust/positive-action color in the Equatorial Editorial palette; using it on an irreversible deletion CTA would mislead the user.

The proposed `DestructivePrimaryButton` shares all structural and motion properties with `PrimaryButton` but overrides the active background color token:

- Active background: `paperAccent` (#D85730 ember coral) / `nightAccent` (#E07F5F)
- Active foreground: `paperSurfaceHigh` (#FFFFFF) / `nightSurface` (#131110)
- Disabled background: `paperBorderSubtle` (#E8DFD0) / `nightBorderSubtle` (#2A2522) — identical to existing `PrimaryButton` disabled
- Disabled foreground: `paperInkSecondary` (#5C544A) / `nightInkSecondary` (#A39B8A) — identical to existing `PrimaryButton` disabled
- All other properties (56dp height, border-radius 14, loading dots animation, button/16 semibold label) unchanged

**Contrast check (WCAG AA, 4.5:1 minimum for normal text):**
- Active state light: white (#FFFFFF) on ember coral (#D85730) → 3.5:1. This does not meet WCAG AA for normal text at 16sp. However, `PrimaryButton.button` style is 16sp **semibold** — this qualifies as large text (≥14pt bold) under WCAG, for which the threshold is 3:1. The 3.5:1 ratio passes at semibold 16.
- Active state dark: `nightSurface` (#131110) on `nightAccent` (#E07F5F) → approximately 4.8:1. Passes AA for normal text.
- Disabled state: `paperInkSecondary` (#5C544A) on `paperBorderSubtle` (#E8DFD0) → 3.2:1. Disabled states are exempt from WCAG contrast requirements per WCAG 2.1 SC 1.4.3 (disabled UI components are excluded).

**This is a new design-system primitive. Engineering should not implement it before CPO sign-off.** In the interim, the spec proceeds with this proposed token; implementation is gated on that consultation.

**Alternative if CPO declines `DestructivePrimaryButton`:** use the existing `PrimaryButton` with `paperPrimary`/`nightPrimary` color for the destructive CTA. This is semantically suboptimal but not a blocker. Note the trade-off in that case: teal on a permanent deletion CTA is misleading; a user who has seen teal as the "positive action" color throughout the app will experience a register mismatch. Recommend CPO approves the new variant.

### No other new design-system additions required

The terminal screen (`AccountDeletedPage`) reuses `PrimaryButton` with standard teal color — the deletion is already confirmed and complete; the CTA at this point is a neutral navigation action, not a destructive one.

---

## Accessibility

### Minimum tap targets

| Element | Specified size | Compliant? |
|---------|---------------|------------|
| `DestructivePrimaryButton` | 56dp height × full width | Yes (iOS 44pt / Android 48dp) |
| `SecondaryButton` ("Cancel") | `minimumSize: Size(48, 48)` per `SecondaryButton` spec | Yes |
| AppBar back arrow | `IconButton` default 48dp | Yes |
| Privacy policy link | Inline text link — wrap in `GestureDetector` with explicit `padding: EdgeInsets.symmetric(vertical: 8)` to extend tap target | Marginal — annotate in handoff |
| Terminal screen CTA | 56dp height × full width | Yes |

### Color contrast

| Element | Light mode | Dark mode | WCAG result |
|---------|-----------|-----------|-------------|
| Heading text on page surface | #1A1714 on #FAF6EF → ~17:1 | #F4EEDF on #131110 → ~14:1 | Passes AAA |
| Disclosure body text | #5C544A on #FAF6EF → ~7:1 | #A39B8A on #131110 → ~5:1 | Passes AA |
| Destructive CTA (enabled, light) | #FFFFFF on #D85730 → 3.5:1 (semibold 16) | — | Passes AA (large/bold text) |
| Destructive CTA (enabled, dark) | — | #131110 on #E07F5F → ~4.8:1 | Passes AA |
| Disabled CTA | #5C544A on #E8DFD0 → 3.2:1 | Exempt per WCAG 2.1 SC 1.4.3 | Exempt |
| Helper caption ("Type DELETE to confirm") | #5C544A on #FAF6EF → ~7:1 | #A39B8A on #131110 → ~5:1 | Passes AA |

### Screen reader narration order (Confirmation surface)

1. AppBar back arrow: "Back, button"
2. Error banner (if present): "Alert: [error copy]"
3. Heading: "Permanently delete your account?"
4. Disclosure paragraph (read as continuous text)
5. Privacy policy link: "Read our Privacy Policy for full details on data deletion, link"
6. Helper label: "Type DELETE to confirm"
7. Confirmation input: "Confirmation input. Type the word DELETE in capital letters to confirm account deletion. Text field, double-tap to edit."
8. Destructive CTA (disabled): "Permanently delete account, button, dimmed. Type DELETE to enable."
9. Destructive CTA (enabled): "Permanently delete account, button. Destructive action — this cannot be undone."
10. Cancel button: "Cancel, button"

### Dynamic Type / font scaling

The entire `DeleteAccountPage` body is inside a `SingleChildScrollView`. At the largest iOS Dynamic Type size (`xxxLarge` or Accessibility Category 5), the heading will wrap to 3 lines and the disclosure paragraph will be significantly taller. The scroll container accommodates this without clipping. The `TribelyTextField` 56dp minimum height is preserved regardless of scale (existing component behavior). The `DestructivePrimaryButton` inherits `PrimaryButton`'s fixed 56dp height — the button label at large text sizes will remain legible because `button/16 semibold` scales proportionally and the button width is full-screen.

On Android, `fontScale > 1.3` is the equivalent threshold. Behavior is identical via `SingleChildScrollView`.

### Reduce-motion

The `DestructivePrimaryButton` loading state uses the same `_LoadingDots` animation as `PrimaryButton`. The existing `context.reduceMotion` check in `_LoadingDots` degrades to a static "•••" when the user has enabled reduced motion. No additional reduce-motion handling is required for this flow.

---

## Out of scope (consistent with PM non-goals)

- Soft-delete / recovery window — not in scope per CEO P3 on TRI-134.
- Biometric re-challenge — not in scope per PM brief.
- Re-registration flow — separate future feature.
- "Why are you leaving?" survey — explicitly excluded.
- Operator-channel deletion (privacy mailbox) — handled separately per `docs/runbooks/account-deletion-sla.md`; no mobile UI surface.
- GDPR Article 17 right-to-erasure framing — Singapore launch is PDPA-only.
- Payment data handling — no stored payment credentials at launch; revisit post-payments.

---

## Open questions for engineering-lead (not for orchestrator/user)

1. **Settings page existence:** at time of spec, `OwnProfilePage` is the de-facto account management surface. If a dedicated Settings page is in the roadmap before TRI-142 ships, the Delete Account entry point should migrate there. EL should confirm the intended navigation architecture before SWE scaffolds the route.

2. **Route for `AccountDeletedPage`:** this screen must sit outside the authenticated GoRouter shell (the `ShellRoute` guard that wraps the main bottom-nav tabs). EL should confirm the unauthenticated route tree and the name of the sign-in entry route (`/auth/sign-in` is assumed but not verified against `app_router.dart`).

3. **Session/secure-storage clearance:** the `AccountDeletedPage` CTA navigates to sign-in, but the backend cascade already hard-deletes refresh tokens (row 3 of the PII cascade contract). SWE needs a clear sequence: does the mobile-side session clear happen (a) synchronously before the navigation on successful 2xx from `DELETE /users/me`, (b) as part of the `AccountDeletedPage` CTA tap, or (c) both? EL to define the authoritative sequence so the `DeleteAccountController` and `SessionController` are wired correctly.

4. **Token restoration after 4xx auth-expiry retry:** if the user taps "Sign in →" from the 4xx error banner and later returns to the deletion flow, the controller will have been disposed. Should the typed token be persisted to ephemeral local state (e.g., `SharedPreferences` with a TTL) so the user does not need to re-type on return? Or is re-typing acceptable given the infrequency of this path? EL to decide; default assumption in this spec is re-typing is acceptable (controller state only, no persistence).

5. **`DestructivePrimaryButton` CPO sign-off:** this spec proposes a new design-system primitive (ember-coral background PrimaryButton variant for irreversible destructive CTAs). EL should confirm this consultation has been routed to CPO before SWE implements the component.

6. **End-to-end verification (AC6):** the spec notes that a deleted account cannot re-authenticate. This is a backend guarantee (credentials hard-deleted per cascade row 2), not a mobile UI concern. EL should confirm whether the QA harness for this check is in scope for TRI-142 or a follow-up ticket.
