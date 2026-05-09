# Tribely — Login experience design spec

Scope: splash, welcome, sign-in, sign-up, forgot-password entry, hand-off to home. Everything else is out of scope.

## Aesthetic direction: "Equatorial Editorial"

Imagine the cover of a thoughtful travel quarterly published in Singapore — confident editorial serif, restrained humanist body, warm paper surfaces in light mode and deep peat in dark mode. Tropical-dusk teal as the primary action, ember coral as the human accent. Subtle paper grain across all surfaces. One signature ink-brush mark. Microcopy that sounds like a friend, not a brand.

### Why this direction (not the obvious ones)

- Tribely is about _real places and real people meeting in person_. A globe icon, a stock Bali sunset, or a Material You blue tells the wrong story. Singapore at 7pm — when offices empty and people stream toward dinner with strangers — is the actual product moment. Design captures that, not "travel" in the abstract.
- Trust + safety must read in the first second. Restrained typography + generous spacing + an editorial tone telegraphs "considered" and "premium." Loud animations and gradient buttons would suggest dating-app or airdrop-startup, both wrong category.
- "Premium but human" is delivered through warmth — paper-cream not pure white, ember not red, deep teak teal not corporate blue. No purple gradient. No glassmorphism. No Material You.

## Type system

| Role    | Family                                       | Source       | Default           | Why                                                                 |
| ------- | -------------------------------------------- | ------------ | ----------------- | ------------------------------------------------------------------- |
| Display | **Fraunces** (variable serif, SOFT axis)     | Google Fonts | 36/42, italic 400 | Editorial weight, warm soul, soft axis adds friendly hand-cut feel  |
| Body    | **General Sans** (variable, weights 400–700) | Fontshare    | 15/22, 400        | Humanist sans with character — _not_ Inter, Geist, or Space Grotesk |

The signature is **italic-display headlines** — gives Tribely a confident-but-warm voice no travel app has.

Type scale (mobile):

```
Display L   36 / 42   Fraunces Italic 400
Display M   28 / 34   Fraunces Italic 400
Headline    22 / 28   General Sans 600
Body L      17 / 24   General Sans 400
Body M      15 / 22   General Sans 400
Caption     13 / 18   General Sans 500
Button      16 / 16   General Sans 600
```

## Color system

**Light — Equatorial Paper:**

```
Surface         #FAF6EF    warm cream (NOT pure white — sterile on cream feels lazy)
Surface high    #FFFFFF    pure for cards on cream
Ink primary     #1A1714    deep ink (NOT pure black — too clinical on cream)
Ink secondary   #5C544A
Border subtle   #E8DFD0
Primary         #1B3D3A    deep teak teal — calm, premium
Accent          #D85730    ember coral — warm, firm-not-alarming
Success         #4A7C59    sage, restrained
Grain           3% noise overlay across surfaces
```

**Dark — Equatorial Night:**

```
Surface         #131110    deep peat (warm undertone, NOT pure black)
Surface high    #1B1816
Ink primary     #F4EEDF    warm cream (NOT pure white)
Ink secondary   #A39B8A
Border subtle   #2A2522
Primary         #D5A86F    burnished brass (teak teal too dark on dark)
Accent          #E07F5F    warmer coral, slightly lifted
Success         #82B091
Grain           4% noise overlay
```

Why teak + coral over the obvious blue + orange (Stripe-clone) or purple + green (AI-startup-clone): complementary-adjacent, photographic, warm, _unique_. Errors in coral feel firm but not alarming — an auth app shouldn't blare red.

## Motion principles

- Default duration: **200–300ms**. Slower = broken; faster = jittery.
- Splash ink mark is the one place we let animation run long (~800ms) — the brand signature.
- Form focus: 200ms soft glow (4dp blur, ember accent), not a sharp 2dp outline ring.
- `prefers-reduced-motion`: animations >200ms drop to 0ms; ink mark renders static.

---

## Screen 1 — Splash / Cold start

The first 1.5–2s of the app. Two paths after this screen:

- Stored refresh token → silently call `POST /auth/refresh` → `/home`
- No token / refresh failed → `/welcome`

Layout: ink-brush stroke draws itself centered (800ms), wordmark "TRIBELY" in Fraunces Italic 28pt fades up 200ms after, "Restoring your session…" caption fades in only if the boot exceeds 1.5s.

States:

- Default (≤1.5s): ink + wordmark, no copy. Minimum hold establishes brand presence.
- Slow (>1.5s, <5s): "Restoring your session…" caption.
- Refresh failed: navigate to `/welcome` with a one-line top banner: "Please sign in again." Auto-dismisses after 4s.
- Network down: `/welcome` with banner: "We couldn't check your session. You can sign in once you're online."

