import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PostEventCheckInRepository } from '../../domain/repositories/post-event-check-in.repository.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';
import type { PrunePostEventCheckInsResult } from '../dto/prune-post-event-check-ins.result.js';

/**
 * Subtracts `months` calendar months from `date`.
 *
 * Clamps the day to the last valid day of the resulting month (e.g.
 * 2028-03-31 minus 1 month → 2028-02-29, not the invalid 2028-02-31).
 * Mirrors the same helper in PrunePostEventCheckInEventsUseCase — kept
 * local here to avoid a cross-use-case import.
 */
function subtractMonths(date: Date, months: number): Date {
  const result = new Date(date);
  const targetMonth = result.getMonth() - months;
  result.setMonth(targetMonth);
  const intendedMonth = ((targetMonth % 12) + 12) % 12;
  if (result.getMonth() !== intendedMonth) {
    result.setDate(0);
  }
  return result;
}

const PENDING_RETENTION_DAYS = 30;
const OK_RETENTION_DAYS = 90;
const FLAGGED_RESOLVED_RETENTION_MONTHS = 12;

/**
 * Sweeps expired post-event check-in records from the `post_event_check_ins`
 * table according to three retention boundaries:
 *
 *   1. `pending` rows where createdAt < now − 30 days → delete + audit
 *   2. `ok` rows where createdAt < now − 90 days → delete + audit
 *   3. `flagged` rows where resolvedAt IS NOT NULL AND
 *         resolvedAt < now − 12 months → delete + audit
 *
 * Critically: `flagged` rows where resolvedAt IS NULL are NEVER deleted by
 * this sweep. They represent unresolved safety reports that must be retained
 * indefinitely until an operator marks them resolved.
 *
 * Per-row UoW pattern: each deletion + audit row is committed in its own
 * `unitOfWork.run(...)` for crash safety — if the process dies mid-sweep,
 * the next run skips already-deleted rows and retries remaining ones.
 * This matches B4's PrunePostEventCheckInEventsUseCase pattern.
 *
 * Audit wire (A7 exception): for each deleted row, calls
 * PostEventCheckInAuditPort.execute({..., reason: 'deleted_by_retention'}, ctx)
 * inside the same UoW — the audit row commits atomically with the deletion.
 *
 * Standard single-arg `execute()` shape — this use case opens its own UoW
 * per row (unlike the two-arg pattern used by cascade callers).
 */
export class PrunePostEventCheckInsUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly checkIns: PostEventCheckInRepository,
    private readonly recordAuditEvent: PostEventCheckInAuditPort,
    private readonly clock: Clock,
  ) {}

  async execute(): Promise<PrunePostEventCheckInsResult> {
    const now = this.clock.now();

    const pendingCutoff = new Date(now.getTime() - PENDING_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    const okCutoff = new Date(now.getTime() - OK_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    const flaggedResolvedCutoff = subtractMonths(now, FLAGGED_RESOLVED_RETENTION_MONTHS);

    // ── 1. Sweep pending rows older than 30 days ────────────────────────────
    const pendingRows = await this.checkIns.listForRetentionSweep({
      status: 'pending',
      olderThan: pendingCutoff,
    });

    let pendingDeleted = 0;
    for (const row of pendingRows) {
      await this.unitOfWork.run(async (ctx) => {
        await this.checkIns.deleteById(row.id, ctx);
        await this.recordAuditEvent.execute(
          {
            checkInId: row.id,
            userId: row.userId,
            eventId: row.eventId,
            reason: 'deleted_by_retention',
            occurredAt: now,
          },
          ctx,
        );
      });
      pendingDeleted++;
    }

    // ── 2. Sweep ok rows older than 90 days ─────────────────────────────────
    const okRows = await this.checkIns.listForRetentionSweep({
      status: 'ok',
      olderThan: okCutoff,
    });

    let okDeleted = 0;
    for (const row of okRows) {
      await this.unitOfWork.run(async (ctx) => {
        await this.checkIns.deleteById(row.id, ctx);
        await this.recordAuditEvent.execute(
          {
            checkInId: row.id,
            userId: row.userId,
            eventId: row.eventId,
            reason: 'deleted_by_retention',
            occurredAt: now,
          },
          ctx,
        );
      });
      okDeleted++;
    }

    // ── 3. Sweep flagged rows with resolvedAt < now − 12 months ─────────────
    // The repository's listForRetentionSweep filters by createdAt, not resolvedAt.
    // We query all flagged rows where resolvedAt IS NOT NULL (hasResolvedAt=true),
    // passing epoch as the olderThan to retrieve the full set, then filter by
    // resolvedAt in-process. This is the correct approach because resolvedAt can
    // be much more recent than createdAt — using createdAt as a proxy would delete
    // rows whose report was resolved recently but created long ago.
    //
    // hasResolvedAt=true is the critical guard: rows with NULL resolvedAt represent
    // unresolved safety reports that must NEVER be deleted by the sweep.
    const allFlaggedResolvedRows = await this.checkIns.listForRetentionSweep({
      status: 'flagged',
      // Use a far-future date so the createdAt < olderThan filter passes for
      // all rows — the real retention gate is on resolvedAt, applied below.
      // We must fetch all flagged-resolved rows regardless of createdAt because
      // a row could have been created years ago but resolved recently.
      olderThan: new Date(8_640_000_000_000_000), // max valid JS Date (year 275760)
      hasResolvedAt: true,
    });

    const flaggedResolvedRows = allFlaggedResolvedRows.filter(
      (row) =>
        row.resolvedAt !== null && row.resolvedAt.getTime() < flaggedResolvedCutoff.getTime(),
    );

    let flaggedResolvedDeleted = 0;
    for (const row of flaggedResolvedRows) {
      await this.unitOfWork.run(async (ctx) => {
        await this.checkIns.deleteById(row.id, ctx);
        await this.recordAuditEvent.execute(
          {
            checkInId: row.id,
            userId: row.userId,
            eventId: row.eventId,
            reason: 'deleted_by_retention',
            occurredAt: now,
          },
          ctx,
        );
      });
      flaggedResolvedDeleted++;
    }

    return { pendingDeleted, okDeleted, flaggedResolvedDeleted };
  }
}
