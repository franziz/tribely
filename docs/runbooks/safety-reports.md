# Safety Reports SOP

> **Status:** Drafted under the agents-draft / human-executes convention
> (precedent: TRI-77 selfie-storage runbook). Agents authored this SOP;
> the founder names the reviewer rotation and signs off on response-time
> commitments against real ops capacity. CEO sign-off recorded 2026-05-30
> on TRI-127.
>
> **Source-of-truth:** this file. Linked from TRI-127 (operational owner)
> and from the consumer ticket (TRI-29 for safety).

## Channel

`safety@gotribely.com` is the safety-report intake channel. Users who
experience or witness unsafe conduct — physical danger, criminal conduct,
harassment, self-harm concerns, or repeat-host patterns — submit a report
by emailing this address or via the in-app safety-report submit flow
(TRI-29, modified by TRI-238). The channel is for safety reports about
Tribely events and hosts only; it is NOT a verification-appeals channel
(use `support@gotribely.com` for those), a general support channel, or an
emergency-response service. Tribely cannot dispatch help; `safety@` is a
non-emergency moderation intake.

## SLA

**First acknowledgement:** within SG business hours — Monday to Friday,
9am–9pm SGT, excluding Singapore public holidays. Reports received outside
these hours will be acknowledged on the next business-hours window.

**SG business hours table:**

| Day                   | Covered hours (SGT)   |
| --------------------- | --------------------- |
| Monday–Friday         | 09:00–21:00           |
| Saturday              | Not covered           |
| Sunday                | Not covered           |
| Singapore public holidays | Not covered       |

The authoritative public-holiday list is the Ministry of Manpower calendar
at <https://www.mom.gov.sg/employment-practices/public-holidays>.

**Weekend / public-holiday / after-hours coverage.** There is no monitored
`safety@` channel coverage outside SG business hours at SG launch. The
999 pre-submit disclaimer (§C.2 below, and enforced by TRI-238 as a hard
gate before the submit action becomes interactive) is the safety-net for
this gap: every submitter is instructed to call SPF 999 for immediate
danger before submitting the form. The disclaimer is per-submit, not
per-user, so the direction is surfaced on every submission attempt
regardless of session history. Do not represent `safety@` as a 24/7
channel.

## Reviewer assignment

**Primary reviewer:** Frans Siswanto (founder).

**Backup reviewer:** `[ Gate-1 placeholder — name before App Store submission ]`

**Log store:** `[ Founder-named at execute-time — Notion private DB or Google Sheet w/ 2FA ]`

The log store must be access-controlled to the named reviewer(s) only
(PDPA s24). Unindexed share-links, public Notion pages, and open-channel
patterns are forbidden. Free-text report bodies frequently contain
third-party PII the reporter has included; loose ACLs on the store
constitute a PDPA s24 breach. The store's native access log must be
enabled and retained for 12 months.

## Decision logging and retention

Every safety-report intake is logged. The log is the PDPA s25 evidence
trail, the repeat-host-pattern detection signal, the App Store 5.1.1 /
Play UGC moderation-narrative defensibility artefact, and the basis for
any downstream account action.

### Schema

Each row captures:

- `reportId` — opaque identifier (UUID).
- `reporterUserId` — the user submitting the report.
- `eventId` — the event the report relates to.
- `hostUserId` — the host of that event.
- `reportExcerpt` — the user's free-text report body. Stored as the user
  submitted it; no reviewer paraphrase replaces the original text.
- `reviewerNotes` — reviewer-side reasoning. No reproduction of third-party
  PII beyond what is intrinsic to the report.
- `actionTaken` — one of `no-action` / `warning-to-host` / `host-suspension`
  / `account-suspension` / `escalated-to-founder` / `escalated-to-spf` /
  `signposted-self-harm-helpline`.
- `decisionTimestamp` — ISO-8601 with SGT offset.
- `decisionMaker` — reviewer identity (founder, or named backup once filled).
- `state` — `open` / `resolved`.
- `resolvedAt` — ISO-8601 with SGT offset; null while open.
- `disclaimerAcknowledged` — boolean. `true` when the 999 pre-submit gate
  was acknowledged by the reporter before submission. Required `true` for
  any row received via the in-app submit flow (per TRI-238).

