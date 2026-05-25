# Law Enforcement Disclosure Protocol — Internal

**Status:** Active (MVP launch posture)
**Audience:** Internal — Tribely operations, future counsel, regulators on inspection
**Owner:** CEO / Frans Siswanto
**Companion runbook:** [`docs/runbooks/moderation-cli.md`](../runbooks/moderation-cli.md) (operational data-extraction procedure)
**Last reviewed:** 2026-05-25

---

## 1. Purpose and scope

This protocol governs how Tribely responds to data-disclosure requests from law-enforcement authorities — primarily the Singapore Police Force (SPF) and other Singapore statutory authorities (IMDA, MAS, IRAS, CPIB) — concerning user data Tribely processes.

Tribely operates a Singapore-first social events platform; the data classes in scope are those persisted by `apps/api` (Postgres + S3-equivalent object storage). This protocol applies to disclosure requests for any of those data classes.

**Out of scope:**
- Civil-litigant subpoenas (different posture — see §5 trigger 3, escalate to counsel).
- Foreign law-enforcement requests (different posture — see §5 trigger 3, escalate to counsel).
- Mutual Legal Assistance Treaty (MLAT) requests routed via the Attorney-General's Chambers (treated as SPF-channelled; same posture as direct SPF request).
- Court orders in private litigation (escalate to counsel).
- Regulator notices outside disclosure (e.g., PDPC investigation under PDPA s50) — separate response posture.

**Legal basis for disclosure without consent:** PDPA s4(2)(b) (the Act does not impose the consent / notification / access / correction obligations in Parts III–VI when disclosure is required or authorised under any written law or by an order of a court) and PDPA Second Schedule paragraph 1(e) / Fourth Schedule (disclosure for law-enforcement purposes by a public agency). The interpretation memo accompanying TRI-167 sets out the per-row reasoning.

**Single-operator model accepted at MVP; revisit at headcount > 3.** The disclosure-authorizer role is currently a single human (see §4). At headcount 4+, a documented two-person rule for `Resist` / `Warrant-required` releases should be re-evaluated.

---

## 2. Disclosure-scope posture table

Three postures govern every data class:

- **`Release`** — disclosed to SPF on properly-served request (cooperative-by-default under PDPA s4(2)(b)). No warrant required.
- **`Resist`** — not disclosed on a request letter alone. Released only on (a) a court-issued warrant or production order, or (b) specific statutory compulsion naming the data class.
- **`Warrant-required`** — released only on a court-issued warrant or production order. Distinct from `Resist`: even where a statutory provision might be argued to compel disclosure, the operator treats these classes as warrant-only and escalates to counsel to verify the compulsion's specificity before release.

