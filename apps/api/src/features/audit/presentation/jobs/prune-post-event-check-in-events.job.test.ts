import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getRequestContext } from '@/core/context/request-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { PrunePostEventCheckInEventsResult } from '../../application/dto/prune-post-event-check-in-events.result.js';
import type { PrunePostEventCheckInEventsUseCase } from '../../application/usecases/prune-post-event-check-in-events.usecase.js';
import { PrunePostEventCheckInEventsJob } from './prune-post-event-check-in-events.job.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

interface CapturedExecuteCall {
  requestId: string | null | undefined;
}

/**
 * Minimal interface satisfied by FakePruneUseCase. The job only calls
 * `.execute()` — using the full concrete class type in the constructor would
 * require the fake to carry private fields (unitOfWork, repository, clock)
 * that are irrelevant here. The cast in buildJob() uses `as unknown as
 * PrunePostEventCheckInEventsUseCase` — the same pattern as
 * prune-selfie-deletion-events.job.test.ts.
 */
interface ExecutableUseCase {
  execute(): Promise<PrunePostEventCheckInEventsResult>;
}

class FakePruneUseCase implements ExecutableUseCase {
  readonly calls: CapturedExecuteCall[] = [];
  private result: PrunePostEventCheckInEventsResult = {
    pruned: 0,
    cutoff: new Date('2026-01-01T00:00:00Z'),
    durationMs: 1,
  };
  shouldThrow = false;

  setResult(r: PrunePostEventCheckInEventsResult): void {
    this.result = r;
  }

  execute(): Promise<PrunePostEventCheckInEventsResult> {
    // Capture the requestId from ALS so the runAsSystem assertion can check it.
    this.calls.push({ requestId: getRequestContext()?.requestId });
    if (this.shouldThrow) {
      return Promise.reject(new Error('prune failed'));
    }
    return Promise.resolve(this.result);
  }
}

class FakeLogger implements Logger {
  readonly infoLines: Array<{ payload: Record<string, unknown>; message: string }> = [];
  readonly warnLines: Array<{ payload: Record<string, unknown>; message: string }> = [];
  readonly errorLines: Array<{ payload: Record<string, unknown>; message: string }> = [];

  info(payload: Record<string, unknown>, message: string): void {
    this.infoLines.push({ payload, message });
  }
  warn(payload: Record<string, unknown>, message: string): void {
    this.warnLines.push({ payload, message });
  }
  error(payload: Record<string, unknown>, message: string): void {
    this.errorLines.push({ payload, message });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const INTERVAL_MS = 1_000;

function buildJob(
  pruneUseCase: FakePruneUseCase,
  logger: FakeLogger,
): PrunePostEventCheckInEventsJob {
  return new PrunePostEventCheckInEventsJob({
    pruneUseCase: pruneUseCase as unknown as PrunePostEventCheckInEventsUseCase,
    intervalMs: INTERVAL_MS,
    logger,
  });
}

/**
 * Flush all pending microtasks (resolved promise continuations) without
 * advancing the fake clock. Safe to call with setInterval jobs because it
 * does NOT re-trigger the interval — it only drains the microtask queue.
 */
async function flushMicrotasks(): Promise<void> {
  await Promise.resolve();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PrunePostEventCheckInEventsJob', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('start() schedules an interval — first tick does not fire immediately', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();

    expect(useCase.calls).toHaveLength(0);

    await job.stop();
  });

  it('tick calls the use case after one interval elapses', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBeGreaterThanOrEqual(1);
    await job.stop();
  });

  it('tick is wrapped in runAsSystem — requestId has system:cron.prune-post-event-check-in-events prefix', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBeGreaterThanOrEqual(1);
    const call = useCase.calls[0];
    expect(call).toBeDefined();
    expect(typeof call?.requestId).toBe('string');
    expect(call?.requestId).toMatch(/^system:cron\.prune-post-event-check-in-events:/);

    await job.stop();
  });

  it('logs INFO with pruned, cutoff, durationMs on success', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const cutoff = new Date('2026-01-01T00:00:00Z');
    useCase.setResult({ pruned: 5, cutoff, durationMs: 99 });

    const job = buildJob(useCase, logger);
    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    const infoLine = logger.infoLines.find((l) =>
      l.message.includes('Post-event check-in audit sweep complete'),
    );
    expect(infoLine).toBeDefined();
    expect(infoLine?.payload).toMatchObject({
      pruned: 5,
      cutoff: cutoff.toISOString(),
    });

    await job.stop();
  });

  it('stop() clears the interval — no further ticks fire after stop', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();
    const countAfterFirstTick = useCase.calls.length;

    await job.stop();

    vi.advanceTimersByTime(INTERVAL_MS * 5);
    await flushMicrotasks();

    expect(useCase.calls.length).toBe(countAfterFirstTick);
  });

  it('tick errors are logged WARN and do not stop subsequent ticks', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    useCase.shouldThrow = true;

    const job = buildJob(useCase, logger);
    job.start();

    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(logger.warnLines.length).toBeGreaterThanOrEqual(1);
    const warnLine = logger.warnLines[0];
    expect(warnLine).toBeDefined();
    expect(warnLine?.payload).toHaveProperty('err');

    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBeGreaterThanOrEqual(2);

    await job.stop();
  });

  it('start() is idempotent — calling it twice does not double-schedule', async () => {
    const useCase = new FakePruneUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    job.start(); // second call must be a no-op

    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBe(1);

    await job.stop();
  });
});
