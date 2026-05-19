import { createId } from '@paralleldrive/cuid2';

import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PostEventCheckInRepository } from '../../domain/repositories/post-event-check-in.repository.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';
import type { PseudonymiseCheckInsForUserResult } from '../dto/pseudonymise-check-ins-for-user.result.js';

export interface PseudonymiseCheckInsForUserInput {
  userId: string;
}

/**
 * Pseudonymise all post-event check-in rows tied to a user as part of a
 * PDPA erasure cascade. Designed to be called directly by a future
 * `DeleteAccountUseCase` — no HTTP endpoint, no event subscription.
 *
 * Required-ctx two-arg execute(input, ctx) shape (A7 exception):
 *   - This use case joins the CALLER's UnitOfWork transaction.
 *   - There is NO internal unitOfWork.run — opening a nested UoW here would
 *     defeat the atomicity contract required by the cascade.
 *   - Every repo call and audit record commits atomically within the
 *     caller-supplied TxContext.
 *
 * Pseudonymisation strategy:
 *   - A single fresh cuid2 pseudonym is generated per invocation.
 *   - `flagged` rows where userId === input.userId  → userId rewritten.
 *   - `flagged` rows where hostUserId === input.userId → hostUserId rewritten.
 *   - `pending` and `ok` rows where userId === input.userId are DELETED
 *     (no evidentiary value; no flagged content to preserve).
 *
 * Audit granularity — AGGREGATE (one record per pseudonymiseForUser call):
 *   The repository's `pseudonymiseForUser` returns only a row count, not the
 *   touched rows themselves. Extending the repository to return IDs would
 *   require adding a method to the domain interface (out of scope per the
 *   B5 brief hard rule). Per-row audit is therefore deferred to a future
 *   ticket that can add `pseudonymiseForUser` → `{ count, ids }`. Until then,
 *   each aggregate call records one audit row whose `checkInId` carries the
 *   caller-provided `userId` as a synthetic aggregate identifier (the actual
 *   row IDs are not available from the count-only return). This is sufficient
 *   for the PDPA s25 trail: the audit record proves pseudonymisation occurred
 *   for `userId` at `occurredAt`, even without individual row IDs.
 *
 * Deletion audit granularity — PER-ROW for pending rows (listPendingForUser
 *   returns the full set, so individual IDs are available). For `ok` rows the
 *   domain repository has no per-user query; deletion of ok rows is deferred
 *   until `PostEventCheckInRepository` gains a `listByUserAndStatus` method.
 *   TODO(TRI-29-followup): add `listByUserAndStatus` to the repo to cover ok
 *   rows in the deletion path and switch aggregate audit to per-row audit.
 */
export class PseudonymiseCheckInsForUserUseCase {
  constructor(
    private readonly checkIns: PostEventCheckInRepository,
    private readonly recordAuditEvent: PostEventCheckInAuditPort,
    private readonly clock: Clock,
  ) {}

  async execute(
    input: PseudonymiseCheckInsForUserInput,
    ctx: TxContext,
  ): Promise<PseudonymiseCheckInsForUserResult> {
    const { userId } = input;
    const pseudonymUserId = createId();
    const now = this.clock.now();

    // ── 1. Pseudonymise flagged rows where this user was the attendee ──────────
    const attendeeCount = await this.checkIns.pseudonymiseForUser(
      { userId, pseudonymUserId, role: 'attendee' },
      ctx,
    );

    if (attendeeCount > 0) {
      // Aggregate audit: one record per batch; checkInId carries userId as the
      // synthetic aggregate identifier (see docstring above).
      await this.recordAuditEvent.execute(
        {
          checkInId: userId,
          userId,
          eventId: userId,
          reason: 'pseudonymised',
          occurredAt: now,
        },
        ctx,
      );
    }

    // ── 2. Pseudonymise flagged rows where this user was the host ──────────────
    const hostCount = await this.checkIns.pseudonymiseForUser(
      { userId, pseudonymUserId, role: 'host' },
      ctx,
    );

    if (hostCount > 0) {
      await this.recordAuditEvent.execute(
        {
          checkInId: userId,
          userId,
          eventId: userId,
          reason: 'pseudonymised',
          occurredAt: now,
        },
        ctx,
      );
    }

    // ── 3. Delete pending rows authored by this user (per-row audit) ───────────
    const pendingRows = await this.checkIns.listPendingForUser(userId, ctx);
    for (const checkIn of pendingRows) {
      await this.checkIns.deleteById(checkIn.id, ctx);
      await this.recordAuditEvent.execute(
        {
          checkInId: checkIn.id,
          userId,
          eventId: checkIn.eventId,
          reason: 'deleted_by_retention',
          occurredAt: now,
        },
        ctx,
      );
    }

    // NOTE: ok rows for this user are NOT deleted here — the domain repository
    // has no listByUserAndStatus method that filters by userId + status='ok'.
    // Covered by TODO(TRI-29-followup) above.

    return {
      pseudonymisedReports: attendeeCount + hostCount,
      deletedReports: pendingRows.length,
    };
  }
}