| Data class | Posture | Rationale |
|---|---|---|
| Account identifier (`users.id`, cuid2) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — opaque identifier carrying no content; necessary precondition for SPF to identify the account being investigated. |
| Email address (`users.email`) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine subscriber identifier; standard SPF disclosure under Criminal Procedure Code (CPC) s20 / s39 notice. |
| Phone number (`users.phone`, where verified) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine subscriber identifier on equal footing with email; sender-ID and OTP records (Twilio sub-processor) are subject to the same posture. |
| Account creation timestamp (`users.createdAt`) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — metadata about the subscriber relationship, no content. |
| Sign-in IP + timestamp (`http_audit_logs` filtered to auth endpoints; `refresh_tokens.lastUsedAt`) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine traffic data; standard SPF disclosure for attribution. |
| Last-known device label (`refresh_tokens.deviceLabel`, derived from User-Agent) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — derived metadata, no content. |
| Profile fields — display name + bio + avatar + interests + languages + current city + traveler type (`users.displayName`, `users.bio`, `users.avatarUrl`, `users.interests`, `users.languages`, `users.currentCity`, `users.travelerType`) | Resist | PDPA s4(2)(b) is the gateway, but the data is user-generated *content* (self-described identity); release only on a warrant or production order naming the user. Request letters alone do not compel release of profile content. |
| Event content — title, description, venue address, venue coordinates, start/end times, category, capacity (`events.*`) | Resist | User-generated content; same rationale as profile fields. Disclosure of event content (including venue coordinates) is a content disclosure, not a metadata disclosure. Release only on a warrant or production order. |
| Join-request content — free-text decision reason, lifecycle metadata (`join_requests.decisionReason`, lifecycle fields) | Resist | The decision reason is host-authored free text and is treated as user-generated content. Lifecycle metadata (requestedAt, decidedAt, status) follows the same posture because the disclosure context is identical — release only on warrant or production order. |
| Review content — rating, comment, hidden state (`reviews.*`) | Resist | User-generated content directed at a third party (the rated user); two-party privacy interest. Release only on a warrant or production order. |
| Report-flow metadata — reporter identity, target, reason, comment, resolution (`reports.*`) | Resist | Identifies a user who exercised an in-app safety flow; release would chill the safety system. Release only on warrant or production order. |
| Moderation actions taken — operator action, target, snapshot, reason (`moderation_action_audit.*`) | Resist | Internal operations record; release would expose moderation methodology. Release only on warrant or production order. |
| User-block relationships (`user_blocks.*`) | Resist | Discloses a user's chosen social-safety actions; release only on warrant or production order. |
| Post-event check-in records — status, flag body (`post_event_check_ins.*`) | Resist | User-generated content (flag body) and safety-flow metadata; release only on warrant or production order. |
| Selfie verification artefacts — image bytes in object storage, `users.selfieStatus`, `selfies.storageKey`, `selfies.*` lifecycle | Warrant-required | Biometric-derived personal data subject to PDPA's heightened-sensitivity treatment (PDPA Advisory Guidelines on the PDPA for Selected Topics, ch. 8 — NRIC, biometric data); release only on a court-issued warrant or production order specifically naming biometric/verification data. Operator MUST escalate to counsel before release in every case. |
| Password hash (`credentials.passwordHash`) | Warrant-required | Argon2id hash; release would compromise account security even for a hash (offline-cracking exposure). Release only on a court-issued warrant or production order; operator MUST escalate to counsel before release. |
| OTP / verification code hashes — email verification, password reset, phone OTP (`email_verification_tokens.codeHash`, `password_reset_tokens.codeHash`, phone OTP equivalents) | Warrant-required | One-time secrets used for authentication; release would compromise account security. Release only on a court-issued warrant or production order; operator MUST escalate to counsel before release. |
| Refresh-token hashes (`refresh_tokens.tokenHash`) | Warrant-required | Long-lived session secrets (hashed); release would compromise account security. Release only on a court-issued warrant or production order; operator MUST escalate to counsel before release. |
| Draft / unpublished event content (`events` rows with `status = 'draft'`) | Warrant-required | Content the user has not made available to any other party; private content disclosure requires the strictest legal compulsion. Release only on a court-issued warrant or production order specifically naming draft content; operator MUST escalate to counsel before release. |
| Account-deletion audit records (`account_deletion_events.*`) | Warrant-required | PDPA s24 evidence-integrity record; `userIdHash` is a SHA-256 hash and not directly attributable without separate correlation. Release only on a court-issued warrant or production order; operator MUST escalate to counsel before release. |
| Selfie-deletion audit records (`selfie_deletion_events.*`) | Warrant-required | PDPA s25 evidence-integrity record concerning biometric-derived data; release only on a court-issued warrant or production order; operator MUST escalate to counsel before release. |

**Data classes Tribely does NOT store** (and therefore cannot disclose):
- Plaintext passwords. Plaintext OTPs / verification codes. Plaintext refresh tokens.
- In-app direct messages (no DM feature at MVP).
- Payment instrument data (payments deferred at MVP).
- Government identity numbers (NRIC / passport — not collected).
- Precise device location histories beyond venue coordinates the user chose to attach to an event.
- Photos other than the avatar and the selfie verification artefact.

---

## 3. SLA

**Routine response: 7 calendar days from receipt of a properly-served request, where "properly-served" means delivered to `privacy@gotribely.com` or hand-delivered to the registered business address, in English, with a named SPF officer and contactable verification channel.**

