> **About this runbook.** This document describes Tribely's operational moderation process: how user-submitted reports are received, triaged, resolved, escalated, and audited. The **process itself** — the response SLAs, the escalation path, the evidence-preservation rules, the audit discipline — is the operational commitment Tribely makes to its users, to the App Store and Google Play, and to the Singapore Personal Data Protection Commission. It is in force at launch and is not provisional.
>
> The **interface** used to operate the process is currently a command-line script at `apps/api/scripts/moderation.ts`, intended for the solo-operator stage of Tribely's launch. The interface will be replaced under a planned upgrade (tracked internally as TRI-159) with an HTTP-based operator tool that exposes the same audit-logged actions over an authenticated API. The replacement is a **tooling iteration**, not a process change: the SLAs, escalation categories, evidence rules, and audit guarantees described below carry over verbatim. This runbook will be updated to reference the new interface at the moment of cutover; the policy content will not.
>
> An operator reading this runbook today should follow it as authoritative. A reviewer (App Store, Google Play, PDPC, external counsel) reading this runbook should understand it as describing the current operational state, with the interface evolution flagged transparently rather than concealed.

# Moderation CLI Operator Runbook

## 1. Scope

This runbook governs operator handling of user-filed content moderation reports for Tribely's Singapore launch, via the in-process CLI at `apps/api/scripts/moderation.ts`. The CLI is a stop-gap tool — it is retired in the same PR as TRI-159, which replaces it with HTTP-based admin endpoints (TRI-156 admin auth + TRI-157 admin endpoints). The process described here (SLAs, escalation categories, evidence rules, audit posture) carries over verbatim to the HTTP-based replacement; only the interface changes.

The contract for PII handling on resolved-hidden content is in `docs/policy/pii-cascade-contract.md`.

## 2. Response SLAs

Tribely commits to the following response times for user-submitted reports against reviews, users, and events. These are operational commitments — an operator opening this runbook is responsible for honouring them, and a missed SLA is treated as an internal incident requiring root-cause review.

**First-touch — within 72 hours of report submission.**
The operator must acknowledge the report by running the `ack` command, which records the acknowledgement (reviewer ID + timestamp) in the moderation action audit. Acknowledgement is **not** a determination on the merits of the report; it confirms the report has been received and entered the active queue.

**Resolution — within 7 days of report submission.**
The operator must resolve the report via either `resolve-hidden` (the offending content is hidden from public view) or `resolve-kept` (the report does not warrant action, with a recorded reason). The resolution timestamp is recorded in the moderation action audit.

**Clock start.** Both SLAs are measured from the timestamp the user tapped **Submit** in-app — recorded as `reportedAt` on the report row — **not** from the time the operator next opens the CLI. The CLI surfaces reports approaching the 72h or 7d boundary in its startup banner so the operator can prioritise accordingly.

