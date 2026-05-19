# PDPA Retention — TRI-30 Surfaces

**Effective date:** [to be set at publication]
**Owner:** Tribely Data Protection.
**Statutory basis:** Personal Data Protection Act 2012 (Singapore), s25 (Retention Limitation).
**Scope:** Data classes introduced by TRI-30 — reviews, reports, user blocks.

## Section 25 framing

PDPA s25 requires Tribely to cease retention of personal data, or remove the means by which the data can be associated with particular individuals, as soon as it is reasonable to assume that the purpose for which the data was collected is no longer being served by retention, and retention is no longer necessary for legal or business purposes.

The retention windows below are Tribely's reasoned assessment of when each purpose ceases. They are not arbitrary maxima; they are floors driven by the operational, evidentiary, and safety purposes the data serves.

## Retention windows

### Reviews — non-hidden

**Window:** Lifetime of the rated user's Tribely account.
**Trigger for deletion:** Either the rater or the ratee deletes their account.
**Purpose served:** Platform trust, safety signalling, and discovery rely on accumulated review history. The purpose persists for as long as the reviewed person uses Tribely. Once they leave, the purpose ceases.

### Reviews — hidden

**Window:** 180 days from the `events.reviewHidden` event.
**Trigger for deletion:** Time-based sweep.
**Purpose served:** Appeals window (authors may contest within 14 days; investigation can extend further), regulator-evidence window (PDPC and other authorities may request records of moderation activity), and pattern-analysis for repeat policy violations.

### Reports — open

**Window:** Indefinite while open.
**Trigger for deletion:** Conversion to a resolved state (hidden or kept), or deletion of the underlying review.
**Purpose served:** Open reports are active workflow state; deletion before resolution would defeat the moderation process itself.

### Reports — resolved

**Window:** 24 months from `resolvedAt`.
**Trigger for deletion:** Time-based sweep.
**Purpose served:** Defamation Act and Protection from Harassment Act limitation periods may run beyond one year; 24 months provides evidentiary headroom for pattern analysis (repeat reporters, repeat targets) and for response to lawful disclosure requests.

### User blocks

**Window:** Lifetime of both users' accounts.
**Trigger for deletion:** Either party deletes their account.
**Purpose served:** A block is an active safety relationship. Time-based pruning would silently restore visibility between people who have explicitly chosen invisibility from each other, creating a safety regression.

### Aggregate ratings on profiles

Derived from non-hidden reviews at read-time. Not separately stored. No independent retention concern.

## Account-deletion cascade

When a Tribely account is deleted:

| Data class | Behaviour on deletion |
|---|---|
| Reviews authored by the deleter | Hard-deleted; counterparties' profile aggregates recompute. |
| Reviews about the deleter | Hard-deleted; the deleter's profile aggregates are no longer surfaced because the profile itself is gone. |
| Reports filed by the deleter | Reporter identity is nulled; the report row is retained for the resolved-reports 24-month window for moderation-audit purposes. |
| Reports about reviews authored by the deleter | Cascade-deleted with the underlying review. |
| Blocks initiated by the deleter | Hard-deleted. |
| Blocks against the deleter | Hard-deleted. |

Account deletion is irreversible. Tribely does not maintain a soft-delete state that retains personal data after a user's deletion request, in accordance with Apple App Store Review Guideline 5.1.1(v) and Google Play's 2024 account-deletion requirement.

## Subject access requests

Tribely will provide, on a verified data-subject request to dpo@gotribely.com:
- Reviews authored by the requester.
- Reviews about the requester.
- Reports filed by the requester.
- Reports against reviews authored by the requester, with reporter identity redacted under PDPA s21(3)(b).
- Blocks initiated by the requester.

Blocks against the requester (inbound blocks) and reporter identities are not disclosed, on the basis that disclosure could threaten the safety of another individual (PDPA s21(3)(c)) or reveal personal data about a third party without their consent (s21(3)(b)).

Tribely responds to subject access requests within 30 days of receipt, as required by PDPA s21(1).

## Correction requests

Opinion data — including star ratings and subjective comments in reviews — is not subject to factual correction under PDPA s22. Where a review about the requester contains an alleged factual error, the requester should submit the review through the in-app report flow with reason "false_information"; the moderation team will assess whether the content meets the s22 correction threshold or is protected opinion.

## Implementation

Retention sweeps for hidden reviews (180 days) and resolved reports (24 months) are run by a scheduled job in the Tribely backend, audit-logged to the same audit tables that record other deletion events.

## Review of these windows

These windows are reviewed annually and after any material regulatory development from the PDPC or relevant authorities.
