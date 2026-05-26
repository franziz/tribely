import { runAsSystem } from '@/core/context/system-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { SweepResolvedReportsUseCase } from '../../application/usecases/sweep-resolved-reports.usecase.js';

export interface SweepResolvedReportsJobDeps {
  sweepUseCase: SweepResolvedReportsUseCase;
  intervalMs: number;
  logger: Logger;
}

/**
 * Scheduled job that calls SweepResolvedReportsUseCase on a fixed interval.
 * Driven by the PDPA retention policy for moderation report records:
 *   - Resolved `moderation_reports` older than 12 months are deleted.
 *   - `moderation_action_audit.originatingReportId` cross-references are
 *     severed (NULL'd) when the referenced report row is purged (PDPA s25
 *     cross-reference minimisation).
 *
 * Design choices:
 * - start() is idempotent — calling it twice is a no-op (mirrors OutboxDispatcher).
 * - Each tick is wrapped in runAsSystem so the ALS frame is set; the publisher
 *   persists `requestId=system:cron.sweep-resolved-reports:<cuid>` for
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
export class SweepResolvedReportsJob {
  private readonly sweepUseCase: SweepResolvedReportsUseCase;
  private readonly intervalMs: number;
  private readonly logger: Logger;

  private timer: ReturnType<typeof setInterval> | undefined;
  private tickRunning = false;
  // Expose for tests that need to await the in-flight tick settling.
  private tickSettled: Promise<void> = Promise.resolve();

  constructor(deps: SweepResolvedReportsJobDeps) {
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
      await runAsSystem('cron.sweep-resolved-reports', async () => {
        const result = await this.sweepUseCase.execute();
        this.logger.info(
          {
            evaluated: result.evaluated,
            deleted: result.deleted,
            failed: result.failed,
            auditRowsSevered: result.auditRowsSevered,
            orphanRowsSevered: result.orphanRowsSevered,
            durationMs: result.durationMs,
          },
          'Moderation report retention sweep complete',
        );
      });
    } catch (err) {
      this.logger.warn({ err }, 'Moderation report retention sweep — tick failed');
    } finally {
      this.tickRunning = false;
    }
  }
}