### Retention window

| State    | Retention                                | Trigger to delete                                |
| -------- | ---------------------------------------- | ------------------------------------------------ |
| Open     | Retained while open                      | Transition to `resolved` re-anchors the clock    |
| Resolved | 12 months from `resolvedAt`              | Monthly scheduled sweep + account-deletion cascade |

**Why 12 months for resolved reports.** Three concrete purposes anchor the
post-resolution tail under PDPA s25:

1. **Repeat-host pattern detection.** A host who appears across multiple
   `safety@` reports over months is the dominant abuse signal. A 12-month
   rolling window catches this signal; a shorter window does not.
2. **PDPC inquiry-response window.** PDPC enforcement matters that
   reference platform safety practice typically reference a 6–18 month
   lookback. 12 months sits inside that range.
3. **App Store 5.1.1 / Play UGC moderation-narrative defensibility.** If a
   downstream account-action (host suspension, account suspension) is
   challenged, Tribely must be able to show how the underlying report was
   handled. 12 months is a reasonable evidentiary tail for this purpose.

12 months is materially shorter than indefinite retention (which would
defeat s25's destroy-when-no-longer-needed principle) and longer than the
30-day selfie-image window (different data class, different purpose, different
horizon).

### Apple 5.1.1(v) account-deletion cascade

On account deletion, for each safety-report row that references the
deleting user:

- **Reports authored BY the deleting user (reporter):** delete entirely.
- **Reports ABOUT the deleting user (reporter named the deleting user as
  host, or the deleting user is the host of the named `eventId`):**
  pseudonymise the about-user direct identifier — replace `hostUserId`
  with an irreversible hash; retain the narrative + relational metadata
  for the remaining 12-month window. This preserves the Apple 5.1.1(v)
  user-right to deletion while preserving the safety evidentiary chain.

This mirrors the TRI-29 pseudonymise-and-retain rule for `flagged`
records on account deletion. The pseudonymisation must be irreversible —
no rainbow-table-recoverable mapping retained.

### Storage

- **Location:** founder-named access-controlled store. Permitted at SG
  launch: Notion private database with named-user ACL, or a
  restricted-share Google Sheet with 2FA on the founder account. The
  store is named and linked from this runbook's `Reviewer assignment`
  section.
- **PDPA s24 (Protection):** the store must be private to the named
  reviewer(s). Unindexed-share-link, public-Notion-page, and
  open-channel patterns are forbidden. Free-text report content
  frequently contains third-party PII the reporter has included; loose
  ACLs on the store are a PDPA s24 breach.
- **Access logging:** the store's native access log is enabled and
  retained for 12 months.
- **Cross-channel routing:** safety reports occasionally arrive at
  `support@` (user picks the wrong channel). Reviewer reroutes the row
  to the safety-reports store and replies to the user from `safety@`.
  The original `support@` thread is not retained beyond the routing
  decision.

## Escalation paths

All internal escalation paths collapse to the founder for SG launch (per
TRI-127 CEO 2026-05-30 parameter on AC #5). Externals are SPF 999, SPF
protocol per `docs/legal/law-enforcement-internal.md`, and SOS Singapore
1767. Each row below is a trigger condition, the internal escalation, the
external escalation, and the reviewer's first-action checklist.

### (a) Physical danger — in-progress or imminent

**Trigger.** The report names immediate physical danger or describes an
in-progress incident. Common phrasings: "right now," "happening now," "he
is here," "she's not safe."

**Internal escalation.** Immediate escalation to founder by direct
contact (phone call, not email queue). The 999 pre-submit disclaimer is a
hard gate per TRI-238; the reviewer verifies the disclaimer was surfaced
to the reporter pre-submit (`disclaimerAcknowledged = true`).

**External escalation.** Reporter directed to SPF 999 in the
acknowledgment reply. If the reporter's contact information indicates they
are not the immediate victim (e.g., bystander reporting), the reply
includes the 999 directive and asks the reporter to confirm if they have
already called.

**Reviewer first-action checklist.**

1. Verify `disclaimerAcknowledged = true`.
2. Reply to the reporter from `safety@gotribely.com` within the
   SG-business-hours SLA — copy includes the 999 directive verbatim.
3. Direct-contact the founder (phone, signal, not email queue).
4. Log row with `actionTaken = escalated-to-founder` (initial) and update
   `actionTaken` as the founder's outcome lands.

**Posture note.** Tribely does not contact SPF on the reporter's behalf as
a standard pathway. SPF 999 is the reporter's channel; Tribely's role is
to direct, not to intermediate. Founder may contact SPF directly per the
SPF disclosure protocol if Tribely-held information is necessary for an
SPF inquiry — see `docs/legal/law-enforcement-internal.md`.

### (b) Criminal conduct alleged

**Trigger.** The report alleges criminal conduct — assault, sexual
offence, theft, drug-related offence, harassment under POHA.

**Internal escalation.** Escalate to founder. Founder routes per the SPF
disclosure protocol — see `docs/legal/law-enforcement-internal.md`. Until
SPF serves a disclosure request, Tribely's posture on user-content
(report bodies, message content) is `Resist` per that protocol; routine
identifiers are `Release` under PDPA s4(2)(b).

**External escalation.** Reporter is signposted to SPF (non-emergency:
1800-255-0000; emergency: 999). Tribely does not file a police report on
the reporter's behalf — the reporter is the complainant and SPF requires
the complainant to lodge directly.

**Reviewer first-action checklist.**

1. Reply to the reporter — acknowledge receipt; signpost SPF
   (non-emergency 1800-255-0000 or 999 if immediate); confirm Tribely
   will hold the report pending the reporter's SPF lodgement; do not
   commit to any specific account-action timeline (the action depends on
   SPF outcome or independent Tribely review).
2. Escalate to founder.
3. Founder reviews against `docs/legal/law-enforcement-internal.md` and
   determines whether independent account-action (host suspension)
   is warranted on Tribely's own review, separate from SPF outcome.
4. Log row with `actionTaken = escalated-to-founder` and update as
   outcomes land.

**Mandatory-reporting note.** Singapore does not have a general
mandatory-reporting regime for adult-victim crime. CPC s424 imposes a
duty to inform police of certain serious offences on persons "aware" of
them; engagement is fact-specific. The safe posture at SG launch is:
escalate to founder, who decides whether Tribely's awareness rises to
the s424 threshold (with external counsel input for any borderline
case). Do not unilaterally disclose to SPF outside the disclosure
protocol absent a clear-cut s424 trigger.

### (c) Self-harm / vulnerable-person language

**Trigger.** The report invokes self-harm language ("I want to hurt
myself," "I don't want to be here anymore") or describes a vulnerable
person at risk (minor in an event the reporter alleges was 18+
only, person under apparent influence unable to consent, etc.).

**Internal escalation.** Escalate to founder. The reviewer does NOT
attempt to counsel, advise, or otherwise act as a mental-health
intermediary — see reply template at §C.4.

**External escalation.** Reporter (if the reporter is the at-risk
person) or the at-risk individual named in the report is signposted to
SOS Singapore 1767 — see reply template at §C.4. For imminent risk to
life, the 999 directive is included.

**Reviewer first-action checklist.**

1. Reply using the verbatim self-harm reply template at §C.4. Do not
   modify the template's substantive language.
2. Escalate to founder.
3. Log row with `actionTaken = signposted-self-harm-helpline`. If the
   report also names a host concern, `actionTaken` is the more-severe of
   the two; founder decides at escalation.

**Minor-victim carve-out.** If the report names a minor victim,
additional handling applies — see CYPA s14 and CSAM posture per
`docs/policies/csam-reporting.md`. The minor-victim path overlays this
self-harm path; both apply.

### (d) Repeat-host pattern

**Trigger.** The report names a host who has been the subject of one or
more prior reports in the safety-reports log. The reviewer is responsible
for cross-checking the log on every intake; the 12-month retention window
exists specifically to make this check meaningful.

**Internal escalation.** Escalate to founder. The escalation note
includes a summary of all prior rows naming the same host, with
`reportId` and `decisionTimestamp` references.

**External escalation.** None automatic. Founder determines whether the
pattern crosses into criminal-conduct or physical-danger territory; if
so, paths (a) or (b) apply instead.

**Reviewer first-action checklist.**

1. Cross-check the log for prior rows naming the same `hostUserId`.
2. If at least one prior row exists with a non-`no-action` outcome,
   classify as a repeat-host pattern and escalate.
3. Log row with `actionTaken = escalated-to-founder` and a pattern note
   in `reviewerNotes`.

## Disclaimer

This is the exact verbatim copy surfaced as a hard pre-submit gate on the
safety-report submit flow (TRI-29, modified by TRI-238). The disclaimer
must appear before the submit action becomes interactive on every submit
attempt — not a tooltip, not a footer, not a one-time onboarding nudge.
Acknowledgement state is per-submit, not per-user.

### Verbatim copy

> **If you or someone else is in immediate danger, call SPF 999 now.**
>
> Tribely is not an emergency service and cannot dispatch help. This form
> is for non-emergency safety reports about events and hosts. Reports are
> reviewed by a human during Singapore business hours (Monday to Friday,
> 9am–9pm SGT, excluding public holidays).
>
> If you are reporting an in-progress incident or someone in immediate
> physical danger, call 999. Do not rely on this form.
>
> [ I understand — continue ]   [ Call 999 ]

### Why this copy

- **First sentence (unhedged 999 directive)** — Apple Review Guideline 1.6
  (Physical Harm) requires verbatim, unhedged safety-disclaimer copy. No
  "we may," "we try to," or "approximately."
- **Second sentence (disclaim emergency-response-intermediary status)** —
  Tribely is not the emergency channel; reliance on this form for
  immediate danger is not the intended use. This is the framing that
  defends Tribely against any claim that the platform assumed a duty of
  emergency response.
- **Third sentence (honest SLA)** — names the SG business hours window in
  full. Sets the correct expectation; prevents formation of a false belief
  that the channel is 24/7 monitored.
- **Fourth sentence (re-direction)** — explicit instruction to call 999 in
  the immediate-danger case. This is the safety-net for the SG-business-hours
  SLA gap on weekends, nights, and public holidays (per CEO 2026-05-30
  parameter on TRI-127 AC #3).
- **Action buttons** — "Call 999" is a tel-link affordance; "I understand —
  continue" is the explicit acknowledgement that unlocks the submit
  action. Per-submit acknowledgement, not per-user.

### Reviewer-side verification

Per TRI-127 AC #5, the reviewer verifies on receipt of each safety-report
intake that the `disclaimerAcknowledged` field is `true`. A row with
`disclaimerAcknowledged = false` indicates a routing path that bypassed
the gate (e.g., direct email to `safety@gotribely.com` from outside the
app). The reviewer's first reply to such submissions includes the 999
directive inline.

## Reply templates

## Reply template — self-harm / vulnerable-person signposting

This template is verbatim. The substantive language must not be modified
by the reviewer; only the salutation, the reporter's first name (if
known), and the reviewer sign-off may be adjusted. Reply from
`safety@gotribely.com`.

### Verbatim template

> Hi [first name, or "there"],
>
> Thank you for reaching out. We've read your message and we want to make
> sure you have the right support.
>
> Tribely is not a counselling or crisis service, and we are not able to
> provide the help you need. There are people in Singapore who can — and
> who answer right now:
>
> - **If you or someone else is in immediate danger, call SPF 999.**
> - **For emotional support, SOS Singapore is available 24 hours at
>   1767 (calls) or 9151 1767 (CareText, WhatsApp).**
> - **If you'd prefer to talk to someone face-to-face, IMH's Mental
>   Health Helpline is 6389 2222 (24 hours).**
>
> We are not medical professionals and this isn't medical advice. We're
> sharing these numbers because the people on the other end are trained
> for exactly this and they want to hear from you.
>
> If your message also reported a concern about a Tribely event or host,
> we've logged that and our safety reviewer is looking at it during
> Singapore business hours (Monday to Friday, 9am–9pm SGT). If anything
> about that situation is urgent, please call 999 — don't wait on us.
>
> Take care.
>
> — [Reviewer first name], Tribely

### Why this template

- **"Not a counselling or crisis service"** — disclaim
  mental-health-intermediary status. Negligence-tail liability if Tribely
  presents itself as competent in this space; the disclaimer is the
  defensive posture.
- **999 + SOS 1767 + IMH 6389 2222** — three named, current, working
  Singapore channels. SOS 1767 is the CEO-named primary signpost. IMH is
  added because some users prefer face-to-face / clinical and SOS is
  peer-support; naming both does not weaken the signposting and serves the
  user better.
- **"Not medical professionals and this isn't medical advice"** —
  explicit disclaimer of medical-advice framing. Required.
- **"Don't wait on us"** — re-anchors the user to the right channel
  rather than the Tribely inbox. Mirrors the 999 disclaimer's framing.
- **Sign-off as named reviewer** — humanises the reply; reduces the risk
  the message reads as automated. Some users in self-harm crisis discount
  automated replies.

### Logging

The row's `actionTaken` is `signposted-self-harm-helpline`. The
`reviewerNotes` captures: the substance of what the reporter said (so
escalation can be triaged without re-reading the full thread), the time
of reply, and whether the reporter responded.

Do not retain detailed clinical-style notes on the reporter. The
log row is operational, not a counselling record.

## Test intake

Before TRI-29 ships, a synthetic test email is sent to
`safety@gotribely.com` simulating a standard non-emergency safety report.
The expected outcome is: the reviewer acknowledges within SG business
hours (same business-hours window as receipt). This end-to-end test
validates email routing to the intake channel, reviewer assignment,
log-row creation in the access-controlled store (including
`disclaimerAcknowledged` field handling for direct-email submissions),
and SOP compliance. No production user data is used in the test.

## Compliance posture

PDPA s25 retention is cleared: resolved safety-report rows are retained
for 12 months from `resolvedAt` (purpose-anchored to repeat-host
detection, PDPC inquiry-response, and App Store 5.1.1 moderation
defensibility) and are deleted on monthly sweep or account-deletion
cascade. PDPA s24 access-controlled storage is required: the log store
must be private to the named reviewer(s) with access logging enabled;
report bodies contain third-party PII. PDPA s11 DPO is named: Frans
Siswanto (founder), publicly reachable at `privacy@gotribely.com`.
PDPA s22 is not the primary statutory frame for safety reports, but the
30-day correction window and s22(7) safe-harbour ground are carried by
the verification-appeals SOP for any correction claim that routes through
`safety@`. Apple 5.1.1(v) account-deletion cascade is encoded:
reports authored by the deleting user are deleted entirely; reports about
the deleting user pseudonymise the `hostUserId` with an irreversible
hash, retaining the evidentiary chain for the 12-month window. App Store
Review Guideline 1.6 999 disclaimer verbatim copy is fixed in §C.2 above
as a hard pre-submit gate per TRI-238. SPF 999 / SPF disclosure protocol
per TRI-167 / SOS Singapore 1767 signposting are cleared and embedded in
escalation paths and reply template above. External-counsel triggers —
PDPA s25 12-month-tail defensibility, CPC s424 first borderline
mandatory-report case, and PDPA s22(6) downstream-disclosure posture —
are bundled into the TRI-69 / TRI-167 counsel queue and are not
launch-blocking.

## References

- Consumer ticket: TRI-29
- Operational owner ticket: TRI-127
- CEO sign-off: 2026-05-30 (recorded on TRI-127)
- Related: TRI-69 (selfie retention), TRI-77 (storage runbook precedent),
  TRI-167 (SPF protocol), TRI-238 (TRI-29 safety SLA cascade),
  `docs/policies/selfie-retention.md`,
  `docs/legal/law-enforcement-internal.md`,
  `docs/policies/csam-reporting.md`
