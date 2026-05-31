# Verification Appeals SOP

> **Status:** Drafted under the agents-draft / human-executes convention
> (precedent: TRI-77 selfie-storage runbook). Agents authored this SOP;
> the founder names the reviewer rotation and signs off on response-time
> commitments against real ops capacity. CEO sign-off recorded 2026-05-30
> on TRI-127.
>
> **Source-of-truth:** this file. Linked from TRI-127 (operational owner)
> and from the consumer ticket (TRI-70 for appeals).

## Channel

`support@gotribely.com` is the verification appeals intake channel. Users
who disagree with a selfie verification outcome — a rejection, a failure
category assignment, or the recorded state of their verification attempt —
submit an appeal by emailing this address. The channel is for verification
appeals only; it is NOT a general support inbox, a safety-report channel
(use `safety@gotribely.com` for those), or a data-correction channel
(although a PDPA s22 right-to-correction request arriving here is handled
in-place per the escalation path below — it does not need to be rerouted).

## SLA

**Acknowledgement:** 1 SG business day from receipt of the appeal email.
**Decision:** 3 SG business days from receipt.

**SG business day definition:** Monday through Friday, excluding Singapore
public holidays. The authoritative public-holiday list is the Ministry of
Manpower calendar at <https://www.mom.gov.sg/employment-practices/public-holidays>.

**Out-of-office coverage:** If the primary reviewer (founder) is unavailable
on a given business day, the backup reviewer listed in the Reviewer
assignment section below handles ack and decision within the stated SLA.
Until the backup slot is filled (Gate-1 before App Store submission), ack
and decision timelines are on the founder; no alternate coverage path
exists at SG launch.

## Reviewer assignment

**Primary reviewer:** Frans Siswanto (founder).

**Backup reviewer:** `[ Gate-1 placeholder — name before App Store submission ]`

**Log store:** `[ Founder-named at execute-time — Notion private DB or Google Sheet w/ 2FA ]`

The log store must be access-controlled to the named reviewer(s) only
(PDPA s24). Unindexed share-links, public Notion pages, and open-channel
patterns are forbidden. The store's native access log must be enabled and
retained for 12 months.

### Data Protection Officer designation

PDPA s11(3) requires Tribely to designate at least one individual as Data
Protection Officer responsible for ensuring compliance. This is required
from day one of processing personal data; it is not threshold-gated. s11(5)
requires the DPO's business contact information to be publicly available.

**Designated DPO:** Founder (Frans Siswanto). Public contact:
`privacy@gotribely.com`.

The DPO designation is independent of the appeals-reviewer rotation. The
backup reviewer slot (Gate-1 blocking before App Store submission) does
NOT need to also be a DPO; s11 requires one named individual, not two.
The same founder serves both roles at SG launch.

## Decision logging and retention

Every appeal decision is logged. The log is the PDPA s25 evidence trail, the
abuse-pattern detection signal, and the reviewer-quality audit artefact.

### Schema

Each row captures:

- `appealId` — opaque identifier (UUID).
- `appellantUserId` — the user appealing.
- `originalFailureCategory` — one of `poorLighting` / `faceNotVisible` /
  `qualityTooLow` / `other` (per TRI-70 closed enum).
- `reviewerNotes` — free-text reviewer-side reasoning. No selfie image
  reproduced; no third-party PII unless intrinsic to the appeal.
- `decision` — one of `approve` / `deny` / `request-more-info` /
  `correction-applied` (the last reserved for s22 right-to-correction outcomes).
- `decisionTimestamp` — ISO-8601 with SGT offset.
- `decisionMaker` — reviewer identity (founder, or named backup once filled).
- `s22Flag` — boolean. `true` when the appeal was handled as a PDPA s22
  correction request (see Escalation Path (b) below). `false` for standard
  appeals.

### Retention window

| Log type                          | Retention                                                          | Trigger to delete                          |
| --------------------------------- | ------------------------------------------------------------------ | ------------------------------------------ |
| Appeal decision log (per row)     | Lifetime-of-account OR until account-deletion, whichever is first  | Account-deletion cascade                   |
| s22 correction request (per row)  | Lifetime-of-account OR until account-deletion, whichever is first  | Account-deletion cascade                   |

**Why lifetime-of-account.** The appeal record's purposes — reviewer-quality
audit, abuse-pattern detection across multiple appeal cycles per user, and
defensibility of any future account action that touches verification state —
persist for the lifetime of the account. The rows contain operational metadata
only (no selfie image; the image is governed by `docs/policies/selfie-retention.md`
§7 / §8A — uniform 30-day window with a 24-month deletion-event audit). This
mirrors the §7A.3 precedent already cleared for `selfieAttemptCount` /
`selfieLastFailureCategory`. PDPA s25 is satisfied because retention is
purpose-anchored and ceases on account deletion.

**Image-deletion independence.** A selfie image referenced by an appeal may be
deleted by the routine 30-day sweep before the appeal log row is deleted. This
is expected. The appeal log entry survives image deletion as plain operational
metadata; the deletion-event audit row in `selfie_deletion_events` provides the
evidentiary chain that the image existed and was destroyed per policy.

