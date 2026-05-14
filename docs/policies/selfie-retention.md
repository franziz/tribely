# Selfie Verification — Data Retention & Handling Policy

**Status:** v1.0 — locked for launch
**Owner:** Legal & Compliance (internal advisor) with CEO sign-off
**Last reviewed:** 2026-05-14
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

- **Storage region:** Singapore-resident object storage. *Provider and bucket identifier pending selection (tracked separately); the SG-resident constraint is non-negotiable per Section 4 and Section 11. No data will be collected via the selfie flow until this is resolved.*
- **Cross-border transfer (PDPA s26):** Not engaged. Data does not leave Singapore.
- **Encryption at rest:** Provider-managed AES-256 (minimum).
- **Encryption in transit:** TLS 1.2+ on all client-to-storage and server-to-storage paths.
- **Access path:** Signed, short-lived URLs only. No public-readable objects under any circumstance.

If engineering determines that a Singapore-region bucket is operationally infeasible at launch, this triggers a CEO re-decision — it does NOT default to a US/EU region. There is no pre-approved transfer basis under s26 for this data class.

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
| Rejected | **7 days from rejection timestamp** OR until account deletion, whichever is first | Daily scheduled job + account-deletion cascade |
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

## 12. Change log

| Date | Version | Change | Approver |
|---|---|---|---|
| 2026-05-14 | 1.0 | Initial policy. Locked retention windows, SG-resident storage, no biometrics, one-time verification, named external-counsel triggers. | CEO (TRI-69) |