**Urgent response (life-at-risk standard asserted by SPF): best-effort 24 hours from receipt; committed 48 hours from receipt.** "Life-at-risk" must be explicitly asserted by the requesting officer with a stated basis (e.g., active threat to a named or identifiable individual). Tribely does not unilaterally assess life-at-risk standing.

**Conditions:**
- The SLA clock begins when the request lands in `privacy@gotribely.com` (or hand-delivered) AND meets the served-properly conditions above. Requests not meeting the served-properly conditions are returned with a clarification request; the SLA clock starts on receipt of the resubmitted, properly-served request.
- Calendar days, not business days. Singapore public holidays do not pause the clock.
- The SLA is for an initial response — either disclosure, escalation-to-counsel notice, or scope-clarification request. The SLA is not a guarantee of completed disclosure for `Resist` or `Warrant-required` classes, which depend on counsel review and warrant validity.

---

## 4. Contacts

**Primary disclosure-authorizer:** Tribely Operations, CEO / Frans Siswanto, `franssiswanto@gmail.com`.

The CEO is the sole human authorised to release any user data to law enforcement at MVP. Single-operator model accepted at MVP; revisit at headcount > 3.

**Backup disclosure-authorizer:** BACKUP TO BE FILLED PRE-LAUNCH — role: [TBD second pair of eyes for disclosure authorization]. Filed as owner action under TRI-187. Until filled, all disclosure decisions route to the primary authorizer; an unavailable primary delays response within the SLA window rather than authorising release without primary sign-off.

**Receiving address for requests:** `privacy@gotribely.com` (canonical erasure + LE-request contact; production sender domain is `gotribely.com`, DKIM-verified).

**External counsel:** Not yet retained. Counsel engagement mechanism filed in TRI-187 (TODO link). Until retained, escalation triggers in §5 hold the request and notify the primary authorizer; the primary authorizer pauses the SLA clock (with notice to the requestor) pending counsel onboarding.

---

## 5. Counsel-trigger checklist

The operator pattern-matches every incoming request against the checklist below. If ANY trigger fires, the operator does not release data and proceeds per the trigger's action.

For each trigger: (a) condition, (b) operator action, (c) holding response to send the requestor.

### Trigger 1 — Warrant served (not a request letter)

(a) **Condition.** The request is a court-issued warrant, production order, or other instrument bearing a court seal — as distinct from a written SPF request, CPC s20 / s39 notice, or other administrative request.

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link] before any release. Even a facially valid warrant is verified for: scope (does it name the data classes in §2?), jurisdiction (Singapore court?), service (properly addressed?), validity period (not expired?). Counsel signs off before the operator runs the moderation CLI extraction.

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of the warrant referenced [warrant number / date / issuing court] on [date received] at [time]. We are reviewing the instrument for scope and validity with external counsel and will respond within our published SLA. Tribely's point of contact for this matter is Tribely Operations at privacy@gotribely.com."*

### Trigger 2 — Request scope exceeds the disclosure-scope table

(a) **Condition.** The request asks for data classes not listed in §2 OR asks for `Resist` / `Warrant-required` data classes on a request-letter basis (no warrant).

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link]. Do not release any data — including the `Release`-posture classes in the same request — until counsel has reviewed the scope mismatch. Partial release while a scope mismatch is being adjudicated risks waiver arguments on the resisted classes.

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of your request dated [date] on [date received] at [time]. The request appears to cover data classes for which Tribely's disclosure posture requires additional review. We are consulting external counsel and will respond within our published SLA with either the disclosable portions, a request for a properly-scoped warrant for the remainder, or a substantive response. Tribely's point of contact for this matter is Tribely Operations at privacy@gotribely.com."*

### Trigger 3 — Requestor jurisdiction is non-SPF (foreign LE, civil litigant)

(a) **Condition.** The requestor is a foreign law-enforcement agency (e.g., FBI, NCA, AFP) acting directly rather than via MLAT / Attorney-General's Chambers; OR a civil litigant (private party, opposing counsel in civil proceedings); OR an unidentified requestor purporting to act in a law-enforcement capacity without verifiable Singapore statutory authority.

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link]. Tribely does not respond to foreign LE direct requests on a request-letter basis (MLAT is the proper channel). Civil-litigant requests require court process. The operator does not release data and does not confirm or deny that any account exists.

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of your communication dated [date]. Tribely's disclosure protocol routes requests of this nature through external counsel. We will respond within our published SLA. For foreign law-enforcement matters, the appropriate channel is mutual legal assistance via the Attorney-General's Chambers of Singapore. For civil matters, the appropriate channel is a court order from a competent Singapore court."*

