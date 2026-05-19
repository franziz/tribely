# Post-Event Check-In — Data Handling & Retention Policy

**Status:** v1.0 — locked for launch
**Owner:** Legal & Compliance (internal advisor) with CEO sign-off
**Last reviewed:** 2026-05-19
**Linear:** TRI-29 (feature)
**Jurisdiction:** Singapore (Personal Data Protection Act 2012, with 2020 amendments)
**External counsel review:** REQUIRED before public launch on items flagged in Section 11.

---

## 1. Purpose

This policy governs the collection, storage, access, retention, deletion, and pseudonymisation of data captured by Tribely's post-event check-in flow. It exists to:

1. Satisfy PDPA obligations under sections 13–14 (Consent), 18 (Purpose Limitation), 20 (Notification), 24 (Protection), and 25 (Retention Limitation).
2. Provide a defensible audit trail for the PDPC in the event of inquiry or breach notification (s26A–26D).
3. Anchor engineering, product, and operations decisions to a single source of truth.
4. Substantiate the Trust & Safety narrative required for Gate 3 moderation-SLA approval and Apple App Store Review Guideline 5.1.1 / 1.6 defensibility.

The post-event check-in is the trust signal at the highest-stakes moment in the Tribely experience: the period immediately after strangers have met in person for the first time. A user who just attended an event returns to the app and is asked, once, whether everything was okay. The response — or deliberate non-response — is the earliest available safety signal without requiring real-time tracking. This is the context in which the data collected under this policy must be understood: it is safety infrastructure, not engagement instrumentation.

This policy applies only to check-in prompts and responses created by the post-event check-in flow. It does NOT apply to general in-app moderation reports, event cancellation records, or dispute-system records — those are governed by the general Privacy Policy and Community Guidelines.

---

## 2. Scope

### 2.1 In-scope at MVP

- **In-app foreground prompt:** displayed once on app foreground-resume when all of the following are true:
  1. The authenticated user has an RSVP confirmed for an event whose `endsAt` was at least 3 hours ago.
  2. No check-in record already exists for this user × event pair.
  3. The event's `endsAt` is no more than 7 days in the past (see Section 5 for rationale).
- **Two-path response:**
  - "All good" → creates a `PostEventCheckIn` record with `status = ok`.
  - "I need help" → creates a `PostEventCheckIn` record with `status = flagged`, captures an optional free-text `reportBody` (maximum 2 000 characters), and sends a notification email to `safety@gotribely.com`.
- **Pending state:** a record is created with `status = pending` at the moment the prompt is displayed, to prevent re-prompting on the same session or a rapid re-open. The record transitions to `ok` or `flagged` on response, or is swept by the pending-retention job if no response is given.

### 2.2 NOT in scope at MVP

- Push notification delivery of the check-in prompt (deferred, see Section 13).
- A moderation inbox UI within the app (deferred, see Section 13).
- Trust-signal aggregation, scoring, or surfacing on host or attendee profiles (deferred).
- Automated NLP or AI processing of free-text `reportBody` content.

---

## 3. Data classes

| Data element | Storage location | Classification |
|---|---|---|
| `PostEventCheckIn` record (id, eventId, hostUserId, attendeeUserId, status, createdAt, respondedAt, resolvedAt) | Primary DB — `post_event_check_ins` table | Personal data (PDPA s2(1)) — linked to identifiable individuals |
| `reportBody` | Primary DB — `post_event_check_ins.report_body` column, max 2 000 chars | Personal data; potentially sensitive (free-text safety report) |
| Outbound notification email to `safety@gotribely.com` | External mailbox — `safety@gotribely.com` | ID-only + free text (see Section 7 for redaction) |
| `post_event_check_in_events` audit log row | Primary DB — `post_event_check_in_events` table | Operational audit data (personal data by association) |

**NOT collected / NOT computed / NOT stored:**

- Real-time location data.
- Device accelerometer, GPS, or sensor data.
- Any biometric or health-and-fitness signal (the "did you get home safely" phrasing pattern is deliberately avoided to prevent Apple 5.1.1(i) Health & Fitness misclassification — see Section 10).
- Identifiers beyond those already present in the authenticated RSVP record.

---