**Apple 5.1.1(v) account-deletion cascade.** On account deletion:

- Appeal log rows authored BY the deleting user → delete entirely.
- Appeal log rows in which the deleting user is the appellant (the only
  case at SG launch) → delete entirely.

There is no pseudonymise-and-retain branch for the appeals log; the appellant
is the only user identifier on each row.

### Storage

- **Location:** founder-named access-controlled store. At SG launch:
  Notion private database with named-user ACL, or a restricted-share
  Google Sheet with 2FA on the founder account. The store is named and
  linked from this runbook's `Reviewer assignment` section.
- **PDPA s24 (Protection):** the store must be private to the named
  reviewer(s). Unindexed-share-link, public-Notion-page, and open-channel
  patterns are forbidden.
- **Access logging:** the store's native access log is enabled (Notion
  member activity, Google Workspace audit log) and retained for 12 months.

## Escalation paths

All internal escalation paths collapse to the founder for SG launch. External
escalations are noted per path below.

### (a) Discrimination or identity-based wrongful-rejection claim

**Trigger.** The appellant asserts that the rejection was discriminatory —
based on ethnicity, skin tone, national origin, or another protected
characteristic. Common phrasings: "my selfie was rejected because of my skin
colour," "the system doesn't work for people who look like me," "this is
discriminatory."

**Internal escalation.** Escalate to founder. The reviewer does not
make any admission or denial on behalf of Tribely; the acknowledgement
reply confirms receipt only.

**External escalation.** None at SG launch. If the appellant references
a complaint to a regulatory body (PDPC, MCCY), escalate to founder
immediately for external-counsel routing.

**Reviewer first-action checklist.**

1. Reply within 1 SG business day — acknowledge receipt; do not make
   any admission or statement on the merits.
2. Escalate to founder by direct contact.
3. Log row with `decision = request-more-info` (pending founder review)
   and a discrimination-claim note in `reviewerNotes`.
4. Founder determines substantive response and outcome; update log row
   when decision lands.
5. If regulatory body is named, add external-counsel flag to log row.

### (b) PDPA s22 right-to-correction

**Trigger language.** The appellant's email asserts that a record Tribely
holds about them is factually wrong and asks that it be corrected. Examples:

- "You have my name as 'Jon' but my IC reads 'John'."
- "Your reviewer logged my failure as 'poor lighting' but my face WAS
  visible — please correct the record."
- "The account verification decision is wrong; please correct it."
- "Please update my DOB on the verification record from YYYY-MM-DD to
  YYYY-MM-DD."

If the appellant frames their request in factual-correction terms — even if
they do not cite PDPA s22 explicitly — handle as an s22 request. When in
doubt, ask the appellant: *"To confirm — are you asking us to correct a
factual record we hold about you (PDPA s22), or to re-review the
verification decision itself? The two paths differ."*

**What this is not.** A request to re-litigate the reviewer's
*judgement* (e.g., "I think you should have approved my selfie") is a
standard appeal, not an s22 correction request. s22 covers correction of
*facts*; appeals cover review of *judgement*. The distinguishing question is
whether the appellant is asserting a fact Tribely recorded is wrong, or
asking Tribely to re-weigh the same facts.

**Statutory window.** PDPA s22 obliges Tribely to correct the personal data
**"as soon as practicable."** PDPC advisory guidance treats this as ≤30
calendar days in normal course. If Tribely cannot meet 30 days, Tribely
**must** notify the appellant in writing of the timeline.

**Reviewer capture at intake.** The reviewer logs the request as an appeals
row with `s22Flag = true` and additionally captures:

- The specific field(s) the appellant is asking to correct.
- The appellant's evidence supporting the assertion (typically an
  attachment or excerpt).
- The intake timestamp — this starts the 30-day clock.
- Whether the request is for a factual correction (s22 path) or a
  re-review of judgement (standard appeals path). If unclear, the
  reviewer's first action is the clarification email above.

**Handling.**

1. **Acknowledge within 1 SG business day** (reuses the standard appeals
   acknowledgment SLA).
2. **Decide within 30 calendar days** of intake. Three possible outcomes:
   - `correction-applied` — Tribely makes the correction. Document what
     was changed, by whom, and when. Reply to the appellant confirming.
   - `correction-declined` — Tribely is satisfied on reasonable grounds
     that the correction should not be made (PDPA s22(7) safe-harbour).
     Document the specific reasonable ground. Reply to the appellant
     stating the decision AND noting that the appellant may complain to
     the PDPC if they disagree.
   - `partial-correction` — Tribely corrects some but not all of the
     requested fields. Document the same way as above for each field.
3. If the 30-day window cannot be met, send the appellant a written
   timeline notice **before** the 30-day mark elapses. This is a hard
   statutory requirement, not a courtesy.

