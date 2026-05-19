import { runAsSystem } from '@/core/context/system-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { PruneSelfieDeletionEventsUseCase } from '../../application/usecases/prune-selfie-deletion-events.usecase.js';

export interface PruneSelfieDeletionEventsJobDeps {
  pruneUseCase: PruneSelfieDeletionEventsUseCase;
  intervalMs: number;
  logger: Logger;
}

/**
 * Scheduled job that calls PruneSelfieDeletionEventsUseCase on a fixed
 * interval. Driven by the PDPA s25 retention policy: audit rows whose
 * `deletedAt` exceeds 24 calendar months must be pruned.
 *
 * Design choices:
 * - start() is idempotent — calling it twice is a no-op (mirrors OutboxDispatcher).
 * - Each tick is wrapped in runAsSystem so the ALS frame is set; the publisher
 *   persists `requestId=system:cron.prune-selfie-deletion-events:<cuid>` for
 *   audit chain integrity.
 * - Tick errors are logged WARN and swallowed — one failed sweep does not stop
 *   the scheduler. The next tick will retry.
 * - stop() clears the interval and awaits any in-flight tick before returning.
 *
 * NOT a generic job scheduler abstraction. Two-job-minimum-before-abstraction rule.
 */
export class PruneSelfieDeletionEventsJob {
  private readonly pruneUseCase: PruneSelfieDeletionEventsUseCase;
  private readonly intervalMs: number;
  private readonly logger: Logger;

  private timer: ReturnType<typeof setInterval> | undefined;
  private tickRunning = false;
  // Expose for tests that need to await the in-flight tick settling.
  private tickSettled: Promise<void> = Promise.resolve();

  constructor(deps: PruneSelfieDeletionEventsJobDeps) {
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
      await runAsSystem('cron.prune-selfie-deletion-events', async () => {
        const result = await this.pruneUseCase.execute();
        this.logger.info(
          {
            pruned: result.pruned,
            cutoff: result.cutoff.toISOString(),
            durationMs: result.durationMs,
          },
          'Selfie deletion audit sweep complete',
        );
      });
    } catch (err) {
      this.logger.warn({ err }, 'Selfie deletion audit sweep failed');
    } finally {
      this.tickRunning = false;
    }
  }
}
