# Tribely Moderation Posture — TRI-30 Baseline

**Effective date:** [to be set at publication]
**Owner:** Tribely Trust & Safety.
**Scope:** Reviews and review-related reports under TRI-30. Other UGC surfaces (event descriptions, profile bios) are out of scope and follow separate policies.

## Moderation model

Tribely uses **reactive moderation**: reviews publish immediately upon submission and are reviewed by Tribely staff only when a report is received. Tribely does not pre-publication-screen review content.

The reactive model is deliberate. Pre-publication moderation would introduce latency into the post-event review flow, create a curatorial relationship between Tribely and user content that weakens the platform's role under the Defamation Act 1957 s25 innocent-dissemination framework, and is not operationally feasible at the current scale.

The reactive model is paired with:
- A clearly published Review Content Policy.
- One-tap report access on every review.
- A 500-character cap on review comments.
- An in-flow composer notice setting behavioural expectations.
- A user-block primitive that lets users self-protect without waiting for moderation.

## Service-level commitments

Tribely commits to the following moderation timing:

| Stage | Target |
|---|---|
| First moderator touch (`firstReviewedAt`) | Within **72 hours** of report submission |
| Resolution (`resolvedAt`) after first touch | Within **24 hours** of first touch |
| Maximum total time to resolution | **7 days** from report submission |

Reports approaching the 7-day ceiling are auto-escalated to the on-call operator.

## Resolution outcomes

A reviewed report resolves to one of:
- **hidden** — the review breaches the Review Content Policy and is removed from the reviewed person's public profile and from aggregate rating computations. The review row is retained for 180 days for appeal and audit purposes, then deleted.
- **kept** — the review does not breach the policy and remains visible. The report row is retained for 24 months as a moderation record.

Tribely does not communicate per-report outcomes to reporters individually. Reporters can observe outcome via the visibility of the reported review.

## Reviewer identity

At MVP scale, moderation is performed by Tribely's founding team via an admin command-line tool. There is no in-app moderator console at this stage. The admin tool writes to the same `reports` and `reviews` tables that the app reads from; all moderator actions are audit-logged.

When moderation volume requires it, Tribely will introduce a dedicated moderator console and, if required, contracted moderators under appropriate data-processing terms.

## Escalation and appeal

Authors of hidden reviews may appeal to support@gotribely.com with the relevant event ID. Appeals are reviewed within 14 days by a moderator who was not involved in the original decision where staffing permits.

Reviewed parties who believe a kept review is harmful beyond Tribely's policy threshold (e.g. defamatory in legal terms) may seek independent legal advice. Tribely will respond to formal legal notices and lawful disclosure requests from Singapore authorities in accordance with PDPA s17 and the relevant procedural law.

## Transparency

Tribely intends to publish aggregate moderation metrics annually once volumes are meaningful (reports received, resolution mix, median time-to-resolution). MVP-stage metrics are tracked internally and available to regulators on lawful request.

## Review of this posture

This posture document is reviewed quarterly and after any material incident.