### Trigger 4 — Life-at-risk urgent flag asserted

(a) **Condition.** The requestor explicitly invokes a life-at-risk standard (e.g., "imminent risk to life", "active threat", "missing person at risk of harm") with a stated basis identifying or making identifiable the at-risk person.

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link] on the urgent track. The primary disclosure-authorizer (CEO) is paged immediately. Best-effort 24h / committed 48h SLA applies. If counsel is unreachable within the urgent SLA, the CEO may release `Release`-posture data classes only (the routine identifiers in §2) under the s4(2)(b) cooperative-by-default posture; `Resist` / `Warrant-required` classes remain held pending counsel.

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of your urgent request asserting a life-at-risk standard on [date received] at [time]. We are processing this request on our urgent track with best-effort 24-hour and committed 48-hour SLA. Our point of contact for this matter is the CEO via privacy@gotribely.com. If the situation is changing, please contact us with updated information."*

### Trigger 5 — Request involves data classes marked `Warrant-required` in §2

(a) **Condition.** The request, whether on a letter or warrant, seeks selfie verification artefacts, password hash, OTP / verification code hashes, refresh-token hashes, draft / unpublished content, or audit records (account-deletion or selfie-deletion).

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link]. Even where a warrant is served, verify with counsel that the warrant's scope specifically names the warrant-required class (generic warrants for "user data" do not authorise release of biometric-derived data, hashed authentication secrets, or audit records).

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of your request dated [date] on [date received] at [time]. The request involves data classes subject to Tribely's heightened-protection posture. We are reviewing scope and authority with external counsel and will respond within our published SLA."*

### Trigger 6 — Operator uncertainty (tiebreaker)

(a) **Condition.** The operator is uncertain whether any of triggers 1–5 fires, or whether a data class falls into `Release` / `Resist` / `Warrant-required`, or whether the request is properly served, or whether the requestor is bona fide.

(b) **Action.** Engage counsel via [mechanism filed in TRI-187 — TODO link]. **If uncertain, escalate.** Over-escalation is recoverable; under-disclosure-resistance is not.

(c) **Holding response to requestor:**
> *"Tribely acknowledges receipt of your request dated [date] on [date received] at [time]. We are reviewing the request and will respond within our published SLA."*

---

## 6. Operational execution

Data extraction is performed via the moderation CLI per [`docs/runbooks/moderation-cli.md`](../runbooks/moderation-cli.md). The CLI is the sanctioned extraction surface; ad-hoc SQL against the production database is not.

When a disclosure is authorised (by the primary authorizer, post-counsel-clearance where triggered), the operator:

1. Records the authorising decision in the disclosure log (file location and format filed in TRI-187).
2. Extracts only the data classes scoped by the request, using the CLI's read-only paths.
3. Hands over the extracted data to the requestor by the channel SPF has identified (typically encrypted email or named-officer hand-off).
4. Records the completion timestamp in the disclosure log.

Disclosures are append-only in the disclosure log. No deletion path.

---

## 7. Review cadence

This protocol is reviewed:
- On every TRI-187 update (counsel mechanism wiring, backup-contact filing).
- On every PDPA amendment touching s4(2)(b), Second Schedule, or Fourth Schedule.
- On every PDPC enforcement decision concerning consumer-facing apps and LE disclosure.
- On every change to the schema that adds a new user-data class (the scope table in §2 must be updated before the schema migration ships).
- At minimum, every 12 months.

---

## 8. External counsel disclaimer

This protocol is operational guidance from Tribely's internal compliance function. It is NOT a legal opinion. Statutory interpretation, warrant adjudication, and any contested-disclosure correspondence MUST be routed to external Singapore counsel via the mechanism filed in TRI-187. Where this protocol's posture conflicts with counsel advice on a specific request, counsel advice governs.
