# PII Cascade Contract — Account Deletion

## 1. Purpose

This document is the binding contract for what `DeleteAccountUseCase` does to every class of personal data Tribely stores. It exists to satisfy PDPA s25 (Protection Obligation) — operators and PDPC must be able to audit, ahead of any actual deletion, exactly what the platform commits to do for each data class. The behaviour described here is enforced by code; this document is the source of truth and PR review gate for any change to the cascade.

Two channels invoke this cascade — in-app deletion and operator-fulfilled (privacy mailbox). Both run the SAME contract. Channel attribution is recorded separately via audit (see `docs/runbooks/account-deletion-sla.md` §4); it does not vary the cascade itself.

## 2. Per-class contract

| # | Data class | Action | Rationale |
|---|---|---|---|
| 1 | `users` row | Soft-delete: `deletedAt = now()`, PII columns nulled (display name, bio, locale) | Foreign key target for historical event/join-request rows; hard-delete would cascade-orphan or block deletion. PII nulled to satisfy s26. |
| 2 | `credentials` row | Hard-delete | No retention obligation; presence is itself the auth surface that must be removed. |
| 3 | `refresh_tokens` rows | Hard-delete (all) | Active sessions must terminate immediately. |
| 4 | `email_verification_tokens` rows | Hard-delete (all) | Tied to credential; no independent retention basis. |
| 5 | `password_reset_tokens` rows | Hard-delete (all) | Tied to credential; no independent retention basis. |
| 6 | `selfies` row + S3 object | Hard-delete row, S3 object deletion via existing TRI-79 mechanism | Biometric class; strict deletion per TRI-79 design. |
| 7 | `selfie_deletion_events` rows | Retain unchanged | PDPA s25 evidence-integrity audit; survival of the cascade is the design requirement (TRI-79). |
| 8 | `check_ins` rows | Hash `userId` to a stable pseudonym, retain row otherwise | Event-attendance aggregates serve host's legitimate interest (no-show patterns); pseudonymization breaks linkage to the deleted user. |
| 9 | `events` rows where this user is host | Soft-disassociate: `hostUserId` nulled or rebound to a "deleted user" sentinel; event itself retained if it has accepted attendees | Other users depend on the event row; hard-delete would corrupt their experience. |
| 10 | `join_requests` rows authored by this user | Hash `requesterUserId` to a stable pseudonym, retain row otherwise | Host's audit of who-they-approved is legitimate interest; pseudonymization breaks linkage. |
| 11 | `http_audit_logs` rows where actor is this user | Hash `actorUserId` column to a stable pseudonym; other columns unchanged | PDPA s25 audit-trail integrity vs. s26 retention — pseudonymization is the established compromise. |
| 12 | `event_audit_logs` rows where actor is this user | Hash `actorUserId` column to a stable pseudonym; other columns unchanged | Same rationale as row 11. |
| 13 | `outbox_events` rows where payload references this user | Redact payload PII fields in-place (replace name/email/locale with `[redacted]`); preserve event type, aggregate id, seq | Outbox is append-only by design; redaction is the only available action. Event lifecycle audit chain remains intact. |
| 14 | `User.deletedAt` field (set itself) | Set to `now()` as the cascade's terminal write | The deletion timestamp on the soft-deleted user row is the canonical "this user is gone" signal for application-layer filters. |

Of the 14 rows above, 12 appear in the `AccountDeletionCascadeScope` enum (any class whose state is actively modified by the cascade). The two retain-without-modification classes (`selfie_deletion_events` retained per TRI-79 design; the implicit `User.deletedAt` set itself) appear in this contract table for completeness but are NOT enum values — the cascade does not write a token for them.

## 3. `cascadeScope` enum reconciliation

Every row the cascade writes is enumerated in the `cascadeScope` column on `account_deletion_events`. The audit row's `cascadeScopes` array lists exactly which scopes were touched in a given cascade execution, providing PDPC with a per-deletion manifest.

The enum values are the underscore-cased identifiers defined in `apps/api/src/features/audit/domain/repositories/account-deletion-event.repository.ts` as `AccountDeletionCascadeScope`. The 12 values are: `users`, `credentials`, `refresh_tokens`, `email_verification_tokens`, `password_reset_tokens`, `selfies`, `check_ins`, `events_hosted`, `join_requests_authored`, `http_audit_logs_actor_hashed`, `event_audit_logs_actor_hashed`, `outbox_events_redacted`.

Current design always touches all 12 in a single cascade — the array is invariant per invocation. The array shape is preserved (rather than collapsed to a boolean "cascade ran") to leave a forward-compatible audit surface for future partial-cascade scenarios (e.g., legal hold on a subset of classes).

## 4. Change control

Any change to this contract — adding a class, changing an action, changing the rationale — requires:

1. A PR that updates THIS document and the corresponding code change atomically.
2. Sign-off from CEO (legal/compliance posture) and engineering-lead (technical correctness).
3. A migration plan if existing `account_deletion_events` rows would become inconsistent with the new contract.

This document is git-versioned; the version that was active at the time of any cascade is recoverable via `git log`. PDPC inspection treats the git-blame of this file as canonical.

## 5. Non-goals

- This contract does NOT cover deletion of data Tribely processes but does not store (e.g., data sent to third-party payment processors — deferred, no payments at launch).
- This contract does NOT cover account deactivation (a future post-launch feature, distinct from deletion).
- This contract does NOT cover GDPR Article 17 ("right to erasure") — Singapore launch is PDPA-only; GDPR readiness is a separate post-launch initiative if/when Tribely targets EU users.
