# Selfie Verification — Data Retention & Handling Policy

**Status:** v1.0 — locked for launch
**Owner:** Legal & Compliance (internal advisor) with CEO sign-off
**Last reviewed:** 2026-05-18
**Linear:** TRI-23 (feature), TRI-69 (this policy)
**Jurisdiction:** Singapore (Personal Data Protection Act 2012, with 2020 amendments)
**External counsel review:** REQUIRED before public launch on items flagged in Section 11.

---

## 1. Purpose

This policy governs the collection, storage, access, retention, and deletion of selfie images captured during Tribely's onboarding identity-verification flow. It exists to:

1. Satisfy PDPA obligations under sections 13–14 (Consent), 18 (Purpose Limitation), 20 (Notification), 24 (Protection), and 25 (Retention Limitation).
2. Provide a defensible audit trail for the PDPC in the event of inquiry or breach notification (s26A–26D).
3. Anchor engineering, product, and operations decisions to a single source of truth.

This policy applies only to selfies captured by the in-app verification flow. It does NOT apply to user-uploaded profile photos or to images embedded in user-generated event content — those are governed by the general Privacy Policy and Community Guidelines.

---

## 2. Scope of data covered

A single still image of the user's face, captured via the device camera, submitted exactly once at onboarding.

- **Format:** JPEG, captured by the mobile client.
- **Associated metadata stored alongside the image:**
  - User ID (internal cuid2).
  - Capture timestamp (UTC).
  - Submission status (`pending` | `approved` | `rejected`).
  - Reviewer ID and decision timestamp (when reviewed).
  - Rejection reason code (when rejected).
- **NOT collected / NOT computed / NOT stored:**
  - Biometric templates, facial embeddings, vector representations, or any machine-learning-derived feature vectors.
  - Liveness-check sensor data beyond what the camera produces as a still image.
  - Device identifiers beyond what is already attached to the authenticated session.

