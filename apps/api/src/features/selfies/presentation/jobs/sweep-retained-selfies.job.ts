import { runAsSystem } from '@/core/context/system-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { SweepRetainedSelfiesUseCase } from '../../application/usecases/sweep-retained-selfies.usecase.js';

export interface SweepRetainedSelfiesJobDeps {
  sweepUseCase: SweepRetainedSelfiesUseCase;
  intervalMs: number;
  logger: Logger;
}

/**
 * Scheduled job that calls SweepRetainedSelfiesUseCase on a fixed interval.
 * Driven by the PDPA selfie retention policy: selfies approved or rejected ≥ 30
 * days ago must be permanently deleted (storage + DB status flip + audit row).
 *
 * Design choices:
 * - start() is idempotent — calling it twice is a no-op (mirrors OutboxDispatcher).
 * - Each tick is wrapped in runAsSystem so the ALS frame is set; the publisher
 *   persists `requestId=system:cron.sweep-retained-selfies:<cuid>` for audit
 *   chain integrity.
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
export class SweepRetainedSelfiesJob {
  private readonly sweepUseCase: SweepRetainedSelfiesUseCase;
  private readonly intervalMs: number;
  private readonly logger: Logger;

  private timer: ReturnType<typeof setInterval> | undefined;
  private tickRunning = false;
  // Expose for tests that need to await the in-flight tick settling.
  private tickSettled: Promise<void> = Promise.resolve();

  constructor(deps: SweepRetainedSelfiesJobDeps) {
    this.sweepUseCase = deps.sweepUseCase;
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
      await runAsSystem('cron.sweep-retained-selfies', async () => {
        const result = await this.sweepUseCase.execute();
        this.logger.info(
          {
            evaluated: result.evaluated,
            deleted: result.deleted,
            failed: result.failed,
            reaperRetried: result.reaperRetried,
            reaperSucceeded: result.reaperSucceeded,
            durationMs: result.durationMs,
          },
          'Selfie retention sweep complete',
        );
      });
    } catch (err) {
      this.logger.warn({ err }, 'Selfie retention sweep — tick failed');
    } finally {
      this.tickRunning = false;
    }
  }
}
