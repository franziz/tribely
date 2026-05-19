# Selfie Verification Recourse — Store-Policy Memo

**Purpose:** Pre-empt Apple App Review and Google Play Policy challenges to Tribely's selfie-verification gate by documenting that the failure + appeal design satisfies platform requirements for identity-verification recourse.
**Scope:** Apple App Store Review Guidelines; Google Play Developer Program Policies.
**Linear:** TRI-70 (design), TRI-37 (submission packet).
**Status:** v1.0 — locked for TRI-37 submission.
**Owner:** Legal & Compliance (internal advisor).
**Not a legal opinion.** Internal compliance artefact only.

---

## Design summary (as of TRI-70 close)

| Element | Value |
|---|---|
| Retry budget before appeal | 3 attempts |
| Lockout window | 24 hours OR until appeal resolution, whichever earlier |
| Appeal channel | mailto: `support@gotribely.com` (separate alias from `privacy@gotribely.com`) |
| Public SLA | "within 3 business days" |
| Hard-ban at launch | None — 3-attempt + 24h lockout is the only enforcement |
| Browse-while-unverified | Permitted |
| Verified-gated actions while unverified | Blocked (request to join, create event) |
| Failure-reason transparency | Category-level ("lighting", "face not visible", "quality", "other") |

---

## Apple App Store Review Guidelines

### 5.1.1(v) Account Sign-In — Data Collection and Storage (Recourse)

**Guideline text (paraphrased):** Apps that require identity verification or that gate functionality behind verification must provide a clear path for users to dispute or recover from failed verification.

**Tribely design:** After the 3rd failed attempt, the user is routed to an appeal flow with (a) a clear in-app explanation of the lockout, (b) a "Contact support" CTA that opens `support@gotribely.com` with pre-populated context, (c) a public SLA of "within 3 business days," (d) automatic 24h time-based unlock as a parallel recovery path.

**Why this satisfies 5.1.1(v):** The recourse is in-app, named, time-bounded (24h auto-unlock), and human-staffed (3-day SLA). Apple has rejected apps where the only recourse was "delete your account and try again" or an unstaffed support address. Tribely's design avoids both failure modes.

### 5.1.1(i) Account Sign-In — Required Information

**Guideline text (paraphrased):** Apps must not require more user information than is strictly necessary.

**Tribely design:** Verification collects exactly one selfie image plus metadata (per TRI-69). Failure metadata (3 fields per TRI-70) is the minimum needed to operate the rate limit.

**Why this satisfies 5.1.1(i):** No additional information is collected during the failure or appeal flow itself; the appeal context (userId, attempt count, last failure category, app version, OS) is data Tribely already holds. The user-editable pre-population is an information-minimization win, not a maximization.

### 1.6 Data Security (Physical Harm)

**Guideline text (paraphrased):** Apps must take steps to protect users from physical harm where the app facilitates real-world meetings.

**Tribely design:** The selfie verification gate IS Tribely's primary 1.6 mitigation — it prevents anonymous accounts from requesting to join real-world meetups. The TRI-70 failure flow keeps the gate intact (no bypass) while providing recourse for false-positive rejections.

**Why this satisfies 1.6:** The gate is preserved. A failed user cannot perform Verified-gated actions (request to join, create event) during pending, failed, or locked states. The 3-attempt-then-appeal pattern is the standard 1.6-compatible recourse design.

### 1.2 Safety — User-Generated Content

**Guideline text (paraphrased):** UGC apps must provide reporting, blocking, and moderation.

**Tribely design (in scope for TRI-70):** Rejected selfies are NOT considered user-generated content surfaced to other users — they are private submissions reviewed only by Tribely's bounded reviewer role per TRI-69 Section 6. The verification image is never shown to any other user. Failure metadata is internal-only.

**Why this satisfies 1.2:** 1.2 obligations attach to content surfaced to other users. The selfie-verification flow is one-to-one between user and reviewer; 1.2 is not engaged on the selfie itself. (General UGC reporting/blocking covered separately by event/profile UGC features.)

### 5.1.2 Data Use and Sharing

**Guideline text (paraphrased):** Apps must obtain consent for collection and disclose use of user data.

**Tribely design:** The mailto pre-population transmits user data through a third-party mail channel. The disclosure pattern in `docs/policies/verification-appeal-disclosure.in-app-excerpt.md` names the channel, the content, and the user's edit/delete control before the mail client opens.

**Why this satisfies 5.1.2:** Disclosure is explicit, contemporaneous, and pre-action. User has full edit/delete control. No silent data exfiltration.

---

## Google Play Developer Program Policies

### Personal & Sensitive Information policy — Identity verification

**Policy text (paraphrased):** Apps that collect government-ID-style or face-image identity data must provide users with a clear understanding of how the data is used and a path to dispute decisions.

**Tribely design:** Disclosure of use is in the consent screen (TRI-69 Section 3 / `selfie-retention.in-app-excerpt.md`); dispute path is TRI-70's appeal flow.

**Why this satisfies the policy:** Play's enforcement focus is on (a) prominent disclosure pre-collection (covered by TRI-69 consent screen), (b) a recourse path that does not require account abandonment (covered by TRI-70 appeal), and (c) data-retention discipline (covered by TRI-69 retention windows + TRI-70 Section 7A retention).

### User-Generated Content policy

**Policy text (paraphrased):** Apps hosting UGC must provide reporting and moderation.

**Tribely design / why it does not apply to TRI-70:** Same reasoning as Apple 1.2 above — the rejected selfie is not surfaced to other users. The Play UGC policy attaches to content surfaced publicly or to other users; the selfie verification flow is one-to-one between user and Tribely reviewer.

### Account Deletion Policy (mandatory since 2024)

**Policy text (paraphrased):** Apps must support in-app account deletion AND a web URL discoverable on the Play Store listing.

**Tribely design:** Account deletion cascade per TRI-69 Section 8 includes the selfie image. TRI-70 Section 7A.3 extends the cascade to the three new failure-metadata fields.

**Why this satisfies the policy:** Failure metadata is part of the User aggregate; deletion of the User cascades to these fields in the same transaction. No orphaned data persists past account deletion.

### Play Integrity / sensitive permissions

**Tribely design:** Camera permission is requested at the moment of selfie capture (TRI-23), with an iOS Info.plist `NSCameraUsageDescription` and an Android runtime prompt. No additional sensitive permissions are introduced by TRI-70.

**Why this satisfies the policy:** TRI-70 introduces no new permissions and no new sensitive-data classes — it only adds three scalar fields to an existing aggregate.

---

## Open gaps as of TRI-70 close

NONE that affect store-policy compliance.

The one operational gap is provisioning `support@gotribely.com` (the appeal alias) before any in-app surface references it. This is an ops/engineering provisioning item, not a design gap. Tracked separately as a follow-up (see TRI-70 posture memo Section 6).

---

## Change log

| Date | Version | Change | Approver |
|---|---|---|---|
| 2026-05-19 | 1.0 | Initial memo. Locked store-policy posture for TRI-70 design as ratified by CEO. | CEO (TRI-70) |