## 4. Lawful basis (PDPA s13–14)

Collection relies on **express consent** obtained via privacy notice update and a one-time in-app intro sheet displayed at first foreground-trigger surface (see Section 12). Consent is:

- **Unambiguous and deliberate (s14(1)(a)):** the intro sheet describes the feature and its data handling before the first prompt is shown. The user proceeds by continuing to use the app after the notice is displayed.
- **Purpose-aware (s14(2)):** purpose, data types, retention windows, the flag-report path, and the SPF 999 disclaimer are disclosed contemporaneously in the intro sheet and in the full policy (linked from the intro sheet).
- **Voluntary:** check-in response is never mandatory. A non-response results in a pending record that is swept per the pending retention window (Section 4, Table 1). No functionality is gated on check-in response.
- **Withdrawable (s16):** withdrawal is effected via account deletion (Section 8). There is no continuing-processing scenario from which to withdraw partially; each check-in is a discrete, one-time event.

---

## 5. Foreground-trigger window

The foreground prompt is created — and the check-in record enters `status = pending` — only when:

1. The event's `endsAt` was at least **3 hours** ago (lower bound: the event must be over, and attendees have had time to travel home).
2. The event's `endsAt` is no more than **7 days** ago (upper bound: avoids surprising a user returning to the app after a long absence with a stale check-in prompt).

**Rationale for the 7-day upper bound:** A user who was present at an event but opens the app for the first time 10 days later has had ample time to seek help through other channels if needed. Surfacing a check-in prompt for a 10-day-old event produces confusion and does not serve the safety purpose. The 30-day pending-retention window (Section 4, Table 1) is the DB-side guardrail that handles records created near the edge of the window; the 7-day creation window is the client-trigger guardrail that prevents those records from being created in the first place.

Once a `PostEventCheckIn` record exists for a user × event pair — regardless of status — the foreground trigger does not fire again for that pair.

---

## 6. Pseudonymisation (PDPA s25 + Apple App Store Review Guideline 5.1.1(v) deletion cascade)

When a user deletes their account, the following cascade applies to `PostEventCheckIn` records:

### 6.1 Records in `status = pending` or `status = ok`

These records contain no safety-critical narrative. They are **fully deleted** in the same transaction as the account deletion. The absence of a `reportBody` means there is no information loss of safety value.

### 6.2 Records in `status = flagged` where the deleted user was the **attendee** (authored the report)

- The `attendeeUserId` field is replaced with an opaque cuid2 that is NOT linked to any User record in the database.
- The `reportBody`, `hostUserId`, `eventId`, `createdAt`, `respondedAt`, and `resolvedAt` are retained as-is.
- Rationale: the safety narrative and its relational context remain actionable for the moderation team, even after the author deletes their account.

### 6.3 Records in `status = flagged` where the deleted user was the **host** (subject of the report)

- The `hostUserId` field is replaced with an opaque cuid2 that is NOT linked to any User record in the database.
- All other fields are retained.
- Rationale: same as 6.2 — the safety record retains its operational value.

### 6.4 Pseudonymisation properties

- **Irreversible:** no plaintext-to-pseudo lookup table is retained. Once replaced, the original userId is gone.
- **Per-cascade:** each account-deletion cascade generates its own pseudonyms. Cross-feature pseudonym joinability is intentionally NOT preserved — a pseudonymised `attendeeUserId` in `post_event_check_ins` is not the same opaque value as any pseudonymised reference in a different table from the same cascade.
- **`post_event_check_in_events` audit rows** follow the same per-user pseudonymisation logic applied to the parent record cascade.

---

## 7. Retention windows (PDPA s25)

| Record class | Retention duration | Sweep action |
|---|---|---|
| `PostEventCheckIn` — `status = pending` | 30 days from `createdAt` | Delete raw record + associated `post_event_check_in_events` audit rows |
| `PostEventCheckIn` — `status = ok` | 90 days from `respondedAt` | Delete raw record + associated `post_event_check_in_events` audit rows |
| `PostEventCheckIn` — `status = flagged`, open (`resolvedAt IS NULL`) | Retained while open — no cap | None (active moderation case) |
| `PostEventCheckIn` — `status = flagged`, resolved (`resolvedAt IS NOT NULL`) | 12 months from `resolvedAt` | Delete raw record + associated `post_event_check_in_events` audit rows |
| `post_event_check_in_events` audit log | 24 months append-only, then rolling deletion | Sweep job — mirror TRI-79 selfie-deletion-events pattern |

