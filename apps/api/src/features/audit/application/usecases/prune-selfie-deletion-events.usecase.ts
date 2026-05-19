import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { SelfieDeletionEventRepository } from '../../domain/repositories/selfie-deletion-event.repository.js';

export interface PruneSelfieDeletionEventsResult {
  pruned: number;
  cutoff: Date;
  durationMs: number;
}

/**
 * Subtracts `months` calendar months from `date`.
 *
 * Clamps the day to the last valid day of the resulting month (e.g.
 * 2028-03-31 minus 1 month → 2028-02-29, not the invalid 2028-02-31).
 * No external dep required — the logic is 8 lines.
 */
function subtractMonths(date: Date, months: number): Date {
  const result = new Date(date);
  const targetMonth = result.getMonth() - months;
  result.setMonth(targetMonth);
  // If the day overflowed into the next month (e.g. Jan 31 → Mar 3 when
  // subtracting 0 full months), back up to the last day of the intended month.
  // This happens because setMonth keeps the original day value; if that day
  // doesn't exist in the target month, JS rolls over to the next month.
  // We detect the roll-over by checking whether the resulting month equals
  // the intended month modulo 12.
  const intendedMonth = ((targetMonth % 12) + 12) % 12;
  if (result.getMonth() !== intendedMonth) {
    // The day was clamped past the end-of-month — back up to day 0 of the
    // current month, which yields the last day of the previous month.
    result.setDate(0);
  }
  return result;
}

const RETENTION_MONTHS = 24;

/**
 * Removes selfie-deletion audit rows whose `deletedAt` is older than 24
 * calendar months from now. Driven by the PDPA s25 retention policy: records
 * must be kept for evidence purposes, but must also be pruned once the
 * retention window closes.
 *
 * Returns `{ pruned, cutoff, durationMs }` for the caller (cron job or ops
 * script) to log and alert on.
 */
export class PruneSelfieDeletionEventsUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly repository: SelfieDeletionEventRepository,
    private readonly clock: Clock,
  ) {}

  async execute(): Promise<PruneSelfieDeletionEventsResult> {
    const now = this.clock.now();
    const cutoff = subtractMonths(now, RETENTION_MONTHS);
    const startMs = Date.now();
    const pruned = await this.unitOfWork.run((ctx) => this.repository.pruneOlderThan(cutoff, ctx));
    const durationMs = Date.now() - startMs;
    return { pruned, cutoff, durationMs };
  }
}
