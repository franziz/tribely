# SPF First-Incident Runbook

**Status:** Active (MVP launch posture)
**Audience:** Internal — Tribely operations (CEO / Frans Siswanto), backup-contact slot, future counsel
**Owner:** CEO / Frans Siswanto
**Authoritative scope source:** [`docs/legal/law-enforcement-internal.md`](../legal/law-enforcement-internal.md) (TRI-167). This runbook dereferences the protocol document; it does NOT restate scope. Where this runbook and the protocol disagree, the protocol governs.
**Last reviewed:** 2026-05-25

This runbook is the operational playbook for the **first** real-world law-enforcement disclosure request Tribely receives. It is the page the operator opens at 09:00 on the day a request lands. It exists to convert the protocol document (which establishes WHAT Tribely's posture is) into an executable HOW (intake → counsel engagement → holding response → escalation decision) so the founder is not improvising under pressure.

---

## 1. How to use this runbook

When a disclosure request arrives at `privacy@gotribely.com` (or any other channel that the operator believes to be a properly-served LE request per [`law-enforcement-internal.md` §3](../legal/law-enforcement-internal.md#3-sla)):

1. Open this file. Do not respond to the requestor before completing §2.
2. Complete the **§2 intake form** in full. Print or duplicate this section per incident — one form per request.
3. Engage the **§3 counsel shortlist** primary contact. If unavailable within 4 hours, engage the backup. If both unavailable, send the §4 holding statement immediately and continue counsel outreach.
4. Send the **§4 holding statement** to the requestor only after the intake form is complete (or, in the both-counsel-unavailable case above, send immediately and complete intake in parallel).
5. Cross-check the request against **§5 escalation criteria**. If any criterion fires, this runbook hands off to deeper legal engagement — the operator's job ends at "request held, counsel engaged, holding statement sent." If no criterion fires, the operator may proceed with the ops-only intake-and-respond loop per [`law-enforcement-internal.md` §6](../legal/law-enforcement-internal.md#6-operational-execution).

---

## 2. Intake form

Complete every field. "Unknown" is a valid answer where the requestor has not stated; leave no field empty.

### 2.1 Requestor identity

| Field | Value |
|---|---|
| Date received (YYYY-MM-DD) | |
| Time received (HH:MM, SGT, 24h) | |
| Channel received on (email / hand-delivery / other) | |
| If email: from-address | |
| Requestor name (named officer) | |
| Requestor rank / title | |
| Requestor agency (e.g., Singapore Police Force, IMDA, MAS, IRAS, CPIB, foreign LE) | |
| Requestor warrant-card / badge number (if stated) | |
| Requestor contact phone (verification channel) | |
| Requestor contact email (verification channel) | |

### 2.2 Statutory basis asserted by requestor

Capture the legal authority the requestor cites. Use PDPA vocabulary verbatim where the requestor uses it; otherwise transcribe the asserted authority word-for-word.

| Field | Value |
|---|---|
| Statutory citation asserted (e.g., "PDPA s4(2)(b) + CPC s20 notice", "CPC s39 written order", "court warrant under [Act/section]", "MLAT request via AGC") | |
| Instrument type (request letter / CPC s20 notice / CPC s39 written order / court warrant / production order / other) | |
| If warrant or production order: issuing court | |
| If warrant or production order: instrument number | |
| If warrant or production order: validity period (from-to) | |
| Asserted PDPA exemption basis (s4(2)(b) cooperative-by-default / Second Schedule para 1(e) public-agency LE disclosure / Fourth Schedule / other / not asserted) | |
| Life-at-risk standard asserted? (yes/no) | |
| If yes: stated basis for life-at-risk (named/identifiable person, nature of threat) | |

### 2.3 Subject of the request

| Field | Value |
|---|---|
| Subject identification provided by requestor (Tribely account email / account ID / phone / display name / other) | |
| Subject identifier value (as provided) | |
| Time window of interest (from-to, YYYY-MM-DD) | |
| Investigation reference (case number, if stated) | |

### 2.4 Data classes sought (reconcile against `law-enforcement-internal.md` §2)

Tick every data class the request covers. The posture column is reproduced from [`law-enforcement-internal.md` §2](../legal/law-enforcement-internal.md#2-disclosure-scope-posture-table) — do not reinterpret here; if the protocol and this runbook disagree, the protocol governs.

| Sought? | Data class | Protocol posture |
|---|---|---|
| ☐ | Account identifier (`users.id`) | Release |
| ☐ | Email address (`users.email`) | Release |
| ☐ | Phone number (`users.phone`) | Release |
| ☐ | Account creation timestamp (`users.createdAt`) | Release |
| ☐ | Sign-in IP + timestamp (auth `http_audit_logs`; `refresh_tokens.lastUsedAt`) | Release |
| ☐ | Last-known device label (`refresh_tokens.deviceLabel`) | Release |
| ☐ | Profile fields — display name, bio, avatar, interests, languages, current city, traveler type | Resist |
| ☐ | Event content — title, description, venue address, venue coordinates, times, category, capacity | Resist |
| ☐ | Join-request content — decision reason, lifecycle metadata | Resist |
| ☐ | Review content — rating, comment, hidden state | Resist |
| ☐ | Report-flow metadata — reporter, target, reason, comment, resolution | Resist |
| ☐ | Moderation actions taken — operator action, target, snapshot, reason | Resist |
| ☐ | User-block relationships | Resist |
| ☐ | Post-event check-in records — status, flag body | Resist |
| ☐ | Selfie verification artefacts — image bytes, `selfieStatus`, selfie lifecycle | Warrant-required |
| ☐ | Password hash | Warrant-required |
| ☐ | OTP / verification code hashes (email verification, password reset, phone OTP) | Warrant-required |
| ☐ | Refresh-token hashes | Warrant-required |
| ☐ | Draft / unpublished event content | Warrant-required |
| ☐ | Account-deletion audit records | Warrant-required |
| ☐ | Selfie-deletion audit records | Warrant-required |
| ☐ | Other data class NOT listed above — describe: ______________________ | Out-of-table (treat as Trigger 2 per §5) |

### 2.5 Deadline and properly-served check

| Field | Value |
|---|---|
| Requestor-stated deadline (YYYY-MM-DD, HH:MM SGT) | |
| Hours from receipt to deadline | |
| Channel served on `privacy@gotribely.com` or hand-delivered to registered business address? (yes/no) | |
| Written in English? (yes/no) | |
| Named SPF officer + contactable verification channel present? (yes/no) | |
| **Properly-served per `law-enforcement-internal.md` §3?** (yes/no — if no, return for resubmission; SLA clock starts on resubmitted properly-served request) | |
| SLA clock start (YYYY-MM-DD, HH:MM SGT) | |
| SLA track (Routine 7-day / Urgent best-effort 24h, committed 48h) | |

### 2.6 Operator log

| Field | Value |
|---|---|
| Intake completed by | Tribely Operations, Frans Siswanto |
| Intake completion timestamp (YYYY-MM-DD, HH:MM SGT) | |
| Counsel engaged? (yes/no — record name + firm + timestamp under §3) | |
| Holding statement sent? (yes/no — record timestamp) | |
| Escalation criteria fired? (none / list criterion numbers from §5) | |

---

## 3. Counsel shortlist

Two pre-vetted Singapore counsel contacts — primary and backup. Subject-matter fit: **PDPA s4(2)(b) AND criminal/regulatory disclosure response**. Generic "data protection" practice is insufficient — the disclosure-response posture is the specific fit being vetted.

Both rows are populated asynchronously by TRI-187. The placeholder token `<!-- OWNER TO FILL — populated by TRI-187 -->` is the only placeholder format permitted in this runbook and is tolerated **only** in this §3 section. TRI-187's SWE drops in values by literal find-and-replace on that exact token.

Stale entries (last-confirmed > 6 months) require re-confirmation before the operator treats the row as actionable.

### 3.1 Primary counsel

| Field | Value |
|---|---|
| Firm (full registered name) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Individual contact (full name) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Role / title | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Email | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Direct phone | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Subject-matter fit summary (PDPA s4(2)(b) + criminal/regulatory disclosure response; one-line confirmation from the contact) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Indicative response time (e.g., "24-hour acknowledgement, 48-hour first substantive response") | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Preferred contact channel (email / phone — order of preference) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Last-confirmed date (YYYY-MM-DD) | <!-- OWNER TO FILL — populated by TRI-187 --> |

### 3.2 Backup counsel

| Field | Value |
|---|---|
| Firm (full registered name) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Individual contact (full name) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Role / title | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Email | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Direct phone | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Subject-matter fit summary (PDPA s4(2)(b) + criminal/regulatory disclosure response; one-line confirmation from the contact) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Indicative response time | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Preferred contact channel (email / phone — order of preference) | <!-- OWNER TO FILL — populated by TRI-187 --> |
| Last-confirmed date (YYYY-MM-DD) | <!-- OWNER TO FILL — populated by TRI-187 --> |

### 3.3 Engagement note

Engagement is per-incident, not retained. The operator opens the engagement by emailing the primary contact with: (a) "Tribely SPF disclosure-response engagement — incident [date received]", (b) the completed §2 intake form, (c) the request instrument as received, (d) the §5 escalation criteria status (which fired, or "none fired — confirming ops-only handling is appropriate"). Counsel confirms acceptance before the operator proceeds to release any data.

---

## 4. Holding statement

Paste the block below verbatim into the response channel (typically reply to the requestor's email at `privacy@gotribely.com`). The operator name is hard-coded — do not substitute. The SLA reference points at the protocol document's SLA section by anchor — do not substitute a hard-coded date or duration.

Send the holding statement **after** §2 intake is complete (or in parallel with intake if both counsel contacts are unavailable within the first 4 hours, per §1 step 3).

> Dear [requestor name / officer rank],
>
> Tribely acknowledges receipt of your disclosure request dated [date], received at `privacy@gotribely.com` on [date received] at [time received] (SGT).
>
> We are reviewing the request with external counsel. Tribely's response timelines for disclosure requests are published at [`docs/legal/law-enforcement-internal.md` §3](../legal/law-enforcement-internal.md#3-sla) (routine and urgent tracks). We will respond within the applicable track from the SLA clock start recorded against your request.
>
> Tribely's point of contact for this matter is:
>
> Tribely Operations, Frans Siswanto
> `privacy@gotribely.com`
>
> Please direct all follow-up correspondence on this matter to that address.
>
> Regards,
> Tribely Operations, Frans Siswanto

**What this statement commits to (deliberately narrow):**
- Acknowledgement of receipt with timestamp.
- That external counsel is engaged.
- That a response will land within the published SLA track (anchor-referenced, not hard-coded — the anchor is the single source of truth for whether the request is on the routine 7-day or urgent best-effort-24h / committed-48h track).
- A single named point of contact.

**What this statement does NOT commit to (deliberately):**
- Whether any data will be released.
- Whether any account exists matching the requestor's subject identification.
- Any interpretation of the requestor's statutory authority.
- Any specific data class falling on a specific side of the §2 posture table.

If the requestor presses for a substantive commitment before counsel has cleared the request, the operator's only further response is to repeat the holding statement and refer the requestor to the SLA anchor. Substantive responses are counsel-cleared, not operator-improvised.

---

## 5. Escalation criteria

Cross-check every request against all six criteria. If ANY criterion fires, this runbook hands off — the operator's job is "request held, counsel engaged, holding statement sent, escalation recorded in §2.6." The ops-only intake-and-respond loop is only safe when zero criteria fire.

### 5.1 Warrant served (vs. routine s4(2)(b) request)

The instrument bears a court seal — a warrant, production order, or other court-issued instrument — as distinct from a request letter, CPC s20 notice, or CPC s39 written order.

*Ops guidance:* Look for an issuing-court name, an instrument number, a judge's signature or court seal, and a validity period in §2.2. The "letter vs. warrant" distinction is the single most important pattern-match in this runbook — a warrant on a `Release`-posture class still escalates because warrant-scope validity is a counsel question, not an operator question. Action: hold all data including `Release` classes, engage primary counsel, send §4 holding statement.

### 5.2 Scope exceeds `law-enforcement-internal.md` §2 disclosure-scope table

The request asks for data classes not listed in [`law-enforcement-internal.md` §2](../legal/law-enforcement-internal.md#2-disclosure-scope-posture-table), OR asks for `Resist` / `Warrant-required` classes on a request-letter basis (no warrant).

*Ops guidance:* Look at §2.4. Any "Other data class NOT listed above" tick fires this criterion. Any `Resist` or `Warrant-required` tick combined with an instrument type other than "court warrant" or "production order" in §2.2 fires this criterion. Action: hold ALL data — including `Release` classes in the same request — engage primary counsel. Partial release on the `Release` classes while a scope mismatch is being adjudicated risks waiver arguments on the resisted classes (see protocol §5 Trigger 2 rationale).

### 5.3 Requestor jurisdiction is non-SPF (foreign LEA, IMDA, etc.)

The requestor is a foreign law-enforcement agency acting directly (not via MLAT routed through the Attorney-General's Chambers); OR a Singapore statutory authority other than SPF (IMDA, MAS, IRAS, CPIB, PDPC) asserting disclosure authority; OR a civil litigant; OR an unidentified requestor.

*Ops guidance:* §2.1 "Requestor agency" answers this. SPF-direct and MLAT-via-AGC are the standard channels; everything else is a counsel call. Note that non-SPF Singapore statutory authorities have their own disclosure regimes (e.g., IRAS under the Income Tax Act, MAS under the MAS Act) — the protocol's PDPA s4(2)(b) reasoning maps directly only for SPF and the public-agency LE pathway; other authorities require counsel verification of the specific statutory authority and posture. Action: engage primary counsel; for foreign LE, the holding statement should additionally note that MLAT via AGC is the appropriate channel (use protocol §5 Trigger 3 holding response if needed).

### 5.4 Request explicitly targets biometric / verification artefacts

The request, whether on letter or warrant, seeks selfie images, biometric-derived data (face-embedding vectors, liveness signals, any artefact derived from the selfie), or selfie-deletion audit records.

*Ops guidance:* §2.4 — any tick on "Selfie verification artefacts" or "Selfie-deletion audit records" fires this criterion. These are the protocol's heightened-sensitivity classes under PDPA Advisory Guidelines on Selected Topics ch. 8 (NRIC / biometric data). A facially valid warrant for "user data" generically does NOT authorise biometric release — counsel must confirm the warrant scope specifically names biometric/verification data. Action: engage primary counsel; do not release any selfie/biometric data without counsel sign-off, regardless of instrument type.

### 5.5 Deadline is < 24 hours from receipt

The requestor-stated deadline in §2.5 is less than 24 hours from the time-received in §2.1.

*Ops guidance:* A sub-24-hour deadline is either a life-at-risk urgent assertion (in which case §2.2 will show the life-at-risk standard asserted, and the urgent SLA track applies) or an inappropriate demand that does not respect Tribely's published SLA. Both cases require counsel engagement on the urgent track. The primary disclosure-authorizer (CEO / Frans Siswanto) is paged immediately. Action: engage primary counsel on the urgent track; if counsel unreachable within the urgent SLA window, the CEO may release `Release`-posture data classes only under the s4(2)(b) cooperative-by-default posture per protocol §5 Trigger 4 — `Resist` and `Warrant-required` classes remain held.

### 5.6 If uncertain, escalate (tiebreaker)

None of criteria 5.1–5.5 fires cleanly, but the operator is unsure whether ops-only handling is safe.

*Ops guidance:* This is the catch-all. Examples of legitimate uncertainty that fires this tiebreaker: the requestor's identity cannot be verified through the contact channel in §2.1; the data classes in §2.4 are ticked but the operator is unsure whether the schema field maps to a `Release` or `Resist` row in the protocol §2 table; the asserted statutory citation in §2.2 is one the operator does not recognise; the request is properly served and on a `Release`-only basis but something about the request feels off. Cost of escalating a routine request is low (counsel acknowledges, confirms ops-only handling is appropriate, operator proceeds with the protocol §6 extraction). Cost of mishandling a complex request is high (regulatory exposure under PDPA, evidentiary integrity risk, waiver risk on resisted classes). Action: engage primary counsel; default-to-escalate.

---

## 6. After this runbook

When the request has been resolved (data released per protocol §6, request withdrawn, or counsel-led correspondence has reached a conclusion), the operator records the resolution in the disclosure log per [`law-enforcement-internal.md` §6](../legal/law-enforcement-internal.md#6-operational-execution). The completed §2 intake form for this incident is retained alongside the disclosure log entry as the audit record of the operator's pre-counsel pattern-match.

This runbook is reviewed in lockstep with the protocol document — see [`law-enforcement-internal.md` §7](../legal/law-enforcement-internal.md#7-review-cadence) for review triggers. Any protocol §2 scope-table change requires §2.4 of this runbook to be updated in the same change.

---

## 7. External counsel disclaimer

This runbook is operational guidance from Tribely's internal compliance function. It is NOT a legal opinion. Statutory interpretation, warrant adjudication, and any contested-disclosure correspondence MUST be routed to external Singapore counsel via the §3 shortlist. Where this runbook's guidance conflicts with counsel advice on a specific request, counsel advice governs.