**SLA exclusions.**
- Reports that escalate out-of-band (to the Singapore Police Force, to external counsel, to a regulator, or to a partner reporting channel) **stop the resolution clock** at the moment of escalation. The operator records the escalation in the audit log; resolution resumes when external input is received or the operator determines no further external input is required.
- Reports classified as **Egregious Content** (CSAM, terrorism, content promoting suicide or self-harm with imminent risk indicators) are handled on a **same-business-day** posture via the [Escalation Path](#4-escalation-path), not the general queue. The 72h/7d SLAs do not apply — they are minimums for the general queue, not ceilings for harm response.

**What "honoured" means.** The SLA is honoured when the corresponding audit row exists within the time window. The SLA is breached when no audit row exists. Breach is an internal operational matter — it does not, by itself, constitute a Personal Data Protection Act incident or a store-policy violation. Operators encountering a breach should record root cause in the post-incident log and adjust capacity or escalate to a second operator if recurrent.

## 3. CLI Invocation

All sub-commands are invoked via:

```
npm run --workspace=@tribely/api moderation <sub-command> [flags]
```

**Operator identity.** Every state-changing command requires an operator user ID. Supply it via:
- `--operator <userId>` flag on any command, or
- `$TRIBELY_OPERATOR_USER_ID` environment variable, set once per shell session:
  ```
  export TRIBELY_OPERATOR_USER_ID=usr_abc123
  ```

The CLI prints `Acting as <userId>` before every state-changing command. **Sanity-check this line on every invocation** before proceeding.

---

### `list-reports`

Lists unresolved moderation reports ordered by SLA urgency.

**Invocation:**
```
npm run --workspace=@tribely/api moderation list-reports [--state <open|under_review|escalated>]
```

**Optional flags:**
- `--state <open|under_review|escalated>` — filter by state. Defaults to all unresolved reports.
  - `open` — filed but not yet touched (`firstReviewedAt IS NULL`, not escalated).
  - `under_review` — touched at least once (`firstReviewedAt IS NOT NULL`, not escalated).
  - `escalated` — escalated and not yet resolved (`escalatedAt IS NOT NULL AND resolvedAt IS NULL`).

**Startup SLA banner.** The command prints a banner before the report table when breaches or approaching deadlines are present:

```
[!] 2 reports approaching 72h breach
[BREACH] 1 report past 7d hard ceiling
```

- `[!]` — one or more reports are within 24 hours of the 72h first-touch deadline.
- `[BREACH]` — one or more reports have exceeded the 7d resolution ceiling.

Escalated reports are excluded from banner counts — the SLA clock is paused at the moment of escalation.

**SLA Flag column.** Each row in the report table includes a `SLA Flag` column:

| Value | Meaning |
|---|---|
| `OK` | Both the 72h and 7d clocks have headroom. No immediate action required. |
| `APPROACHING-72H` | The 72h first-touch deadline is within 24 hours. Acknowledge via `touch`. |
| `OVERDUE-72H` | The 72h first-touch deadline has passed without a `touch` record. |
| `APPROACHING-7D` | The 7d resolution deadline is within 24 hours. Resolve via `resolve --hide` or `resolve --keep`. |
| `BREACH-7D` | The 7d resolution deadline has passed without a resolution record. Internal incident; record root cause. |
| `PAUSED-AT-ESC` | Report is escalated and unresolved. SLA clock is paused. No resolution action until escalation is handled. |

**State column.** Each row also includes a `State` column: `open`, `under_review`, or `escalated`.

**On success:** Tabular output with columns `ID`, `Reporter`, `Target`, `Reason`, `Created`, `Age`, `SLA Flag`, `State`, `First-Reviewed`.

**On failure (no matching reports):** `No unresolved reports matching --state <state>.` (with `--state`) or `No unresolved reports.` (without flag).

**Naming note:** The PM brief referred to this as `moderation list --state escalated`. The implemented command is `moderation list-reports --state escalated`. Use the implemented form.

---

### `touch`

Acknowledges a report (maps to the legal-prose `ack` vocabulary in §2). Records the operator ID and timestamp in the moderation action audit. Does not make a determination on the merits.

**Invocation:**
```
npm run --workspace=@tribely/api moderation touch <reportId> [--operator <userId>]
```

**Required:**
- `<reportId>` — the report ID from `list-reports` output.

**Optional:**
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID` for this invocation.

**On success:**
```
Acting as usr_abc123
Report rpt_xyz acknowledged. Audit row written.
```

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId from `list-reports`.
- `Report rpt_xyz is already acknowledged (or resolved).` — no-op; check if a prior operator acted.
- Any database error — cascade did not run; re-run after diagnosing.

---

### `resolve --hide`

Hides the reported content from public view and resolves the report. Maps to the legal-prose `resolve-hidden` vocabulary in §2. Captures an evidence snapshot atomically with the state transition (see §5). Requires a mandatory reason string.

**Invocation:**
```
npm run --workspace=@tribely/api moderation resolve <reportId> --hide --reason "<text>" \
  [--override-reason "<text>"] [--operator <userId>]
```

**Required:**
- `<reportId>` — the report ID from `list-reports` output.
- `--hide` — flag selecting the hide resolution path.
- `--reason "<text>"` — operator-supplied reason string; recorded verbatim in the audit row.

**Optional:**
- `--override-reason "<text>"` — when resolving an escalated report that has no `record_external_input` rows, supply a non-empty override reason. Only valid for `ambiguous-policy` and `external-jurisdiction` escalation categories. Supplying this flag on a non-escalated report, or on a `criminal-content` / `imminent-harm` escalated report, is an error. When used, the audit row action is `resolve_with_override` rather than `resolve_hidden`.
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID` for this invocation.

**On success:**
```
Acting as usr_abc123
Report rpt_xyz resolved (hidden).
```

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId.
- `--reason is required for resolve.` — supply a reason string.
- `Report rpt_xyz is already resolved.` — idempotent; check prior audit row.
- `Report is escalated. Resolve requires either a record-external-input row OR --override-reason.` (`reports.escalationResolveBlocked`, 409) — the report is escalated and has no external-input rows. Either record an external input first (`record-external-input`) or supply `--override-reason` (category permitting).
- `--override-reason only valid on escalated reports.` (`reports.overrideRequiresEscalation`, 400) — `--override-reason` was passed but the report is not escalated.
- `...Resolve requires a record-external-input row for criminal-content / imminent-harm.` (`reports.overrideForbiddenForCategory`, 400) — `--override-reason` was passed on a `criminal-content` or `imminent-harm` escalated report. These categories require an external-input row; override is not permitted.
- Any database error — state transition did not run; audit row was NOT written; re-run after diagnosing.

---

### `resolve --keep`

Resolves the report without hiding the reported content (the report does not warrant action). Maps to the legal-prose `resolve-kept` vocabulary in §2. Requires a mandatory reason string.

**Invocation:**
```
npm run --workspace=@tribely/api moderation resolve <reportId> --keep --reason "<text>" \
  [--override-reason "<text>"] [--operator <userId>]
```

**Required:**
- `<reportId>` — the report ID from `list-reports` output.
- `--keep` — flag selecting the keep resolution path.
- `--reason "<text>"` — operator-supplied reason string; recorded verbatim in the audit row.

**Optional:**
- `--override-reason "<text>"` — same semantics as `resolve --hide --override-reason`. See that section for the category-restriction rules.
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID` for this invocation.

**On success:**
```
Acting as usr_abc123
Report rpt_xyz resolved (kept).
```

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId.
- `--reason is required for resolve.` — supply a reason string.
- `Report rpt_xyz is already resolved.` — idempotent; check prior audit row.
- Escalation-guard failures apply identically to `resolve --hide`. See that section.
- Any database error — state transition did not run; audit row was NOT written; re-run after diagnosing.

---

### `cancel-event-for-safety`

Cancels a scheduled Event for safety reasons and notifies all active RSVPed users. The ONLY moderation action that cascades into Event lifecycle. Maps to Category 4 (Imminent real-world harm) in the Escalation Path.

**Invocation:**
```
npm run --workspace=@tribely/api moderation cancel-event-for-safety <eventId> \
  --reason=safety \
  --justification "<text>" \
  [--report-id <reportId>] \
  [--operator <userId>]
```

**Required:**
- `<eventId>` — the event ID being cancelled.
- `--reason=safety` — moderation reason code; the ONLY value accepted (distinct from host-initiated cancellation).
- `--justification "<text>"` — operator-supplied narrative explaining the cancellation, ≤500 chars. Recorded in the audit row. **Do NOT paste user content verbatim into justification** — paraphrase or reference. **Do NOT include the reporter's identity in the justification** — keep it operator-fact-only.

**Optional:**
- `--report-id <reportId>` — originating report ID (Cat 4 cross-reference). Omit if no upstream report exists (e.g., out-of-band intelligence).
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID`.

**On success:**
```
Acting as usr_abc123
Event evt_xyz cancelled for safety.
Audit row: mac_abc
Notified attendees: 4
```

**On failure:**
- `Event evt_xyz not found.`
- `Event already cancelled.`
- `Event already completed.`
- `Event has ended.`
- `Missing --justification.`
- `Missing or invalid --reason: only --reason=safety is supported.`
- Any database error — state transition did not run; re-run after diagnosing.

**Behavioural contract:**
- Reuses the same cancellation pathway as host-initiated cancellation; downstream notification, calendar surfaces, and join-request invalidation behave identically.
- Notifications use the host-tone copy (TRI-194 may introduce a moderation-tone variant post-launch). Reporter identity, operator justification, and report ID are NEVER surfaced to attendees.
- The audit row carries the safety context (`reasonCode='safety'`, `justificationText`, `originatingReportId`); the Event aggregate's `cancellationReason` field carries the neutral string `"Cancelled by Tribely safety team"` — distinguishable from host reasons in the DB if needed for forensic analysis but not in user-visible copy.

---

### `escalate`

Records the escalation of a moderation report to an external authority (law enforcement, platform safety team, external counsel, or a partner channel). Atomically sets the report's escalation state and writes an audit row. The SLA clock is paused at the moment of escalation — the report will appear with `PAUSED-AT-ESC` in the `SLA Flag` column of `list-reports`.

**Invocation:**
```
npm run --workspace=@tribely/api moderation escalate <reportId> \
  --category <criminal-content|imminent-harm|ambiguous-policy|external-jurisdiction> \
  --external-ref "<text>" \
  [--note "<text>"] \
  [--operator <userId>]
```

**Required:**
- `<reportId>` — the report ID from `list-reports` output.
- `--category` — escalation category. One of:
  - `criminal-content` — credible threats, illegal activity, doxxing, extortion. Requires a `record_external_input` row before resolution; override is not permitted.
  - `imminent-harm` — scheduled meet-up with active safety risk. Requires a `record_external_input` row before resolution; override is not permitted.
  - `ambiguous-policy` — content that does not fit clearly into `criminal-content` or `imminent-harm` but requires external review. Permits `--override-reason` on resolve if no external-input row exists.
  - `external-jurisdiction` — out-of-jurisdiction reports routed to an external authority. Permits `--override-reason` on resolve.
- `--external-ref "<text>"` — operator-supplied external reference (SPF report number, IMDA ticket ID, counsel matter reference). Non-empty. Recorded in the audit row.

**Optional:**
- `--note "<text>"` — free-text operator note recorded in the audit row `reason` field.
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID` for this invocation.

**On success:**
```
Acting as usr_abc123
Report rpt_xyz escalated.
Category: criminal-content
External ref: SPF-2026-001
Audit row written. SLA paused at escalation.
```

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId.
- `External reference required.` (`reports.externalRefRequired`, 400) — `--external-ref` was empty or whitespace-only.
- `Report already escalated.` (`reports.reportAlreadyEscalated`, 409) — re-escalation is not permitted. Check the existing escalation via `show <reportId>`.
- `Report already resolved.` (`reports.reportAlreadyResolved`, 409) — cannot escalate a resolved report.
- Any database error — escalation did not run; audit row was NOT written; re-run after diagnosing.

---

### `record-external-input`

Records an external communication (counsel advice, partner response, regulator determination) against an escalated report as an append-only audit row. Does not change the report's resolution state. Multiple invocations on the same report are permitted — each produces a separate audit row.

**Invocation:**
```
npm run --workspace=@tribely/api moderation record-external-input <reportId> \
  --source <counsel|partner|imda|other> \
  --disposition "<text>" \
  --received-at <ISO8601> \
  [--operator <userId>]
```

**Required:**
- `<reportId>` — the report ID, which must already be escalated.
- `--source` — origin of the external input. One of: `counsel` / `partner` / `imda` / `other`.
- `--disposition "<text>"` — operator-supplied summary of the external communication. Non-empty.
- `--received-at <ISO8601>` — the date and time the external communication was received (not the CLI invocation time). Example: `2026-05-26T10:30:00Z`.

**Optional:**
- `--operator <userId>` — overrides `$TRIBELY_OPERATOR_USER_ID` for this invocation.

**On success:**
```
Acting as usr_abc123
External-input recorded for report rpt_xyz.
Source: counsel
Received-at: 2026-05-26T10:30:00.000Z
Audit row written.
```

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId.
- `Disposition required.` (`reports.dispositionRequired`, 400) — `--disposition` was empty or whitespace-only.
- `Report is not escalated; cannot record external input.` (`reports.notEscalated`, 409) — run `escalate` first.
- `Report already resolved.` (`reports.reportAlreadyResolved`, 409) — cannot record external input on a resolved report.
- Any database error — audit row was NOT written; re-run after diagnosing.

---

### `show`

Displays the full state of a single report: submission time, first-review time, escalation state, resolution state, SLA flag, and the count of recorded external inputs.

**Invocation:**
```
npm run --workspace=@tribely/api moderation show <reportId>
```

**Required:**
- `<reportId>` — the report ID.

**On success:** Key-value output including:
- `Report:` — report ID
- `Reporter:` — reporter user ID
- `Target:` — `<targetType>:<targetId>`
- `Reason:` — report reason
- `Submitted:` — submission timestamp and elapsed time since submission
- `First-reviewed:` — first-touch timestamp, or `-` if not yet touched
- `Escalated:` — escalation timestamp, or `-` if not escalated
- `Category:` — escalation category, or `-`
- `External ref:` — external reference, or `-`
- `External inputs:` — count of `record_external_input` audit rows against this report
- `Resolved:` — resolution timestamp, or `-`
- `Resolution:` — `hidden` / `kept`, or `-`
- `SLA:` — current SLA flag (see `list-reports` for values)

**On failure:**
- `Report rpt_xyz not found.` — verify the reportId.

---

## 4. Escalation Path

Escalation is now recorded via `moderation escalate`. The categories map to the `--category` flag values: Cat 1 (self-harm) → `ambiguous-policy`; Cat 2 (criminal) → `criminal-content`; Cat 3 (minor) → `criminal-content`; Cat 4 (imminent harm) → `imminent-harm`. The judgement guidance for each category — when to call SPF, when to engage counsel — remains operator policy and is unchanged.

**Law-enforcement disclosure requests are out of scope for this runbook.** When an SPF officer, court, or other authority requests user data — whether by request letter, CPC s20/s39 notice, or court-issued warrant — follow [`docs/legal/law-enforcement-internal.md`](../legal/law-enforcement-internal.md) instead. That protocol governs the disclosure-scope posture, SLA, counsel-trigger checklist, and authorised-extraction path. The moderation CLI is the sanctioned extraction surface for authorised disclosures; the legal protocol governs *when* and *what*.

A report is **ambiguous** when its category does not fit cleanly into the general `resolve-hidden` / `resolve-kept` flow. The categories below define the escalation responses for the highest-duty-of-care report types. When in doubt, escalate — over-escalation is recoverable; under-escalation is not.

The operator must **never** make legal determinations on the merits of escalated content. The operator's role at escalation is: preserve evidence, contain harm, and route to the right external party.

### Category 1 — Self-harm or suicidal ideation

**Recognition signals.** Statements of intent to self-harm; references to method, time, or place; explicit suicidal ideation; goodbye-pattern language; reports from concerned parties flagging the same.

**Immediate actions, in order:**
1. **Preserve-then-hide.** Run `hide` (which captures the snapshot — see [Evidence Preservation](#5-evidence-preservation)). The content is removed from public view but retained in the snapshot.
2. **Surface the in-app safety copy to the affected user via the support channel.** Send the verbatim copy: *"If you're in immediate danger, please call Samaritans of Singapore at 1767 or the Singapore Police at 999. We are not an emergency service."* Do not paraphrase. Do not promise follow-up Tribely will not deliver.
3. **Do not contact the reporter** with content-specific information. A neutral acknowledgement of receipt is acceptable.
4. **Record in audit log** with category tag `self_harm`. Do not run `resolve-*` until 24 hours have elapsed and no further escalation indicators emerge.

### Category 2 — Criminal content, violence, or threats

**Recognition signals.** Credible threats of violence against an identifiable person; depiction or solicitation of illegal activity (drugs, weapons trafficking, prostitution); doxxing; extortion.

**Immediate actions, in order:**
1. **Preserve only — do NOT hide yet.** Run the snapshot capture without the hide transition. Hiding content before law enforcement engagement can destroy chain-of-custody for evidence. The CLI provides a `preserve` action separate from `hide` for this purpose.
2. **Assess imminence.** If there is credible indication of imminent physical harm to an identified person, call the Singapore Police Force at **999**. For non-imminent matters, file via the SPF e-services portal at police.gov.sg.
3. **Engage external counsel** before responding to any SPF request that asks for user data, account history, or content disclosure. Do not respond directly to a Criminal Procedure Code request without counsel review — see [External Counsel Triggers](#external-counsel-triggers).
4. **Hide the content only after SPF engagement** (or, if no SPF engagement is warranted, after counsel sign-off). Record both the preserve action and the eventual hide action in the audit log with category tag `criminal`.

### Category 3 — Minor involved

**Recognition signals.** Any indication — explicit or contextual — that a person depicted in or referenced by the reported content is under 18. Includes self-reports by the minor, third-party reports, photo subjects who appear under 18, references to school year / grade, references to age.

**Immediate actions, in order:**
1. **IMMEDIATE hide.** Run `hide` without delay. Minor-protection duty overrides the preserve-first rule for criminal-category content.
2. **Preserve the snapshot.** The `hide` action automatically captures the snapshot; verify the audit row exists.
3. **Do NOT engage with reporter or reported.** Any direct contact risks revictimisation or evidence contamination.
4. **Escalate within 24 hours of recognition.** For minor-involved reports that are NOT CSAM, escalate to external counsel, who routes onward (SPF, IMDA). For reports the operator confirms as suspected CSAM (tagged `minor_csam_suspected`, step 5), follow [§4A — CSAM CyberTipline Submission](#4a-csam-cybertipline-submission), which governs the disclosure channel, submission steps, and SLA.
5. **For suspected Child Sexual Abuse Material (CSAM) specifically:** do NOT view the content further than necessary to confirm the category. Do NOT download. Do NOT distribute internally beyond the operator + named counsel. Record category tag `minor_csam_suspected` and treat the audit row as legally privileged.
6. **Do not run `resolve-*` until counsel confirms.**

### Category 4 — Imminent real-world harm (reported user has scheduled meet-up)

**Recognition signals.** The reported user is the host of, or has an approved join request to, an Event scheduled within the next 72 hours. The reported behaviour suggests safety risk to other attendees (threats, predatory pattern, history correlating with the current report).

**Immediate actions, in order:**
1. **Hide the reported content** via `hide`.
2. **Cancel the scheduled Event.** Use the event-cancellation action surfaced in the CLI: `cancel-event-for-safety <eventId> --reason=safety --justification "..." [--report-id=...]`. This is the only escalation category where the moderation flow cascades into Event lifecycle.
3. **Notify all RSVPed users.** The `cancel-event-for-safety` command fans out the cancellation notification automatically. The notification copy is: *"This event has been cancelled. We're sorry for the inconvenience."* Do not name the reported user. Do not provide details that would identify the reporter. *The notification copy is identical for host-initiated and moderator-initiated cancellations at launch. This is a deliberate non-inference guarantee (legal review). Post-launch TRI-194 may introduce a safety-tone variant.*
4. **Cat 4 ∩ Cat 2 sequencing:** If the report is criminal-grade (credible threats, weapons trafficking, etc.) AND falls under Cat 4, **call SPF 999 BEFORE running `cancel-event-for-safety`**. Evidence chain-of-custody requires SPF engagement first; cancelling the event removes the active venue and may complicate response. The notification fan-out itself does not constitute a "disclosure" under the [SPF First-Incident Protocol](spf-first-incident.md), but the sequencing of platform action versus law-enforcement notification does materially affect SPF's response capacity. When in doubt: SPF first, then cancel.
5. **If the meet-up window is under 6 hours away and credible physical threat is indicated,** call SPF at 999 and proceed under [Category 2](#category-2--criminal-content-violence-or-threats) in parallel.
6. **Record in audit log** with category tag `imminent_real_world_harm` and cross-reference the cancelled Event ID.

### 4A. CSAM CyberTipline Submission

This subsection extends [Category 3 — Minor involved](#category-3--minor-involved) for the specific case of suspected Child Sexual Abuse Material (CSAM). It resolves the formerly-pending CSAM reporting channel to the **NCMEC CyberTipline public webform**. The policy commitment behind this procedure is [`docs/policy/csam-reporting.md`](../policy/csam-reporting.md); this is the executable how.

This subsection **extends, never relaxes,** the Category 3 step 5 handling guardrail: do NOT view the content further than necessary to confirm the category; do NOT download it; do NOT distribute it internally beyond the operator + named counsel; treat the audit row as legally privileged.

#### 4A.1 Recognising a CSAM-categorised report

A report is on this path when BOTH hold:
- It is a Category 3 (Minor involved) report, AND
- The operator, on review limited to confirming the category, identifies it as suspected CSAM and records the audit tag **`minor_csam_suspected`** (per Category 3 step 5).

Minor-involved reports that are NOT CSAM stay on the standard Category 3 counsel-escalation path (§4 Category 3 steps 1–6) and do NOT trigger a CyberTipline submission.

#### 4A.2 Evidence preservation — BEFORE submission

Preserve evidence using the existing atomic hide-and-snapshot discipline in [§5 Evidence Preservation](#5-evidence-preservation). Do NOT introduce any parallel evidence path.

1. **IMMEDIATE hide** via `resolve --hide` is the Category 3 step 1 rule — minor-protection duty overrides preserve-first. The `hide` transition captures the snapshot atomically (§5 "What is captured"); if the audit write fails, the hide rolls back. There is no hidden-but-unaudited state by construction.
2. **Verify the snapshot audit row exists** before proceeding (`show <reportId>` — confirm the action audit row is present).
3. The snapshot is the operator's evidence reference for the submission. The operator does NOT separately download or copy the content.

#### 4A.3 Webform submission steps

Within **24 hours** of the operator identifying the content as suspected CSAM (see §4A.5 SLA), submit via the NCMEC CyberTipline public webform:

1. Open **https://report.cybertip.org/** in a browser.
2. Select the report type covering apparent child sexual abuse material / online enticement, as the form presents it.
3. Complete the form fields from the preserved snapshot and report row:
   - **Reporting entity:** Tribely (Tribely Operations, `privacy@gotribely.com`).
   - **Content description / identifier:** describe the content and supply the hosted URL/identifier from the snapshot where the form requests it. Do NOT download-and-reupload the content.
   - **Reporter context:** the reporting user's account identifier and their stated reason/category.
   - **Account identifiers:** the account identifier of the author of the reported content (and the reported user's account identifier if the report targets a user).
   - **Timestamps:** `reportedAt` (report submission), the operator identification time, and the submission time.
4. Submit the form and **record the NCMEC reference / CyberTipline report ID** returned by the form.

#### 4A.4 Post-submission steps

Reuse the existing escalate / record-external-input vocabulary — do NOT invent a parallel audit path.

1. **Record the escalation.** If the report is not already escalated, run:
   ```
   npm run --workspace=@tribely/api moderation escalate <reportId> \
     --category criminal-content \
     --external-ref "NCMEC-CyberTipline-<reportID>" \
     --note "Suspected CSAM forwarded to NCMEC CyberTipline webform."
   ```
   Category 3 maps to `criminal-content` (§4 mapping). The `criminal-content` category **requires** a `record_external_input` row before resolution and does NOT permit `--override-reason` — this is the correct guardrail for a CSAM matter.
2. **Record the NCMEC submission as external input** against the report's audit row:
   ```
   npm run --workspace=@tribely/api moderation record-external-input <reportId> \
     --source other \
     --disposition "Submitted to NCMEC CyberTipline; reference <NCMEC reportID>; awaiting onward routing." \
     --received-at <ISO8601 submission time>
   ```
   (`--source other` — NCMEC is neither `counsel`, `partner`, nor `imda`. Record the NCMEC reference verbatim in `--disposition`.)
3. **Hold / soft-block the offending account.** Apply the existing soft-block flow to the author of the reported content per standard moderation practice. Do NOT contact the reported or the reporter (Category 3 step 3).
4. **Do NOT run `resolve --*` until counsel confirms** (Category 3 step 6). The `criminal-content` escalation guard enforces this: resolution requires a `record_external_input` row and override is forbidden for this category.
5. **Escalate to named counsel when the incident shape warrants it** (see §4A.6) — e.g., an imminent-harm dimension, ambiguity over whether a direct SPF report is also required, or any contested-disclosure question. Record counsel input via a further `record-external-input --source counsel` row when received.

#### 4A.5 SLA

**Transmission to NCMEC within 24 hours of the operator identifying the content as suspected CSAM.** This is a **calendar-time** clock — it runs through weekends and Singapore public holidays. It is independent of the general 72h first-touch / 7d resolution SLAs (§2) and is independent of the `escalate` SLA pause: the SLA pause governs the *report's resolution clock*, not the CyberTipline transmission deadline. The transmission deadline is honoured when the §4A.4 step 2 `record_external_input` row (carrying the NCMEC reference) exists within 24 hours of operator identification.

#### 4A.6 Named Trust & Safety counsel fallback

A single pre-identified Singapore Trust & Safety counsel — named but **not retained**. Subject-matter fit: **CSAM / online child-safety reporting + Singapore online-safety and CYPA exposure**. Generic "data protection" practice is insufficient — the child-safety reporting posture is the specific fit being vetted.

The row is populated asynchronously by the owner / CEO. The placeholder token `<!-- OWNER TO FILL — counsel name pending owner sign-off; see PR -->` is the only placeholder format permitted here and is tolerated **only** in this §4A.6 entry (same convention as [`spf-first-incident.md` §3](spf-first-incident.md#3-counsel-shortlist)). Find-and-replace on that exact token to populate.

Stale entries (last-confirmed > 6 months) require re-confirmation before the operator treats the row as actionable.

| Field | Value |
|---|---|
| Firm (full registered name) | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Individual contact (full name) | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Role / title | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Email | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Direct phone | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Subject-matter fit summary (CSAM / child-safety reporting + SG online-safety / CYPA; one-line confirmation from the contact) | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |
| Last-confirmed date (YYYY-MM-DD) | <!-- OWNER TO FILL — counsel name pending owner sign-off; see PR --> |

**Engagement model.** Engagement is **per-incident, not retained.** The operator opens engagement only when a real CSAM incident warrants legal guidance (§4A.4 step 5), by emailing the contact with: (a) "Tribely CSAM incident — counsel engagement [date]", (b) the report ID and `minor_csam_suspected` audit reference (NOT the content itself), (c) the NCMEC reference already submitted, (d) the specific question (e.g., direct-SPF-report requirement). Counsel input is recorded back into the audit row via `record-external-input --source counsel`.

### When in genuine doubt

If a report fits two categories, apply the more protective rule. If a report fits no category but feels load-bearing, **acknowledge within 72h, do not resolve, and surface to the CEO** in the daily ops channel for a second pair of eyes. Under-escalation is the failure mode this runbook is designed to prevent.

---

**Operational note (EL TRI-141):** When facing a criminal-category report, DO NOT touch / resolve / hide via the CLI. Immediately escalate via the documented escalation channel above and preserve evidence by leaving the report in `open` state until founder + counsel direct otherwise.

## 5. Evidence Preservation

The moderation CLI captures evidence atomically with the state transition. This section documents **what** is captured, **where** it is stored, **how long** it is retained, and **what triggers purge**. The rules below reconcile the Personal Data Protection Act's data-minimisation obligation (Section 25 — retain only as long as necessary for the purpose) with the operational need to produce evidence on request from law enforcement, the App Store / Play reviewer probe, or external counsel.

### What is captured

When the operator runs `hide` or `preserve`, the system writes the following — atomically with the state transition, in the same database transaction — to the moderation evidence audit:

1. **Content snapshot.** The reported content as it appeared at the moment of report: full text, image URLs (if applicable), structural metadata (reviewId / userId / eventId, version, edit history if any).
2. **Reporter identity.** User ID of the reporter, the timestamp of report submission, and the reporter's stated reason / category.
3. **Reported identity.** User ID of the author of the reported content (and, where the report is against a user rather than content, the user ID of the reported user).
4. **Action metadata.** Operator (reviewer ID) running the command, command issued (`ack` / `hide` / `preserve` / `resolve-hidden` / `resolve-kept` / `escalate`), timestamp, and the operator-supplied reason string (mandatory for `resolve-*` and `escalate`).
5. **Escalation linkage.** If the report is escalated under the [Escalation Path](#4-escalation-path), the category tag and any external reference (SPF report number, counsel matter reference, partner channel ticket ID) are appended to the audit row.

The capture is **atomic** with the state transition: if the audit write fails, the state transition rolls back. This is enforced at the database layer — there is no operator action that can produce a hidden-but-unaudited report, by design. (Pattern reference: the same required-`TxContext` discipline used by selfie-deletion evidence integrity.)

For `cancel-event-for-safety` actions, the audit row additionally carries (a) `reasonCode='safety'` (distinguishes from host-cancel; future moderation reason codes are additive), (b) `justificationText` (≤500 chars; operator narrative; PDPA s24 minimisation gate enforced at write time), and (c) `originatingReportId` (nullable cross-reference to `moderation_reports`).

Three additional audit row variants are written by the escalation sub-commands:

- **`escalate` action.** Written atomically when `moderation escalate` is invoked. Per-variant fields: `escalationCategory` (e.g., `criminal-content`), `externalRef` (operator-supplied reference), `reason` (the `--note` value if provided). The audit row is written in the same UnitOfWork transaction as the `reports.escalatedAt` state transition.

- **`record_external_input` action.** Written atomically when `moderation record-external-input` is invoked. Per-variant fields: `externalSource` (`counsel` / `partner` / `imda` / `other`), `externalDisposition` (operator-supplied summary), `externalReceivedAt` (operator-supplied ISO8601 timestamp of when the external communication was received — distinct from `actedAt`, which is the CLI invocation time). `escalationCategory` is carried forward from the report at write time. This variant does NOT mutate the `reports` row; `externalInputCount` is derived by counting `record_external_input` rows for a given `reportId` at query time.

- **`resolve_with_override` action.** Written instead of `resolve_hidden` or `resolve_kept` when a resolution is performed with `--override-reason` on an eligible escalated report (`ambiguous-policy` or `external-jurisdiction` categories only). Per-variant fields: `reason` (the `--override-reason` value), `escalationCategory` (carried forward for traceability). This variant confirms that the operator took explicit responsibility for resolving an escalated report without external-input confirmation.

### Where it is stored

- **Primary store:** the project Postgres instance, in the `moderation_evidence_snapshots` and `moderation_action_audit` tables. **Region: Singapore (ap-southeast-1).** No cross-border transfer.
- **Backups:** project standard backup policy applies. Snapshots are NOT excluded from backup.
- **Access control:** Access to moderation evidence at this stage is via operational CLI + direct DB access only. Role-based gating, read-audit on evidence tables, and reviewer-scoped query interfaces land with the HTTP admin surface (TRI-156 admin auth + TRI-157 admin endpoints), at which point evidence access transitions to authenticated reviewer-role with full read-audit. Operators handling moderation evidence during this stop-gap window MUST treat all evidence reads as personally attributable and log out-of-band any read performed for non-action purposes (e.g., legal review, founder briefing).

### How long it is retained

| State | Retention window | Rationale |
|---|---|---|
| Report open (`pending` / `acknowledged` / `escalated`) | Retained while open, no cap | Active matter; no PDPA Section 25 trigger to purge yet |
| Report resolved (`resolve-hidden` / `resolve-kept`) | 12 months from resolution timestamp | Industry-standard short tail for civil-claim and reviewer-audit window |
| Egregious-content-tagged reports (`self_harm`, `criminal`, `minor_*`, `imminent_real_world_harm`) | 12 months from resolution **or counsel-directed longer**, whichever later | Higher-duty-of-care matters may require multi-year retention pending external proceedings |
| Hidden content (the underlying record marked `hiddenAt`) | 12 months from resolution, then physical delete on sweep | Content is not deleted at hide-time so the snapshot remains verifiable against the source |
| `moderation_action_audit.originatingReportId` cross-reference | Severed (NULL'd) when the referenced `moderation_reports` row is purged by the §5 sweep | PDPA s25 cross-reference minimisation — the audit row outlives the report row by design, but the cross-reference does not |

### When it is purged

Purge is performed by a **scheduled sweep job** against the 12-month boundary. There is no early-purge override on operator initiative. Specifically:

- A reporter requesting deletion of their report **does not** trigger early purge. The report is evidence of an action the reporter took on the platform; preserving it is a legitimate interest under PDPA Section 17 (1) and the related deemed-consent provisions for evidence retention.
- A reported user requesting account deletion (Apple Guideline 5.1.1(v) flow) **does not** delete the moderation evidence in which they are referenced. Direct identifiers (the reported user's display name, email) are pseudonymised on the evidence row; the underlying user-ID linkage is retained. (Mirror of the selfie-deletion + checkin-flagged-report pattern.)
- A reported user's request under PDPA Section 21 (Access Request) **does** entitle them to know that reports exist about them, but does **not** entitle them to the reporter's identity or the report contents — evidentiary integrity and reporter safety are documented exceptions under the Personal Data Protection (Access) Regulations.

The sweep is implemented as `SweepResolvedReportsJob`, boot-wired in `apps/api/src/index.ts`. It runs on the interval configured by `MODERATION_REPORT_SWEEP_INTERVAL_MS` (default 86400000 ms = 24h). For manual one-shot runs, use `npm run --workspace=@tribely/api moderation sweep-resolved-reports`. Sweep deletions are themselves audit-logged (one `sweep_runs` row per tick, with the row count and the cutoff timestamp).

### How to run the sweep manually

To trigger the report retention sweep outside its scheduled cadence (e.g., for an immediate post-incident purge or to confirm the sweep is operational):

```
npm run --workspace=@tribely/api moderation sweep-resolved-reports
```

The command requires no operator identity — it is a system action, not an operator action. The scheduled job already runs this sweep every 24h by default; manual invocation is for exceptional circumstances only.

### What is NOT captured

To stay within the data-minimisation bar of PDPA Section 18 (Purpose Limitation) and Section 25, the evidence audit does **not** capture:

- IP address or device identifier of the reporter or reported (these would expand the audit scope beyond the moderation purpose; if law enforcement requests these, they are sourced from `http_audit_logs` under a separate disclosure protocol).
- Free-text operator notes beyond the mandatory `reason` string on `resolve-*` and `escalate` actions. Operators who need to record investigative thinking use the separate ops journal, not the audit row.
- Any data about uninvolved third parties referenced incidentally in the reported content (these are subject to standard content-moderation handling but are not separately indexed).

## 6. Audit and PDPC Inspection Posture

All state-changing CLI commands write to the `moderation_action_audit` table atomically with the state transition — the same required-`TxContext` pattern used by `account_deletion_events` (see `docs/runbooks/account-deletion-sla.md` §4). There is no operator action that changes report state without a corresponding audit row; the database transaction enforces this guarantee by construction.

Channel attribution for PDPC inspection uses the AsyncLocalStorage request-context label. The moderation CLI wraps every command invocation in `runAsSystem('cli.moderation.<subcommand>', fn)`. The audit row's `requestId` field will contain a value matching `system:cli.moderation.*`; PDPC inspection queries can discriminate CLI-originated actions via `requestId LIKE 'system:cli.moderation:%'`. This is the same discriminator pattern as the privacy-mailbox operator path in `account-deletion-sla.md` §4 — `system:<label>:*` as the audit channel fingerprint.

The `moderation_action_audit` table is **append-only by contract** — no UPDATE or DELETE is issued by any application path. Rows are immutable once written. Purge of resolved-report rows at the 12-month boundary is performed by the scheduled sweep (§5), which itself writes an audit row recording the batch count and cutoff timestamp. If PDPC requests evidence that a specific report was handled: query `moderation_action_audit` by `reportId` to produce the full action history (touch → hide / keep → optional escalation linkage), ordered by `timestamp`. The `requestId` on each row confirms the operator channel; the `operatorUserId` column confirms the acting operator.

**DB-level enforcement of the append-only contract on `moderation_action_audit` is IN PLACE as of TRI-206.**

The runtime database role is `tribely_app`. Its grants are:

- **`moderation_action_audit`**: INSERT, SELECT, and UPDATE **only on column `originatingReportId`**. `UPDATE` is allowed **only** on column `originatingReportId` — this encodes the TRI-165 severance contract: the report-retention sweep (TRI-198) NULLs the FK so the originating `moderation_reports` row can be deleted >12 months later, while the audit row itself persists as legal-compliance evidence. `UPDATE` on any other column, `DELETE`, and `TRUNCATE` all fail with Postgres error `42501`.
- **All other tables in schema `public`**: SELECT, INSERT, UPDATE, DELETE (baseline for normal application operation).

The `tribely_app` role CANNOT UPDATE non-sanctioned columns, DELETE, or TRUNCATE rows in `moderation_action_audit`. Attempts return Postgres error code `42501` (insufficient_privilege).

The `tribely_app` role is NOT the owner of `moderation_action_audit`. Postgres table owners bypass REVOKE TRUNCATE, so the migration / superuser role retains ownership and the runtime role is grant-restricted. This is verified by an automated test (`moderation-action-audit.append-only.integration.test.ts`).

### Production SQL (copy-pasteable for human prod operator)

Execute as the database superuser via `psql`. Idempotent: safe to re-run.

```sql
-- 1. Create runtime role if missing (LOGIN, password from env).
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tribely_app') THEN
    EXECUTE format('CREATE ROLE tribely_app LOGIN PASSWORD %L', '<RUNTIME_DB_PASSWORD>');
  END IF;
END $$;

-- 2. Baseline grants for normal app operation across all current tables.
GRANT CONNECT ON DATABASE "<DATABASE_NAME>" TO tribely_app;
GRANT USAGE ON SCHEMA public TO tribely_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tribely_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tribely_app;

-- 3. Default privileges so future migrations don't silently break runtime.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tribely_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO tribely_app;

-- 4. TRI-206 lockdown: append-only enforcement on moderation_action_audit.
REVOKE UPDATE, DELETE, TRUNCATE ON moderation_action_audit FROM tribely_app;

-- TRI-165 severance exception: the report-retention sweep (TRI-198) MUST
-- NULL originatingReportId on audit rows when the originating moderation_reports
-- row is deleted >12 months later. The audit row itself persists as
-- legal-compliance evidence; only this single FK column may be cleared.
GRANT UPDATE ("originatingReportId") ON moderation_action_audit TO tribely_app;

-- 5. Verification block — fails the script if posture is wrong.
DO $$
BEGIN
  ASSERT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'INSERT')),
    'tribely_app must have INSERT on moderation_action_audit';
  ASSERT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'SELECT')),
    'tribely_app must have SELECT on moderation_action_audit';
  ASSERT NOT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'DELETE')),
    'tribely_app must NOT have DELETE on moderation_action_audit';
  -- Column-scoped UPDATE: originatingReportId is the ONLY column tribely_app may UPDATE.
  ASSERT (SELECT has_column_privilege('tribely_app', 'moderation_action_audit', 'originatingReportId', 'UPDATE')),
    'tribely_app must have column-scoped UPDATE on originatingReportId (TRI-165 severance)';
  ASSERT NOT (SELECT has_column_privilege('tribely_app', 'moderation_action_audit', 'action', 'UPDATE')),
    'tribely_app must NOT have UPDATE on column action (append-only except originatingReportId)';
END $$;
```

Replace `<RUNTIME_DB_PASSWORD>` with the password the application uses to connect, and `<DATABASE_NAME>` with the production database name.

The same SQL is automated for CI and local dev via `apps/api/scripts/bootstrap-runtime-role.sql` + `npm run --workspace=@tribely/api db:roles:bootstrap`. Production execution is manual via the SQL above, per the agents-draft / human-executes convention (precedent TRI-77).

## 7. Retirement

This CLI is retired in the same PR as TRI-159, which replaces it with HTTP-based admin commands (TRI-156 admin auth + TRI-157 admin endpoints). At the moment of that cutover, operators MUST switch to the HTTP-based interface — the CLI script will no longer be present in the repository. The process described in this runbook (SLAs, escalation categories, evidence rules, audit posture) carries over verbatim; the interface does not. This runbook will be rewritten by TRI-159 to reference the new HTTP-based interface; the policy content will not change.