**Rationale:**

- **30 days for pending:** the foreground-trigger window (Section 5) means a pending record is at most 7 days old when it could be legitimately created. 30 days is a generous sweep window that catches missed crons and slow recoveries without indefinite accumulation.
- **90 days for ok:** the check-in is a low-sensitivity positive signal. A 90-day tail provides a window for any retrospective safety review (e.g., a late-raised complaint about the same event) without indefinite retention of a routine record.
- **No cap for open-flagged:** an unresolved safety report must remain accessible to the moderation team for as long as it is open. Imposing an arbitrary cap could result in a legal-hold record being swept mid-investigation.
- **12 months for resolved-flagged:** provides a full-year tail for regulatory inquiry, appeal, or escalated action after a report is closed. Aligns with standard industry practice for safety-incident records.
- **24 months for audit log:** provides two full years of operational audit evidence. Rolling deletion after 24 months prevents indefinite accumulation while preserving the primary evidence window for potential PDPC inquiry (PDPA s26A–26D requires notification within 72 hours of becoming aware; a 24-month audit tail is adequate for investigation support).

**What persists past the retention window in all cases:** the `post_event_check_in_events` audit log row is the evidence of deletion compliance per s25. That log entry is itself subject to its own 24-month rolling retention window.

---

## 8. Deletion mechanics

- **Scheduled sweep job:** A daily job identifies `PostEventCheckIn` records past their retention window (per the table in Section 7) and issues database deletes. The job is implemented following the TRI-79 selfie-retention sweep pattern — each deletion is recorded in `post_event_check_in_events` with trigger reason `retention_sweep`.
- **Account deletion cascade:** When a user deletes their account:
  - Pending and ok records where the user is the attendee: deleted immediately.
  - Flagged records: pseudonymised per Section 6.
  - All associated audit rows in `post_event_check_in_events`: subject to same pseudonymisation rules as parent record.
- **Deletion verification:** The sweep job emits a `post_event_check_in_events` row for each deleted record (userId, eventId, deletion timestamp, trigger reason). This is the s25 evidence.
- **Backup propagation:** backups containing deleted records are aged out on the database provider's standard backup retention. No deleted `PostEventCheckIn` record persists in any tier longer than 30 days after the primary deletion.

---

## 9. Email-handoff redaction (outbound to `safety@gotribely.com`)

When a user submits a flagged check-in, the system sends an email to `safety@gotribely.com`. The email carries:

| Included | Excluded |
|---|---|
| Event ID (internal cuid2) | Display names (host or attendee) |
| Host user ID (internal cuid2) | Avatar URLs |
| Attendee user ID (internal cuid2) | Phone numbers |
| Event title (truncated to 40 characters) | Email addresses of any party |
| Event `endsAt` timestamp (UTC) | Device identifiers |
| Flagged-at timestamp (UTC) | |
| Free-text `reportBody` (verbatim, up to 2 000 chars) | |

**Rationale:** display names, avatars, and contact details live in the Singapore-region primary database. The `safety@gotribely.com` mailbox is operated by the founders and may be hosted on infrastructure outside Singapore (e.g., Gmail Workspace). Transmitting IDs + free text to the mailbox is operationally necessary; transmitting full PII is not and creates a potential PDPA s26 cross-border-transfer surface for named-individual data. Founders cross-reference the IDs against the admin panel when handling a report.

The `safety@gotribely.com` mailbox MUST NOT be forwarded to third-party ticketing or analytics services without a fresh PDPA s26 review.

---

## 10. Apple App Store posture

### 10.1 Privacy nutrition labels (App Store Review Guideline 5.1.1(i))

| Label | Classification | Notes |
|---|---|---|
| User Content → Other User Content | Required | Covers free-text `reportBody` submitted in flagged check-ins |