**Downstream-notification obligation (PDPA s22(6)).** If the corrected
record has been disclosed to a third party within the year preceding the
correction, Tribely must send the corrected data to that third party. At SG
launch, Tribely does not disclose verification-decision data to third
parties — sub-processors (Resend, Twilio, S3 ap-southeast-1, Neon) are
processors-not-controllers and are likely defensibly outside the disclosure
scope. **External counsel sign-off required pre-launch** to confirm this
posture; until then, default to no-downstream-disclosure and document the
analysis if a correction request occurs.

**Who handles.** Founder (Data Protection Officer per PDPA s11). Backup
slot per the runbook header. The DPO designation under PDPA s11 is
independent of the appeals-reviewer rotation and is named publicly at
`privacy@gotribely.com`. s22 requests may also arrive at `privacy@`; the
two channels are operationally distinct, and an s22 request arriving at
`support@` is rerouted-by-reviewer (or cross-handled) but does not change
the substantive obligation.

**Documentation shape (PDPA s25 + audit trail).**

- The appeals log row with `s22Flag = true` and `decision` field set per
  outcome above.
- The reviewer's working notes capturing: the specific assertion, the
  evidence considered, the legal-basis analysis, the outcome rationale,
  and (if `correction-declined`) the specific s22(7) safe-harbour ground.
- Retention: lifetime-of-account, deleted on account-deletion cascade.
  s22 rows are not retained beyond standard appeals retention.

### (c) Appeal volume exceeds reviewer capacity for the day

**Trigger.** The volume of open appeals on a given business day exceeds
what the primary reviewer can process within the 3-SG-business-day
decision SLA for all open items.

**Internal escalation.** Primary reviewer escalates to founder, who
activates the backup reviewer for the overflow set. Until the backup slot
is filled (Gate-1), the founder absorbs overflow directly; no external
path exists at SG launch.

**External escalation.** None.

**Reviewer first-action checklist.**

1. Triage open queue — identify which appeals are at or approaching the
   3-business-day decision deadline.
2. Flag deadline-at-risk appeals to founder by direct contact.
3. Founder determines capacity allocation (defer lower-risk items,
   activate backup reviewer when slot is filled).
4. Send interim acknowledgement to any appellant whose decision will
   miss the stated SLA, noting the revised timeline. This is a courtesy
   obligation, not a statutory one (the statutory 30-day clock applies
   only to s22 requests).
5. Log each interim notice in the corresponding row's `reviewerNotes`.

### (d) Suspected coordinated abuse

**Trigger.** The reviewer identifies a pattern suggesting coordinated
abuse of the appeals channel — multiple appeals in a short window from
accounts with similar characteristics, identical or templated appeal text
across different user IDs, or appeal submissions that appear designed to
exhaust reviewer capacity or probe system behaviour.

**Internal escalation.** Escalate to founder immediately by direct
contact. Do not acknowledge or action any appeal in the suspected
coordinated set until the founder has reviewed.

**External escalation.** None at SG launch. Founder determines whether
the pattern warrants SPF referral (e.g., if the abuse involves identity
fraud); if so, route per the SPF disclosure protocol in
`docs/legal/law-enforcement-internal.md`.

**Reviewer first-action checklist.**

1. Flag the suspected pattern in `reviewerNotes` on each affected row —
   include cross-references (e.g., "same template as appealId X").
2. Escalate to founder by direct contact before any decision is issued.
3. Founder decides whether to: (i) process each appeal on the merits
   individually, (ii) deny as abuse-pattern, or (iii) hold pending SPF
   referral.
4. Update each row's `decision` and `reviewerNotes` when outcome lands.

## Test intake

Before TRI-70 ships, a synthetic test email is sent to
`support@gotribely.com` simulating a standard verification appeal. The
expected outcome is: the reviewer acknowledges within 1 SG business day and
reaches a logged decision within 3 SG business days. This end-to-end test
validates email routing to the intake channel, reviewer assignment, log-row
creation in the access-controlled store, and SOP compliance. No production
user data is used in the test.

## Compliance posture

PDPA s25 retention is cleared: appeal log rows are retained
lifetime-of-account (purpose-anchored to reviewer-quality audit, abuse
detection, and account-action defensibility) and are deleted on
account-deletion cascade — no indefinite tail. PDPA s24 access-controlled
storage is required: the log store must be private to the named reviewer(s)
with access logging enabled. PDPA s11 DPO is named: Frans Siswanto
(founder), publicly reachable at `privacy@gotribely.com`. PDPA s22
30-day decision window is encoded in escalation path (b), with the
s22(7) safe-harbour ground documented per decision and the 30-day
timeline-notice obligation as a hard requirement. Apple 5.1.1(v)
account-deletion cascade is encoded: appeals log rows where the deleting
user is the appellant are deleted entirely (no pseudonymise-and-retain
branch). External-counsel triggers — PDPA s22(6) downstream-disclosure
posture and the first borderline discrimination complaint — are bundled
into the TRI-69 / counsel queue and are not launch-blocking.

## References

- Consumer ticket: TRI-70
- Operational owner ticket: TRI-127
- CEO sign-off: 2026-05-30 (recorded on TRI-127)
- Related: TRI-69 (selfie retention), TRI-77 (storage runbook precedent),
  `docs/policies/selfie-retention.md`