Rationale: the minimum 1s hold isn't lazy — it's a moment for the brand. Apps that flash through splash feel anxious. Tribely is a slow product (you don't sign up to "swipe"); the splash sets that pace.

---

## Screen 2 — Welcome

Shown when there's no session. The first impression that earns the trust to enter an email.

Layout (mobile portrait): edge-to-edge mood photograph (hawker centre at dusk, low-light, anonymous figures, low angle — see `welcome-photo-prompt.md`) across the top ~50% with a slow continuous parallax (8px/8s). Lower half on warm-cream surface:

- **Display L italic** headline: "Find your people, anywhere." (stagger-fades word-by-word, 200ms each)
- **Body L secondary** copy: "Solo travelers create real-life events. You join the ones that sound like you."
- Primary CTA filled, 56dp height: "Create an account"
- Text-link secondary: "I already have one"

**Rationale for putting the photo above the text:** Tribely is about places. The image telegraphs the product before any word does. Most auth screens lead with the brand or a promise; we lead with a _moment_.

States:

- Default
- Image still loading (or asset missing): a flat warm-cream block with the ink mark centered, no copy yet.

---

## Screen 3 — Sign In

Layout: large back arrow (32dp) top-left. Display L italic "Welcome back." Body L secondary "Sign in to your Tribely account." Email field, password field with a "show / hide" _text_ toggle (NOT eye icon — accessible, translatable, bigger tap target). "Forgot password?" caption-link right-aligned. Primary CTA "Sign in" 56dp filled, full-width. Below: "Or continue with Google" ghost button — DISABLED with "Coming soon" caption.

Inputs: 1.5dp border, 12px radius, focus state = 4dp soft ember-coral glow (NOT a sharp 2dp ring).

### States — Sign in form

| State               | Behavior                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Idle (empty)**    | Sign in button DISABLED. Inputs at rest.                                                                                                                                                                                 |
| **Idle (filled)**   | Sign in button ACTIVE.                                                                                                                                                                                                   |
| **Validating**      | Email format checked on `blur`, never while typing. Inline error: small triangle accent + caption in coral, below the field. Field border becomes coral.                                                                 |
| **Submitting**      | Button text replaces with 3-dot pulse animation (•••). Inputs disabled (opacity 0.5). Form has subtle vertical shimmer (very subtle — 6% brightness oscillation, 1.5s loop). Cursor remains on the focused field if any. |
| **Success**         | Button text becomes "You're in." for 400ms with a tiny coral check ✓ animating in. Then the page fades to warm-cream, `/home` fades up.                                                                                  |
| **Error 401**       | Banner above the form: "That email and password didn't match. Try again, or reset your password." Inputs stay populated; password field empty for re-entry.                                                              |
| **Error 429**       | Banner: "Too many attempts. Try again in {N} seconds." with live-counting timer (uses API's `Retry-After`). Sign in button DISABLED while timer runs.                                                                    |
| **Network failure** | Banner: "Couldn't reach Tribely. Check your connection." Sign in button stays ACTIVE so the user can retry.                                                                                                              |
| **Server 5xx**      | Banner: "Something's off on our end. Give it a moment."                                                                                                                                                                  |
| **Reduced motion**  | Pulse → static "•••" without animation. Shimmer disabled.                                                                                                                                                                |

Banner style: soft-coral background, 1px ember coral left-border, 12dp padding, body M weight 500, dismissible × on the right.

---

## Screen 4 — Sign Up

Layout: same chrome as Sign In. Display L italic "Welcome." Body L secondary "Tell us a few things to get started." Display name field with helper "This is what other travelers will see." Email field. Password field with show/hide + 3-pip strength meter (▰▰▱) and helper "8+ characters." Trust microcopy _above_ the CTA (italic caption): "We'll never share your email. You can change anything later." Primary CTA "Create account."

Detail decisions:

- Strength indicator: **three pip-bars** (▱→▰), not a continuous bar. Discrete states are easier to perceive at a glance and don't imply a misleading 0–100 score.
- Trust microcopy _above_ the CTA. Reading order = "I see the form fields → I see the trust statement → I commit." Below the CTA it'd be missed.
- No phone field. Some Singapore apps lead with phone-OTP — out of MVP scope.

### States — Sign up form

Same as sign-in plus:

- **Display-name validation**: min 2, max 50, accepts Unicode (Chinese/Tamil/Malay names work). On blur.
- **Password strength**: updates _while typing_ (not blur — they need feedback as they choose). 8+ chars = OK; 12+ with mixed = Strong. Feedback only, not blocking.
- **Error 409 (email exists)**: special banner "An account with that email already exists." with inline "Sign in instead →" button that navigates to `/sign-in` _with the email pre-filled_. The highest-friction failure deserves the gentlest recovery.

---

## Screen 5 — Forgot password (entry only, MVP)

The "Forgot password?" link opens a modal bottom sheet:

> **Password reset is coming soon.** Email support@tribely.app to recover your account, and we'll get you back in.
>
> [ Got it ]

This is the honest MVP. Don't ship a broken reset link; don't hide the entry point either. When the real reset flow ships, the sheet becomes the actual form — same entry point, no relearning.

---

## Screen 6 — Hand-off to Home

The transition is the brand moment.

| T         | Step                                                                                                                       |
| --------- | -------------------------------------------------------------------------------------------------------------------------- |
| T+0       | Sign-in CTA pressed                                                                                                        |
| T+0–300ms | Form shimmers; button shows ••• pulse                                                                                      |
| T+API     | Token issued + refresh token persisted                                                                                     |
| T+0       | Button text → "You're in." with ✓ inline (300ms)                                                                           |
| T+300ms   | Whole screen fades to warm-cream (250ms ease-in-out)                                                                       |
| T+550ms   | `/home` fades up (250ms ease-out)                                                                                          |
| T+800ms   | `/home` complete; greeting "Welcome, {firstName}." fades in at top (200ms), holds 3000ms, fades out (200ms) — auto-dismiss |

`displayName` is parsed by first whitespace; if no spaces, the whole name is shown. Localization-safe.

`prefers-reduced-motion`: T+300 onward collapses to a single 80ms cross-fade with no greeting animation; greeting still appears as static text and auto-clears after 3s.

---

## Microcopy library (final)

Voice principles — sentences end short. No exclamation marks (sounds like a sales email). No idioms. No "Oops!" "Yay!" or other cute. We are warm but adult.

```
WELCOME            "Welcome back." / "Welcome."
SIGN_IN_BTN        "Sign in"
SIGN_UP_BTN        "Create account"
FORGOT_LINK        "Forgot password?"
SHOW_PWD           "show" / "hide"
EMPTY_EMAIL        "Email address is required."
INVALID_EMAIL      "That doesn't look like an email."
EMPTY_PASSWORD     "Password is required."
SHORT_PASSWORD     "8 characters or more."
WRONG_CREDS        "That email and password didn't match. Try again,
                   or reset your password."
RATE_LIMITED       "Too many attempts. Try again in {n} seconds."
NETWORK            "Couldn't reach Tribely. Check your connection."
SERVER             "Something's off on our end. Give it a moment."
EMAIL_EXISTS       "An account with that email already exists."
EMAIL_EXISTS_CTA   "Sign in instead →"
TRUST_LINE         "We'll never share your email. You can change
                   anything later."
SUBMIT_LOADING     "•••"
SUBMIT_SUCCESS     "You're in."
GREETING           "Welcome, {firstName}."
```

All <60 chars. None rely on English wordplay. None use imperative shouting.

## Accessibility & localization

- All ink-on-cream and ink-on-peat combos hit **WCAG AA 4.5:1** (verified: `#1A1714` on `#FAF6EF` = 17.9:1, `#F4EEDF` on `#131110` = 16.2:1).
- Coral-banner text on coral-tinted bg verified at 5.8:1.
- Tappable targets ≥48dp.
- Form fields announce label + error to TalkBack/VoiceOver.
- `show` / `hide` toggle is a `<button>` element, announced as such.
- The ink mark is decorative — `excludeFromSemantics: true`.
- Headlines tested for 30% length expansion (French/German/Vietnamese).
- Display name accepts Unicode letters; does NOT enforce ASCII.
- `Email` value object is the same one the API uses — no client-only stricter rules.
- RTL is _not_ in MVP. Singapore doesn't need RTL; defer Arabic/Hebrew when those markets come.

## What we are explicitly NOT doing

- Stock travel photography (Bali sunsets, suitcases on beaches).
- Globe / passport / paper-plane icons.
- Purple gradient backgrounds.
- Material You expressive defaults.
- Glassmorphism / frosted blur.
- Mascots, illustrated characters, "fun" empty states.
- Spinners.
- "Oops!" / "Whoopsie!" cute error voice.
- Eye icon for show-password (text toggle is more accessible).
- Skip / dismiss on the welcome screen.
