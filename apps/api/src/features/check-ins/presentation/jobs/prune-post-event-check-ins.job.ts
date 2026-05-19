import { runAsSystem } from '@/core/context/system-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { PrunePostEventCheckInsUseCase } from '../../application/usecases/prune-post-event-check-ins.usecase.js';

export interface PrunePostEventCheckInsJobDeps {
  pruneUseCase: PrunePostEventCheckInsUseCase;
  intervalMs: number;
  logger: Logger;
}

/**
 * Scheduled job that calls PrunePostEventCheckInsUseCase on a fixed interval.
 * Driven by the PDPA retention policy for post-event check-in records:
 *   - `pending`  rows older than 30 days (createdAt) are deleted.
 *   - `ok`       rows older than 90 days (createdAt) are deleted.
 *   - `flagged`  rows with resolvedAt > 12 months ago are deleted.
 *     `flagged` rows with resolvedAt IS NULL are NEVER deleted.
 *
 * Design choices:
 * - start() is idempotent — calling it twice is a no-op (mirrors OutboxDispatcher).
 * - Each tick is wrapped in runAsSystem so the ALS frame is set; the publisher
 *   persists `requestId=system:cron.prune-post-event-check-ins:<cuid>` for
 *   audit chain integrity.
 * - Tick errors are logged WARN and swallowed — one failed sweep does not stop
 *   the scheduler. The next tick will retry.
 * - stop() clears the interval and awaits any in-flight tick before returning.
 *
 * Single-instance assumption: setInterval is sufficient for the Singapore v1
 * launch (single-process deploy). Multi-instance scaling path is
 * `pg_try_advisory_lock(...)` here — do not implement now.
 *
 * NOT a generic job scheduler abstraction. Two-job-minimum-before-abstraction rule.
 */
export class PrunePostEventCheckInsJob {
  private readonly pruneUseCase: PrunePostEventCheckInsUseCase;
  private readonly intervalMs: number;
  private readonly logger: Logger;

  private timer: ReturnType<typeof setInterval> | undefined;
  private tickRunning = false;
  // Expose for tests that need to await the in-flight tick settling.
  private tickSettled: Promise<void> = Promise.resolve();

  constructor(deps: PrunePostEventCheckInsJobDeps) {
    this.pruneUseCase = deps.pruneUseCase;
    this.intervalMs = deps.intervalMs;
    this.logger = deps.logger;
  }

  /**
   * Start the sweep scheduler. Idempotent — returns early if a timer is
   * already running. First tick fires after one full interval (not immediately).
   */
  start(): void {
    if (this.timer !== undefined) return;

    this.timer = setInterval(() => {
      this.tickSettled = this.runTick();
    }, this.intervalMs);
  }

  /**
   * Stop the scheduler and wait for any in-flight tick to settle before
   * returning. Mirrors OutboxDispatcher.stop() shape.
   */
  async stop(): Promise<void> {
    if (this.timer !== undefined) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
    // Wait for an in-flight tick to finish if one is running.
    await this.tickSettled;
  }

  private async runTick(): Promise<void> {
    if (this.tickRunning) return;
    this.tickRunning = true;
    try {
      await runAsSystem('cron.prune-post-event-check-ins', async () => {
        const result = await this.pruneUseCase.execute();
        this.logger.info(
          {
            pendingDeleted: result.pendingDeleted,
            okDeleted: result.okDeleted,
            flaggedResolvedDeleted: result.flaggedResolvedDeleted,
          },
          'Post-event check-in retention sweep complete',
        );
      });
    } catch (err) {
      this.logger.warn({ err }, 'Post-event check-in retention sweep — tick failed');
    } finally {
      this.tickRunning = false;
    }
  }
}
