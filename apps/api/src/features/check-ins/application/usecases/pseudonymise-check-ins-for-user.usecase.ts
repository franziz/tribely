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
 * Audit granularity:
 *   Pseudonymisation uses aggregate audit — one record per `pseudonymiseForUser`
 *   batch. `checkInId` carries `userId` as a synthetic aggregate identifier
 *   because `pseudonymiseForUser` returns a count only (row IDs unavailable).
 *   This is sufficient for the PDPA s25 trail: the audit record proves
 *   pseudonymisation occurred for `userId` at `occurredAt`.
 *
 *   Deletion uses per-row audit — `listByUserAndStatus` returns the full set,
 *   so individual IDs are available. Each deleted row produces one audit entry
 *   with `checkInId === row.id` and the correct `eventId`.
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

    // ── 1. Delete pending and ok rows authored by this user (per-row audit) ────
    // MUST run before pseudonymiseForUser — that call issues an UPDATE without a
    // status filter and rewrites userId on ALL rows (pending, ok, AND flagged).
    // After pseudonymisation, listByUserAndStatus(userId) would return zero rows
    // and the deletion step would silently no-op, producing no audit records.
    let deletedCount = 0;
    for (const status of ['pending', 'ok'] as const) {
      const rows = await this.checkIns.listByUserAndStatus(userId, status, ctx);
      for (const row of rows) {
        await this.checkIns.deleteById(row.id, ctx);
        await this.recordAuditEvent.execute(
          {
            checkInId: row.id,
            userId,
            eventId: row.eventId,
            reason: 'deleted_by_retention',
            occurredAt: now,
          },
          ctx,
        );
      }
      deletedCount += rows.length;
    }

    // ── 2. Pseudonymise flagged rows where this user was the attendee ──────────
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

    // ── 3. Pseudonymise flagged rows where this user was the host ──────────────
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

    return {
      pseudonymisedReports: attendeeCount + hostCount,
      deletedReports: deletedCount,
    };
  }
}
