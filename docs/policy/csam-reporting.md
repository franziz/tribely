# CSAM Reporting Policy

**Status:** Active (MVP launch posture)
**Audience:** Internal — Tribely operations (CEO / Frans Siswanto), moderation operator on duty, future counsel
**Owner:** CEO / Frans Siswanto
**Last reviewed:** 2026-05-29
**Operational companion:** [`docs/runbooks/moderation-cli.md` §4A](../runbooks/moderation-cli.md#4a-csam-cybertipline-submission) (executable steps)

This is a one-page statement of how Tribely handles suspected Child Sexual Abuse Material (CSAM) discovered on the platform. It states the disclosure channel, when it fires, who acts, what is submitted, and the human-counsel fallback. The executable operator steps live in the moderation runbook §4A — this policy is the commitment; the runbook is the how.

Tribely is an adults-only platform. A stated adults-only age posture reduces the *volume* of CSAM exposure; it does **not** waive the obligation to report apparent CSAM if it is encountered. The duty to report attaches regardless of the age gate.

---

## 1. Disclosure channel

Tribely's CSAM disclosure channel is the **NCMEC CyberTipline public webform** at **https://report.cybertip.org/**.

**Rationale (minimum-dollar posture):**
- **Statutorily-recognised channel.** NCMEC operates the CyberTipline under the authority of 18 U.S.C. § 2258A. It is the recognised clearing-house for CSAM reports and routes reports to the relevant national law-enforcement body — for Singapore, via INTERPOL channels to the Singapore Police Force.
- **No integration burden.** The public webform accepts voluntary reports from non-US providers without ESP registration, API integration, paid vendor, or contract surface. This keeps Tribely's reporting obligation executable at solo-operator scale with zero per-incident cost and no commercial/indemnity exposure.
- **Foreign-provider posture.** Mandatory ESP reporting under 18 U.S.C. § 2258A applies to US-based providers; foreign providers may submit voluntarily via the webform without registering as an ESP. Tribely submits voluntarily and does not register as an ESP at this stage.

---

## 2. Trigger conditions

A report enters this policy's path when it is **CSAM-categorised** under Tribely's existing moderation taxonomy. Specifically:

- The report falls under **Category 3 — Minor involved** of the moderation runbook ([`moderation-cli.md` §4](../runbooks/moderation-cli.md#category-3--minor-involved)), AND
- The operator, on review limited to confirming the category, identifies the content as **suspected CSAM** — recorded with the audit tag **`minor_csam_suspected`** (moderation runbook §4 Category 3 step 5).

The `minor_csam_suspected` tag is the single trigger that fires the CyberTipline submission path in §4A of the runbook. Category 3 reports that are *minor-involved but not CSAM* (e.g., a minor's presence in a non-abusive context) remain on the standard Category 3 counsel-escalation path and do **not** trigger a CyberTipline submission.

---

## 3. Who submits

The **moderation operator on duty** per the moderation-CLI operator rotation (the rotation established under TRI-141, migrating to the HTTP admin surface under TRI-159 / TRI-157) is the operator of record for the CyberTipline submission.

At solo-operator launch scale this is the CEO / Frans Siswanto. A distinct senior assignment *could* be argued given the legal sensitivity of CSAM matters; this is moot at solo-operator scale and is revisited if the rotation widens.

---

## 4. What is submitted

The operator submits to the CyberTipline, drawn from the atomically-preserved evidence snapshot (moderation runbook §5):

- **Image / content evidence reference.** The preserved snapshot of the reported content (the operator does **not** download or re-distribute — see the handling guardrail below). NCMEC's webform accepts a description and, where the operator judges it appropriate and safe, the URL/identifier of the hosted content.
- **Reporter context.** The reporting user's account identifier and the reason/category they filed under.
- **Timestamps.** Report submission time (`reportedAt`), operator identification time, and submission time.
- **Account identifiers.** The account identifier of the author of the reported content and, where the report targets a user rather than a single item, the reported user's account identifier.

**Handling guardrail (extends, never relaxes, the runbook §4 Category 3 step 5 rule).** The operator does **NOT** view the content further than necessary to confirm the category, does **NOT** download it, and does **NOT** distribute it internally beyond the operator + named counsel. The audit row for a `minor_csam_suspected` matter is treated as legally privileged. Evidence handling is governed by PDPA Section 24 (Protection Obligation) and the §5 atomic preserve-and-audit discipline; nothing in this policy authorises broader access to the content.

---

## 5. Named human-counsel fallback

Where the operator judges that a CSAM incident needs legal guidance — for example, ambiguity over whether a direct Singapore Police Force report is required in addition to the NCMEC routing, an imminent-harm dimension, or any contested-disclosure question — the operator escalates to the **named Singapore Trust & Safety counsel recorded in [`moderation-cli.md` §4A.6](../runbooks/moderation-cli.md#4a6-named-trust--safety-counsel-fallback)**.

This counsel is **named but not pre-engaged / not retained.** Engagement is **per-incident**, opened only when a real incident warrants it. Pre-identifying the named human ensures the operator is not improvising under pressure; it does not commit Tribely to a retainer.

---

## 6. Latent obligations (documented, deferred per CEO minimum-dollar ruling)

- **No counsel-cleared CYPA memo at launch.** Tribely does not hold a counsel-cleared memo on whether the Children and Young Persons Act (CYPA) or any other Singapore statute mandates a **direct** local report (to SPF or a designated body) in addition to NCMEC routing. Working answer: NCMEC → SPF routing is sufficient for the platform-reporting obligation; a mandatory direct SPF report may attach for severe / imminent cases. This is a deferred external-counsel question, revisited at the first real incident or at Series A — not a launch blocker per CEO ruling.

---

## 7. External counsel disclaimer

This policy is operational guidance from Tribely's internal compliance function. It is **NOT** a legal opinion. Statutory interpretation (including the CYPA direct-report question), any contested-disclosure correspondence, and engagement of the §5 named counsel MUST be handled by external Singapore counsel. Where this policy conflicts with counsel advice on a specific incident, counsel advice governs.
