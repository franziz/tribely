# Law Enforcement Disclosure Protocol

**Status:** Active
**Last reviewed:** 2026-05-25

---

## 1. Purpose and scope

This protocol governs how Tribely responds to data-disclosure requests from law-enforcement authorities — primarily the Singapore Police Force (SPF) and other Singapore statutory authorities (IMDA, MAS, IRAS, CPIB) — concerning user data Tribely processes.

Tribely operates a Singapore-first social events platform. This protocol applies to disclosure requests for any user data Tribely stores.

**Out of scope:**
- Civil-litigant subpoenas (different posture — escalated to external counsel).
- Foreign law-enforcement requests (different posture — escalated to external counsel; the appropriate channel is mutual legal assistance via the Attorney-General's Chambers).
- Mutual Legal Assistance Treaty (MLAT) requests routed via the Attorney-General's Chambers (treated as SPF-channelled).
- Court orders in private litigation (escalated to external counsel).
- Regulator notices outside disclosure (e.g., PDPC investigation under PDPA s50) — separate response posture.

**Legal basis for disclosure without consent:** PDPA s4(2)(b) (the Act does not impose the consent / notification / access / correction obligations in Parts III–VI when disclosure is required or authorised under any written law or by an order of a court) and PDPA Second Schedule paragraph 1(e) / Fourth Schedule (disclosure for law-enforcement purposes by a public agency).

---

## 2. Disclosure-scope posture table

Three postures govern every data class:

- **`Release`** — disclosed to SPF on properly-served request (cooperative-by-default under PDPA s4(2)(b)). No warrant required.
- **`Resist`** — not disclosed on a request letter alone. Released only on (a) a court-issued warrant or production order, or (b) specific statutory compulsion naming the data class.
- **`Warrant-required`** — released only on a court-issued warrant or production order. Distinct from `Resist`: even where a statutory provision might be argued to compel disclosure, Tribely treats these classes as warrant-only and verifies the compulsion's specificity before release.

| Data class | Posture | Rationale |
|---|---|---|
| Account identifier | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — opaque identifier carrying no content; necessary precondition for SPF to identify the account being investigated. |
| Email address | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine subscriber identifier; standard SPF disclosure under Criminal Procedure Code (CPC) s20 / s39 notice. |
| Phone number (where verified) | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine subscriber identifier on equal footing with email. |
| Account creation timestamp | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — metadata about the subscriber relationship, no content. |
| Sign-in IP + timestamp | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — routine traffic data; standard SPF disclosure for attribution. |
| Last-known device label | Release | PDPA s4(2)(b) + Second Schedule para 1(e) — derived metadata, no content. |
| Profile fields — display name, bio, avatar, interests, languages, current city, traveler type | Resist | PDPA s4(2)(b) is the gateway, but the data is user-generated *content* (self-described identity); release only on a warrant or production order naming the user. Request letters alone do not compel release of profile content. |
| Event content — title, description, venue address, venue coordinates, start/end times, category, capacity | Resist | User-generated content; same rationale as profile fields. Disclosure of event content (including venue coordinates) is a content disclosure, not a metadata disclosure. Release only on a warrant or production order. |
| Join-request content — free-text decision reason, lifecycle metadata | Resist | The decision reason is host-authored free text and is treated as user-generated content. Lifecycle metadata follows the same posture because the disclosure context is identical — release only on warrant or production order. |
| Review content — rating, comment, hidden state | Resist | User-generated content directed at a third party (the rated user); two-party privacy interest. Release only on a warrant or production order. |
| Report-flow metadata — reporter identity, target, reason, comment, resolution | Resist | Identifies a user who exercised an in-app safety flow; release would chill the safety system. Release only on warrant or production order. |
| Moderation actions taken — operator action, target, snapshot, reason | Resist | Internal operations record. Release only on warrant or production order. |
| User-block relationships | Resist | Discloses a user's chosen social-safety actions; release only on warrant or production order. |
| Post-event check-in records — status, flag body | Resist | User-generated content (flag body) and safety-flow metadata; release only on warrant or production order. |
| Selfie verification artefacts — image bytes, status, lifecycle | Warrant-required | Biometric-derived personal data subject to PDPA's heightened-sensitivity treatment (PDPA Advisory Guidelines on the PDPA for Selected Topics, ch. 8 — NRIC, biometric data); release only on a court-issued warrant or production order specifically naming biometric/verification data. |
| Password hash | Warrant-required | Argon2id hash; release would compromise account security even for a hash (offline-cracking exposure). Release only on a court-issued warrant or production order. |
| OTP / verification code hashes — email verification, password reset, phone OTP | Warrant-required | One-time secrets used for authentication; release would compromise account security. Release only on a court-issued warrant or production order. |
| Refresh-token hashes | Warrant-required | Long-lived session secrets (hashed); release would compromise account security. Release only on a court-issued warrant or production order. |
| Draft / unpublished event content | Warrant-required | Content the user has not made available to any other party; private content disclosure requires the strictest legal compulsion. Release only on a court-issued warrant or production order specifically naming draft content. |
| Account-deletion audit records | Warrant-required | PDPA s24 evidence-integrity record. Release only on a court-issued warrant or production order. |
| Selfie-deletion audit records | Warrant-required | PDPA s25 evidence-integrity record concerning biometric-derived data; release only on a court-issued warrant or production order. |

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

**Primary disclosure-authorizer:** Tribely Operations / CEO.

**Backup disclosure-authorizer:** Tribely Operations / [second-pair-of-eyes role, to be confirmed pre-launch].

**Receiving address for requests:** `privacy@gotribely.com`.

---

## 5. External counsel escalation

Tribely engages external Singapore counsel for any request that: requires a warrant under the scope table above; originates outside Singapore jurisdiction (foreign law-enforcement direct requests, civil litigants); asserts a life-at-risk urgency standard; involves any data class marked `Warrant-required` even where a warrant is presented; or presents any case where Tribely is uncertain whether release is properly compelled. Tribely does not release data while a request is under counsel review.

---

## 6. Review cadence

This protocol is reviewed on every PDPA amendment touching s4(2)(b), Second Schedule, or Fourth Schedule; on every PDPC enforcement decision concerning consumer-facing apps and law-enforcement disclosure; on every change to the data Tribely stores that adds a new user-data class; and at minimum, every 12 months.

---

## 7. External counsel disclaimer

This protocol is operational guidance from Tribely's internal compliance function. It is NOT a legal opinion. Statutory interpretation, warrant adjudication, and any contested-disclosure correspondence are routed to external Singapore counsel. Where this protocol's posture conflicts with counsel advice on a specific request, counsel advice governs.