**NOT labelled as Health & Fitness:** the check-in prompt deliberately avoids "did you get home safely" or wellness-signal phrasing. The data class is safety-reporting user content, not a health or fitness metric. Mislabelling as Health & Fitness would invite scrutiny under 5.1.1(iv) and HealthKit policies that do not apply. The copy SoT in `apps/mobile/lib/src/features/check_ins/presentation/string_assets/check_in_copy.dart` must preserve this framing boundary — any future copy change that introduces wellness/fitness language is a re-scoping event requiring an updated privacy label and a re-review of this section.

### 10.2 Account deletion (App Store Review Guideline 5.1.1(v))

Account deletion cascade is specified in Section 6. Full deletion of pending and ok records; irreversible pseudonymisation of flagged records. Both paths satisfy the guideline's requirement that account deletion results in deletion or anonymisation of personal data.

### 10.3 Safety (App Store Review Guideline 1.6)

The following disclaimer MUST appear on the terminal flag-confirmation screen — the final screen shown after a user submits a flagged check-in and before the confirmation dismissal:

> **"If you're in immediate danger, call the Singapore Police at 999. We are not an emergency service."**

This is the canonical wording. It is reproduced verbatim in `apps/mobile/lib/src/features/check_ins/presentation/string_assets/check_in_copy.dart`, which is the mobile string-asset SoT. This policy document is the authoritative SoT; the mobile string asset mirrors it.

Presentation constraints:
- NOT a tappable button or phone-number deep link.
- NOT accompanied by any SPF logo, badge, or "we work with SPF / we partner with SPF" framing.
- Displayed as static body text on the confirmation screen.

### 10.4 Design commitment (App Store Review Guideline 4.0)

The flag-confirmation screen carries the binding commitment: **"We'll reach out within 24 hours."** This is a store-facing commitment and must be treated as a binding SLA for App Store Review purposes. See Section 11 (24h SLA) for operational coverage.

---

## 11. 24-hour SLA and founder-on-rotation

At MVP, flagged check-in reports are handled by the founding team operating on a rotation basis. The 24-hour response commitment on the flag-confirmation screen (Section 10.4) is backed by:

- Immediate email notification to `safety@gotribely.com` on every flagged submission.
- Founder-on-rotation responsibility to triage each report within 24 hours of receipt.
- The email carries sufficient context (event ID, host ID, attendee ID, event title, timestamps, free-text report) to reach out to the reporting user via the admin panel without displaying PII in the mailbox.

Promotion to a dedicated moderation team and inbox is deferred post-launch and is tracked under TRI-133. That promotion is contingent on Gate 3 completion AND month-3 retention data indicating that the foreground-only delivery miss-rate justifies push-delivered prompts (see Section 13).

---

## 12. Google Play posture

### 12.1 User-generated content (UGC) policy

The free-text `reportBody` is user-generated content submitted for a safety purpose. The flag-and-report flow, combined with the 24h SLA commitment (Section 11), satisfies Google Play's UGC policy requirements for apps that collect content related to user safety: a mechanism to report harmful content (the flag flow), a commitment to review it (the 24h SLA), and a mechanism to block or remove (moderation action on the resolved record).

### 12.2 Data Safety form

The following entry must be added to the Play Data Safety form:

| Field | Value |
|---|---|
| Category | User-generated content |
| Data type | Other user content (free-text safety report) |
| Purpose | Safety (report a safety concern) |
| Required / Optional | Optional (response is never mandatory) |
| Shared with third parties | No |
| Encrypted in transit | Yes |
| User can request deletion | Yes (via account deletion) |

### 12.3 Notification permission

Not applicable at MVP — the foreground-trigger prompt does not require a push notification permission. If push delivery is introduced (TRI-133), the Data Safety form must be updated and `POST_NOTIFICATIONS` permission rationale must be added to the Play listing.

---

## 13. Consent and notice (PDPA s13/s14, s20)

Collection of check-in data relies on:

1. **Privacy policy update:** the Tribely Privacy Policy must include a section on post-event check-in data handling before the feature ships to production. The update must reference this policy document by name and URL.
2. **In-app intro sheet:** a one-time notice displayed at first foreground-trigger surface. The short-form text is in `docs/policies/post-event-check-in.in-app-excerpt.md`. The intro sheet must appear before the first check-in prompt is shown; it is not shown again once dismissed.