Selfies are classified as personal data under PDPA s2(1) (an image of an identifiable individual's face). They are NOT processed as biometric data because no template is computed or stored; review is human-only. This framing is material for both PDPA scope and Apple/Play sensitive-permission posture.

---

## 3. Lawful basis (PDPA s13–14)

Collection relies on **express consent** obtained at the point of capture. Consent is:

- **Unambiguous and deliberate (s14(1)(a))** — affirmed by a user action ("By tapping Capture, you agree to Tribely collecting and reviewing this photo for identity verification.") presented immediately above the camera capture control. Capture cannot occur without that affirmative tap.
- **Purpose-aware (s14(2))** — purpose, retention window, reviewer access, and the rejection path are disclosed contemporaneously on the capture screen (short-form notice, with a link to the full Privacy Policy section on verification).
- **Withdrawable (s16)** — withdrawal mechanism is account deletion (see Section 8). There is no continuing-processing scenario from which to withdraw separately; the image is reviewed once.

The "By tapping Capture, you agree…" pattern is the launch consent UI. It is NOT a separate checkbox. External counsel sign-off on this pattern for facial-image collection is a launch-blocking item (see Section 11).

---

## 4. Purpose limitation (PDPA s18)

The selfie is collected and used **only** to:

1. Confirm that the account holder is a real human presenting their own face at onboarding.
2. Provide a reviewer-audit record if the decision is later disputed.

The selfie is **not** used for:

- Training any model, internal or third-party.
- Matching against other users, watchlists, or external identity databases.
- Marketing, advertising, analytics, or profiling.
- Sharing with any third party except as required by law (PDPA s17, Computer Misuse Act, valid Singapore court order).

Any proposed future use (e.g., dispute-system surfacing, recovery-via-selfie, biometric matching, re-verification) is a re-scoping event that must reopen this policy with CEO and external counsel.

---

## 5. Storage location and architecture

- **Provider (v1):** AWS S3 (or any S3-compatible bucket configured via `STORAGE_ENDPOINT`). See `docs/runbooks/sg-selfie-storage-provisioning.md` for one-time provisioning steps.
- **Region:** AWS `ap-southeast-1` (Singapore). Bucket: `tribely-selfies-prod-sg-ap-southeast-1`. Bucket naming convention going forward: `tribely-<purpose>-<env>-sg-<region-id>` — event-photo and avatar buckets will follow the same pattern when provisioned.
- **Cross-border transfer (PDPA s26):** Not engaged. Data does not leave Singapore.
- **Encryption at rest:** SSE-S3 (AES-256, provider-managed keys) — default for v1. Applied atomically at bucket creation; no upload window exists with unencrypted objects.
- **Encryption in transit:** TLS 1.2+ on all client-to-storage and server-to-storage paths.
- **Access path:** Signed, short-lived URLs only, via the `FileStorage` port. No public-readable objects under any circumstance. Public Access Block enforced bucket-side (all four flags set to `true`).

> **PDPA jurisdictional warning.** The v1 provider selection is a legal decision, not only a technical one. `STORAGE_ENDPOINT` exists to allow a swap to any S3-compatible provider (Cloudflare R2, Backblaze B2, MinIO, DigitalOcean Spaces, etc.), but doing so is **NOT a config-only change**. Any swap that moves the data-at-rest location outside Singapore requires a fresh PDPA s26 cross-border transfer review before the new configuration is deployed to production. "The endpoint variable accepts any URL" does not imply "any destination is pre-approved." Operators must not treat this as a tactical knob without legal sign-off.

If engineering determines that a Singapore-region bucket is operationally infeasible at launch, this triggers a CEO re-decision — it does NOT default to a US/EU region. There is no pre-approved transfer basis under s26 for this data class.

**Downstream:** TRI-5 (concrete `S3FileStorage` adapter) and TRI-23 (selfie capture flow) are the downstream consumers of this decision. The selfie flow is blocked until both TRI-5 and provisioning per the runbook above are complete.

---

## 6. Access controls (PDPA s24)

- **Reviewer role:** A named, bounded role assigned to the founding team only at v1. Role assignment is recorded; the role assignment record IS the named-individual access record for PDPA s24 purposes while the role remains bounded to the founding team. Any role expansion is a re-scoping event.
- **Access logging:** Every read of a selfie image (URL signing event, in-app reviewer view) is logged with reviewer ID, user ID being reviewed, timestamp, and outcome. Logs are retained for 12 months and are append-only.
- **Engineering access:** Production engineering staff have infrastructure-level access to the bucket. Direct image inspection by engineering is permitted only for incident response and is itself logged.
- **No third-party processor access** beyond the storage provider acting as a sub-processor under provider-default terms. Resend (email) and any analytics tooling do NOT have access to selfie objects.

External counsel sign-off on the sufficiency of the bounded-reviewer-role-plus-access-log pattern (in lieu of separately named individuals in this document) is a launch-blocking item (see Section 11).

---

## 7. Retention (PDPA s25)

Retention is the minimum window required to serve the disclosed purpose plus a defensible audit tail. PDPA s25 sets no numeric maximum; the obligation is to destroy or anonymise when the purpose is served and no legal-business need remains.

**Approval is defined concretely as: the single moment the reviewer's decision is written to the database with `reviewer_decision = approved`.** The retention clock starts at that timestamp. No other event (queue entry, partial review, soft-approval) starts the clock.

| State | Retention window | Trigger to delete |
|---|---|---|
| Pending (awaiting review) | Until review completes | Reviewer decision written |
| Approved | **30 days from approval timestamp** OR until account deletion, whichever is first | Daily scheduled job + account-deletion cascade |
| Rejected | **30 days from rejection timestamp** OR until account deletion, whichever is first | Daily scheduled job + account-deletion cascade |
| Re-uploaded after rejection | New independent retention clock on the new submission; prior rejected submission deletes on its own original schedule | No rolling window |

**Why 30 days for approved selfies:** the verification decision is the recorded outcome; the underlying image is retained only for the dispute tail (user disputes decision, reviewer-quality audit, late-stage fraud signal). 30 days is the internal-judgment window covering those scenarios without indefinite retention. External counsel sign-off on s25 defensibility of this window is a launch-blocking item (see Section 11).

**Why 7 days for rejected selfies:** users may retry; we keep the rejected image briefly for reviewer consistency and to detect repeated submission patterns. After 7 days, only the rejection event and reason code remain.

**What persists past the retention window in all cases:** the decision metadata (status, decision timestamp, reviewer ID, rejection reason code). Only the image object and any image-derived data are deleted. Metadata is part of the account record and follows account-lifecycle retention.

**Re-verification:** One-time at onboarding for v1; may be revisited post-launch. No re-verification cadence, no scheduler, no re-prompt UI at launch.

---

## 8. Deletion mechanics

- **Scheduled deletion:** A daily job identifies records past their retention window and issues authenticated deletes against the storage provider. The job's run log is retained for 90 days.
- **Account deletion cascade:** When a user deletes their account (mandatory path per Apple App Store Review Guideline 5.1.1(v) and Google Play Account Deletion Policy 2024), the selfie image and all image-derived data are deleted in the same transaction as the account record. If the user's selfie is mid-review at the time of deletion, the in-flight reviewer task is cancelled and the image is deleted immediately — no reviewer action is required.
- **Verification of deletion:** The daily job emits a deletion-event record (user ID, deletion timestamp, trigger reason). This record is the evidence of compliance with s25; it is retained for 24 months.
- **Backup propagation:** Backups containing deleted selfies are aged out on the storage provider's standard backup retention (no longer than 30 days after the primary deletion). No selfie persists in any tier longer than 60 days from the original retention trigger.

---

## 9. User rights (PDPA s21–22)

- **Access (s21):** A user may request a copy of their selfie and the decision metadata. Response within 30 calendar days. While the image still exists, it is returned; after retention-window deletion, only the decision metadata remains and is returned with a note that the image has been deleted per this policy.
- **Correction (s22):** A user may dispute the verification decision. The reviewer reviews the dispute against the retained image (if within retention window). Disputes raised after image deletion are decided on metadata alone, which weighs in the user's favour.
- **Withdrawal of consent (s16):** Effected via account deletion. There is no partial-withdrawal path because there is no continuing processing.
- **Contact path:** `privacy@gotribely.com`. *This mailbox is required to be provisioned and monitored before this policy is referenced in any in-app surface or external-facing context (tracked separately).*

---

## 10. Breach notification (PDPA s26A–26D)

A breach involving selfie data is by default treated as a notifiable event because facial images of an identifiable individual carry significant-harm potential.

- **PDPC notification:** Within 72 hours of becoming aware of a breach that affects 500+ individuals OR is likely to result in significant harm.
- **Affected-user notification:** As soon as practicable after PDPC notification, unless an exception under s26D applies.
- **Incident-response owner:** Engineering lead initiates containment; Legal & Compliance drafts the s26B notification with external counsel review before submission.

---

## 11. External counsel review — launch-blocking items

The following are flagged for Singapore PDPA counsel review before public launch:

1. **Section 7 — defensibility of the 30-day approved-selfie retention window under PDPA s25.**
2. **Section 6 — sufficiency of the bounded-reviewer-role-plus-access-log pattern (in lieu of individually named accessors) under PDPA s24.**
3. **Section 3 — sufficiency of the "By tapping Capture, you agree…" affirmative-tap consent pattern under PDPA s14 for facial-image collection without a separate checkbox.**

This policy is an internal compliance artefact. It is NOT a legal opinion and is not to be cited in PDPC correspondence without external counsel review.

---

## 7A. Verification failure & appeal metadata (TRI-70)

This subsection extends Section 7 to cover the abuse-prevention metadata introduced by the verification-failure flow. It is NOT a separate policy; it is part of this policy.

### 7A.1 Scope

Three fields on the `User` aggregate:

| Field | Type | Purpose |
|---|---|---|
| `selfieAttemptCount` | integer (0–3+) | Rate-limit gate — enforces the 3-attempt budget before appeal lockout. |
| `selfieLastFailureCategory` | enum (`lighting` / `face_not_visible` / `quality` / `other`) | Powers in-app failure copy and pre-populated support context. |
| `selfieAppealLockedAt` | timestamp, nullable | Enforces the 24h lockout window; triggers appeal routing. |

These fields contain NO image data and NO biometric data. They are personal data under PDPA s2(1) only by virtue of being attached to an identifiable user record.

### 7A.2 Lawful basis and purpose (PDPA s13–14, s18)

Collection relies on the same express consent obtained at selfie capture (Section 3), extended in the layered notice to cover "we keep a record of your verification attempts to prevent abuse." Use is restricted to:

1. Enforcing the 3-attempt-budget rate limit.
2. Enforcing the 24h lockout window.
3. Pre-populating the support context for an appeal (subject to user override — see Section 7A.5).
4. Internal Trust & Safety review of appeal patterns.

The fields are **not** used for marketing, profiling, shadow-banning beyond the disclosed lockout, sharing with third parties, or training any model.

### 7A.3 Retention (PDPA s25)

| State | Retention window | Trigger to delete |
|---|---|---|
| Account active | Lifetime of account | None — retained for abuse-prevention purpose throughout account lifetime |
| Account deleted | 0 (immediate cascade) | Account-deletion cascade per Section 8 |
| Appeal resolved as approved | Fields are NOT cleared on appeal approval | See Section 7A.4 |

**Why lifetime-of-account is defensible under s25:** The abuse-prevention purpose persists for the lifetime of the account. Clearing on appeal-approval would defeat the rate-limit's purpose — a bad-faith actor could reset their attempt count by appealing. The fields are minimal (one int, one enum, one timestamp), contain no sensitive content, and are deleted on account deletion. This is consistent with how login-attempt counters and account-lockout timestamps are treated industry-wide.

### 7A.4 Behavior on appeal approval

On reviewer approval of an appeal, `selfieAppealLockedAt` is cleared (the user regains access). `selfieAttemptCount` and `selfieLastFailureCategory` are **preserved** as historical record — they form part of the reviewer-audit trail and the future-abuse-detection signal. This is intentional and aligned with the lifetime-of-account retention basis in 7A.3.

### 7A.5 Pre-populated support context

When the user taps "Contact support" after lockout, the device's default mail client is opened with a pre-populated subject and body. The body includes the values of these three fields, plus userId, app version, and OS. The user is shown a disclosure screen (see `docs/policies/verification-appeal-disclosure.in-app-excerpt.md`) BEFORE the mail client opens, and can edit or delete any of this content before sending. The user's ability to edit/delete preserves PDPA s14(1)(a) deliberate-consent semantics for the onward transmission.

### 7A.6 User rights (PDPA s21–22)

- **Access (s21):** A user may request a copy of these three field values. They are returned alongside the selfie decision metadata per Section 9. Response within 30 calendar days.
- **Correction (s22):** These fields are operational counters and timestamps; correction is not user-facing. A successful appeal effectively "corrects" `selfieAppealLockedAt` by clearing it.
- **Withdrawal of consent (s16):** Effected via account deletion (cascade per Section 8).

### 7A.7 Access controls

These fields are part of the `User` aggregate and follow the same access pattern as other user record fields. Reviewer access during appeals is logged per Section 6.

---

## 8A. Deletion-event audit retention (TRI-82)

This subsection extends Section 7 (Retention) and Section 8 (Deletion mechanics) to cover the `selfie_deletion_events` append-only audit table introduced by TRI-82. It is NOT a separate policy; it is part of this policy. Schema-level details (column types, indices, DB-role hardening) are out of scope here and live in the `features/audit/` README and TRI-130 respectively.

### 8A.1 Uniform 30-day retention for selfie images (supersedes Section 7 table for rejected state)

Effective TRI-82, the retention window for **rejected** selfies is harmonised with the approved-selfie window: **30 days from the decision timestamp** OR until account deletion, whichever is first. This supersedes the 7-day rejected-state row in the Section 7 table.

The Section 7 table is read as if the Approved and Rejected rows share the **30 days from decision timestamp** window. Re-uploaded-after-rejection semantics are unchanged: the new submission starts an independent 30-day clock; the prior rejected submission deletes on its own original schedule.

**Why uniform 30 days:**

1. **Auditor-defensible posture.** A single retention horizon for the image-object data class is materially easier to defend to the PDPC under s25 than a state-dependent window. The asymmetric 7-day rejected window introduced an explanatory burden ("why shorter for rejected?") that the underlying purpose-limitation analysis did not earn — the dispute-tail and reviewer-quality-audit purposes apply symmetrically to both decision outcomes.
2. **Removes per-state branching from the sweep job.** The deletion-automation job (TRI-79) selects by `decisionTimestamp < now() - 30d` without inspecting `reviewer_decision`. Single predicate, single failure mode.
3. **Rejected-selfie evidentiary chain is preserved independently.** A `selfie_deletion_events` row is written on every deletion regardless of decision state (see 8A.2), and that row is retained for 24 months. Shortening the image-object window for rejected selfies was historically motivated by minimisation; that minimisation is now achieved by the s25 evidentiary tail living in the audit table rather than in the image-object lifetime.

*Cited verdict:* TRI-82 workflow Q1 — legal-compliance cleared the uniform 30-day window as PDPA s25-defensible on 2026-05-19, on the condition that the deletion-event audit row carries the long-tail evidence (see 8A.2).

External counsel review of this uniform window is folded into the existing Section 11 item (1) — no new launch-blocking item is created.

### 8A.2 Deletion-event 24-month retention (`selfie_deletion_events`)

Every deletion of a selfie image — whether by scheduled sweep, account-deletion cascade, user request, or aged-out reviewer rejection — writes exactly one row to the `selfie_deletion_events` table inside `features/audit/`. This row is the PDPA s25 evidence-of-deletion artefact referenced in Section 8 ("Verification of deletion") and is retained for **24 months from `occurredAt`**, after which a separate sweep job prunes it.

The 24-month window is anchored in PDPA s25 evidentiary-window guidance: the obligation to show that data was destroyed when its purpose was served persists beyond the destruction event itself. 24 months covers the practically observed window for PDPC inquiry, user access-request lookback, and reviewer-decision dispute escalation. It is intentionally **shorter** than indefinite retention (which would defeat s25's destroy-when-no-longer-needed principle) and **longer** than the image-object window (which would defeat the evidentiary purpose).

**`userId` design note — string column, not foreign key.** Each `selfie_deletion_events` row stores `userId` as a plain string column with **no foreign-key constraint** to the `users` table. This is a deliberate evidentiary-survival design choice, not an oversight:

- An auditor or PDPC inquiry asking "prove you deleted this user's selfie" must be answerable **after** the user account itself has been deleted. A cascading FK would destroy the evidence row at the moment the underlying account is removed — the precise moment at which the evidence is most needed.
- The account-deletion cascade (Section 8) deletes the selfie image and the `users` row atomically, but the `selfie_deletion_events` row written by that cascade is independent of the FK graph and survives. Lookup is by `userId` string; the absence of a corresponding live `users` row is expected and is itself part of the evidence ("the user no longer exists; here is the deletion record").

The 24-month sweep job is **separate** from the 30-day selfie-image sweep job. Different retention horizons, different failure modes, different DB roles (per TRI-130). The two jobs must not be fused.

*Cited verdict:* TRI-82 workflow Q3 — legal-compliance confirmed that `userId`-as-plain-string (no FK, no cascade) satisfies PDPA s25 by preserving the evidence-of-deletion chain past account-record deletion, adjudicated 2026-05-19.

### 8A.3 Definition — `reason = user-request`

The `selfie_deletion_events.reason` column carries a closed enum of four values at launch: `retention-sweep` | `account-deletion` | `user-request` | `reviewer-rejection-aged`. Adding a fifth value is a re-scoping event requiring CEO sign-off and a stated regulatory or product driver.

The `user-request` value covers **both** of the following user-initiated deletion paths:

1. **Explicit deletion request.** A user invokes the in-app "delete my selfie" action (or the equivalent path surfaced via the PDPA s21 access/withdrawal channel at `privacy@gotribely.com`). The deletion is processed and one `selfie_deletion_events` row is written with `reason = user-request`.
2. **Resubmit-replacement.** A user submits a new selfie that supersedes a prior submission (typically after rejection, but also permitted in the re-upload-after-rejection path defined in Section 7). The prior image is deleted as part of the supersession; one `selfie_deletion_events` row is written for the superseded image with `reason = user-request`.

Both paths are user-initiated and both reflect the user's act of withdrawing the prior image from Tribely's processing surface. Distinguishing them at the audit-table level was considered and rejected as over-specification for v1 — the act ("user caused this image to be deleted") is the auditor-relevant fact; whether the cause was an explicit-delete tap or a resubmit-replace is recoverable from the cross-joined `http_audit_logs` row by `requestId` when needed.

Paths that are **NOT** `user-request`:

- The daily retention sweep deleting an image at the 30-day boundary → `retention-sweep`.
- The account-deletion cascade per Section 8 → `account-deletion` (even though the user initiated the account deletion; the cascade is the operative deletion event for the selfie image and is captured under its own reason for clean separation from the per-image `user-request` flows).
- A reviewer-rejection path where the image is aged out by sweep after rejection → `reviewer-rejection-aged`.

*Cited verdict:* TRI-82 workflow Q4 — legal-compliance confirmed that collapsing explicit-delete and resubmit-replacement under a single `user-request` reason is consistent with PDPA s25 evidence requirements (the auditor-relevant fact is user-causation, not the in-app surface), adjudicated 2026-05-19.

---

## 12. Change log

| Date | Version | Change | Approver |
|---|---|---|---|
| 2026-05-14 | 1.0 | Initial policy. Locked retention windows, SG-resident storage, no biometrics, one-time verification, named external-counsel triggers. | CEO (TRI-69) |
| 2026-05-30 | 1.0 (annexe) | TRI-82 extension. Harmonised rejected-selfie retention to 30 days (§7 table + 8A.1); added 24-month `selfie_deletion_events` window with `userId`-as-string evidentiary-survival design (8A.2); defined `reason=user-request` scope (8A.3). | Legal & Compliance (TRI-129) |
