# Account Deletion SLA — Operator Runbook

## 1. Scope

This runbook governs operator handling of account-deletion requests for Tribely's Singapore launch. It covers the two channels by which a deletion request can arrive, the SLA the platform commits to under PDPA s25 (Protection Obligation) and s26 (Retention Limitation), and the audit posture that satisfies PDPC inspection.

- **In-app deletion** — user invokes "Delete account" inside the Tribely mobile app. The mobile client calls `DeleteAccountUseCase` directly through the authenticated HTTP path.
- **Operator-fulfilled deletion (privacy mailbox)** — user emails `privacy@gotribely.com` requesting deletion. An on-call operator authenticates the requester (per §3) and runs the privacy-mailbox-fulfilment script, which invokes `DeleteAccountUseCase` on the user's behalf.

Both paths execute the SAME cascade. The contract for what is deleted, hashed, redacted, or retained is in `docs/policy/pii-cascade-contract.md`.

## 2. SLA commitment

- **Acknowledgement:** within 3 business days of receipt (PDPC guideline alignment).
- **Completion:** within 30 calendar days of receipt for both channels.
- **PDPA basis:** s26 Retention Limitation — personal data must not be retained beyond the purposes for which it was collected. A 30-day completion ceiling is the industry-aligned reading for consumer apps with no statutory retention obligation on the deleted classes.

In-app deletions complete synchronously (single request, single cascade transaction). Operator-fulfilled deletions complete when the operator runs the script; the 30-day ceiling exists to bound mailbox triage latency, not the cascade itself.

## 3. Requester authentication (operator-fulfilled path only)

Before running the script, the operator MUST confirm the requester controls the account. Accepted proofs:

- Reply from the email address registered on the account (primary path; in 99% of cases the mailbox sender IS the account holder).
- If the requester emails from a different address: require a one-time verification code sent to the registered email and quoted back in their reply.

Do NOT proceed on photo-ID alone — the cascade is irreversible and we have no recovery path. When in doubt, escalate.

## 4. Channel attribution and audit

Channel attribution is recorded via the AsyncLocalStorage request-context label. The privacy-mailbox fulfilment script MUST invoke `DeleteAccountUseCase` inside `runAsSystem('ops.privacy-mailbox-fulfilment', fn)`. The audit row's `requestId` field will then contain a value matching `system:ops.privacy-mailbox-fulfilment:*`; PDPC inspection queries discriminate via `requestId LIKE 'system:ops.privacy-mailbox-fulfilment:%'` (operator) vs. `requestId NOT LIKE 'system:%' AND requestId IS NOT NULL` (in-app) vs. `requestId IS NULL` (legacy or misconfigured — should never occur for in-app or operator paths; presence indicates a bug to investigate).

The `account_deletion_events` audit row is written atomically with the cascade (required-ctx pattern per TRI-79 precedent). One row per deletion, with `userId`, `requestId`, `cascadeScopes` (the set of enum values touched), and the timestamp. This row is the legal evidence that the cascade ran; it is retained indefinitely.

## 5. PDPC inspection posture

If PDPC requests evidence of a deletion (either to confirm we honoured a request or to audit our retention practice):

- Query `account_deletion_events` by `userId` (the operator can derive the userId from the original email via the privacy mailbox correspondence log).
- The row's `requestId` discriminates channel per §4.
- The row's `cascadeScopes` enumerates which classes were affected (full vs. partial — current design is always full cascade; partial is reserved for future legal-hold scenarios).
- The contract for WHAT happened to each class is `docs/policy/pii-cascade-contract.md`, versioned in git.

## 6. Failure handling

The cascade is a single transaction. Partial failure is impossible by construction — either every class in scope is processed or none are, and the audit row reflects the committed state. If the script errors:

- The cascade did NOT run. Re-run after diagnosing.
- The audit row is NOT written. There is no inconsistent state.
- Escalate to engineering if the failure recurs.

Do NOT manually delete rows in any of the cascade-target tables outside the script. Manual DB intervention bypasses audit and breaks the legal evidence chain.