**Affirmative re-consent is NOT required** if the privacy policy update is published before the first relevant RSVP confirmation for any user. The same pattern governs the selfie-retention policy (see `docs/policies/selfie-retention.md`, Section 3) — this policy follows that precedent.

Contact for data requests: `privacy@gotribely.com`. This mailbox must be provisioned and monitored before this policy is referenced in any in-app surface.

---

## 14. Post-launch promotion path (TRI-133)

The foreground-only delivery model is the MVP constraint, not the long-term design. After Gate 3 lands AND month-3 retention data indicates that the foreground-only miss-rate (users who had a relevant event but never reopened the app within the 7-day window) justifies it, the feature promotes to:

- Push-delivered check-in prompts (requires `POST_NOTIFICATIONS` permission and a Play Data Safety form update — see Section 12.3).
- A dedicated moderation inbox within the admin panel (removing the email-handoff dependency described in Section 9).
- Possible trust-signal aggregation surfaced on host profiles (requires a new policy section and CEO sign-off before implementation).

TRI-133 is the tracking ticket. None of the above changes are pre-authorised by this policy; each requires a policy amendment before the corresponding code ships to production.

---

## 15. Breach notification (PDPA s26A–26D)

A breach involving flagged check-in data (including `reportBody` content) is by default treated as a notifiable event. Free-text safety reports may contain sensitive personal information about individuals and incidents.

- **PDPC notification:** within 72 hours of becoming aware of a breach that affects 500+ individuals OR is likely to result in significant harm.
- **Affected-user notification:** as soon as practicable after PDPC notification, unless an exception under s26D applies.
- **Incident-response owner:** engineering lead initiates containment; Legal & Compliance drafts the s26B notification with external counsel review before submission.

---

## 16. User rights (PDPA s21–22)

- **Access (s21):** a user may request a copy of their check-in records (status, timestamps, and report body if flagged). Response within 30 calendar days. After the retention window, only the audit log record remains and is returned with a note that the primary record has been deleted per this policy.
- **Correction (s22):** check-in timestamps and status are operational fields; correction is not user-facing. A user who believes a record was created in error may request deletion via `privacy@gotribely.com` — treated as a withdrawal of consent under s16.
- **Withdrawal of consent (s16):** effected via account deletion (cascade per Section 8). There is no partial-withdrawal path; each check-in is a discrete event.
- **Contact path:** `privacy@gotribely.com`.

---

## 17. External counsel review — launch-blocking items

The following are flagged for Singapore PDPA counsel review before public launch:

1. **Section 7 — defensibility of the 12-month resolved-flagged record retention window under PDPA s25.** The safety-incident rationale is strong, but an explicit counsel sign-off is appropriate given the sensitivity of the content.
2. **Section 13 — sufficiency of the privacy-policy-update + in-app-intro-sheet consent pattern under PDPA s14 for safety-report collection without a separate affirmative tap.** The voluntary-response framing reduces friction; counsel should confirm it satisfies s14(1)(a).
3. **Section 9 — whether transmission of free-text `reportBody` to `safety@gotribely.com` (potentially hosted on infrastructure outside Singapore) constitutes a PDPA s26 cross-border transfer, and whether the "IDs + free text, no named PII" redaction pattern sufficiently mitigates that risk.**

This policy is an internal compliance artefact. It is NOT a legal opinion and is not to be cited in PDPC correspondence without external counsel review.

---

## 18. Related documents

- [`docs/policies/selfie-retention.md`](./selfie-retention.md) — sibling PDPA data-handling pattern; precedent for retention sweep mechanics and pseudonymisation approach.
- Privacy Policy (separate ticket) — must be updated to reference this policy before launch.
- TRI-133 — post-launch promotion path (push delivery + moderation inbox).

---

## 19. Change log

| Date | Version | Change | Approver |
|---|---|---|---|
| 2026-05-19 | 1.0 | Initial policy. Locked retention windows, foreground-trigger window, email-handoff redaction, pseudonymisation cascade, SPF 999 disclaimer, Apple/Play posture, 24h SLA, external counsel triggers. | CEO (TRI-29) |
