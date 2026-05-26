import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getRequestContext } from '@/core/context/request-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { SweepResolvedReportsResult } from '../../application/dto/sweep-resolved-reports.result.js';
import type { SweepResolvedReportsUseCase } from '../../application/usecases/sweep-resolved-reports.usecase.js';
import { SweepResolvedReportsJob } from './sweep-resolved-reports.job.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

interface CapturedExecuteCall {
  requestId: string | null | undefined;
}

/**
 * Minimal interface satisfied by FakeSweepUseCase. The job only calls
 * `.execute()` — using the full concrete class type in the constructor would
 * require the fake to carry private fields (unitOfWork, reports, auditRepo, etc.)
 * that are irrelevant here. The cast in buildJob() uses `as unknown as
 * SweepResolvedReportsUseCase` — the same pattern as the prune job tests.
 */
interface ExecutableUseCase {
  execute(): Promise<SweepResolvedReportsResult>;
}

class FakeSweepUseCase implements ExecutableUseCase {
  readonly calls: CapturedExecuteCall[] = [];
  private result: SweepResolvedReportsResult = {
    evaluated: 0,
    deleted: 0,
    failed: 0,
    auditRowsSevered: 0,
    orphanRowsSevered: 0,
    durationMs: 0,
  };
  shouldThrow = false;

  setResult(r: SweepResolvedReportsResult): void {
    this.result = r;
  }

  execute(): Promise<SweepResolvedReportsResult> {
    // Capture the requestId from ALS so the runAsSystem assertion can check it.
    this.calls.push({ requestId: getRequestContext()?.requestId });
    if (this.shouldThrow) {
      return Promise.reject(new Error('sweep failed'));
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

function buildJob(sweepUseCase: FakeSweepUseCase, logger: FakeLogger): SweepResolvedReportsJob {
  return new SweepResolvedReportsJob({
    sweepUseCase: sweepUseCase as unknown as SweepResolvedReportsUseCase,
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

describe('SweepResolvedReportsJob', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('start() is idempotent — calling it twice does not double-schedule', async () => {
    const useCase = new FakeSweepUseCase();
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

  it('tick errors are logged WARN and do not stop subsequent ticks', async () => {
    const useCase = new FakeSweepUseCase();
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

  it('stop() awaits in-flight tick before returning', async () => {
    const useCase = new FakeSweepUseCase();
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

  it('tick wraps the use case in runAsSystem — requestId has system:cron.sweep-resolved-reports prefix', async () => {
    const useCase = new FakeSweepUseCase();
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
    expect(call?.requestId).toMatch(/^system:cron\.sweep-resolved-reports:/);

    await job.stop();
  });
});
