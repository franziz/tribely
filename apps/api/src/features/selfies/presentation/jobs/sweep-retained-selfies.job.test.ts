import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getRequestContext } from '@/core/context/request-context.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { SweepRetainedSelfiesResult } from '../../application/dto/sweep-retained-selfies.result.js';
import type { SweepRetainedSelfiesUseCase } from '../../application/usecases/sweep-retained-selfies.usecase.js';
import { SweepRetainedSelfiesJob } from './sweep-retained-selfies.job.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

interface CapturedExecuteCall {
  requestId: string | null | undefined;
}

/**
 * Minimal interface satisfied by FakeSweepUseCase. The job only calls
 * `.execute()` — using the full concrete class type in the constructor would
 * require the fake to carry all constructor dependencies that are irrelevant
 * here. The cast in buildJob() uses `as unknown as SweepRetainedSelfiesUseCase`
 * — the same pattern as FakePrisma in the OutboxDispatcher tests.
 */
interface ExecutableUseCase {
  execute(): Promise<SweepRetainedSelfiesResult>;
}

class FakeSweepUseCase implements ExecutableUseCase {
  readonly calls: CapturedExecuteCall[] = [];
  private result: SweepRetainedSelfiesResult = {
    evaluated: 0,
    deleted: 0,
    failed: 0,
    reaperRetried: 0,
    reaperSucceeded: 0,
    durationMs: 1,
  };
  shouldThrow = false;

  setResult(r: SweepRetainedSelfiesResult): void {
    this.result = r;
  }

  execute(): Promise<SweepRetainedSelfiesResult> {
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

function buildJob(sweepUseCase: FakeSweepUseCase, logger: FakeLogger): SweepRetainedSelfiesJob {
  return new SweepRetainedSelfiesJob({
    sweepUseCase: sweepUseCase as unknown as SweepRetainedSelfiesUseCase,
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

describe('SweepRetainedSelfiesJob', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('start() schedules an interval — first tick does not fire immediately', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();

    // No time has passed yet — use case must not have been called.
    expect(useCase.calls).toHaveLength(0);

    await job.stop();
  });

  it('tick calls the use case after one interval elapses', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    // Advance exactly one interval to fire the setInterval callback once.
    vi.advanceTimersByTime(INTERVAL_MS);
    // Drain the microtask queue so the async runTick() body completes.
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBeGreaterThanOrEqual(1);
    await job.stop();
  });

  it('tick is wrapped in runAsSystem — requestId has system:cron.sweep-retained-selfies prefix', async () => {
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
    expect(call?.requestId).toMatch(/^system:cron\.sweep-retained-selfies:/);

    await job.stop();
  });

  it('logs INFO with result fields on success', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();
    useCase.setResult({
      evaluated: 10,
      deleted: 8,
      failed: 2,
      reaperRetried: 3,
      reaperSucceeded: 2,
      durationMs: 42,
    });

    const job = buildJob(useCase, logger);
    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    const infoLine = logger.infoLines.find((l) =>
      l.message.includes('Selfie retention sweep complete'),
    );
    expect(infoLine).toBeDefined();
    expect(infoLine?.payload).toMatchObject({
      evaluated: 10,
      deleted: 8,
      failed: 2,
      reaperRetried: 3,
      reaperSucceeded: 2,
      durationMs: 42,
    });

    await job.stop();
  });

  it('stop() clears the interval — no further ticks fire after stop', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();
    const job = buildJob(useCase, logger);

    job.start();
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();
    const countAfterFirstTick = useCase.calls.length;

    await job.stop();

    // Advance time further — no new ticks should fire.
    vi.advanceTimersByTime(INTERVAL_MS * 5);
    await flushMicrotasks();

    expect(useCase.calls.length).toBe(countAfterFirstTick);
  });

  it('tick errors are logged WARN and do not stop subsequent ticks', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();
    useCase.shouldThrow = true;

    const job = buildJob(useCase, logger);
    job.start();

    // First tick — throws.
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(logger.warnLines.length).toBeGreaterThanOrEqual(1);
    const warnLine = logger.warnLines[0];
    expect(warnLine).toBeDefined();
    expect(warnLine?.payload).toHaveProperty('err');

    // Second tick — still fires (scheduler not stopped).
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();
    await flushMicrotasks();

    expect(useCase.calls.length).toBeGreaterThanOrEqual(2);

    await job.stop();
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

    // Only one tick should fire per interval even after double start().
    expect(useCase.calls.length).toBe(1);

    await job.stop();
  });

  it('overlap guard — second tick is skipped if first is still running', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();

    // Make the use case block until we release it.
    let releaseFirstTick!: () => void;
    const firstTickLatch = new Promise<SweepRetainedSelfiesResult>((resolve) => {
      releaseFirstTick = () => {
        resolve({
          evaluated: 0,
          deleted: 0,
          failed: 0,
          reaperRetried: 0,
          reaperSucceeded: 0,
          durationMs: 1,
        });
      };
    });
    let callCount = 0;
    useCase.execute = () => {
      callCount++;
      if (callCount === 1) return firstTickLatch;
      return Promise.resolve({
        evaluated: 0,
        deleted: 0,
        failed: 0,
        reaperRetried: 0,
        reaperSucceeded: 0,
        durationMs: 1,
      });
    };

    const job = buildJob(useCase, logger);
    job.start();

    // First tick fires — blocked on the latch.
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();

    // Second interval fires while first is still in-flight.
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();

    // Only one call should have been made so far.
    expect(callCount).toBe(1);

    // Release first tick.
    releaseFirstTick();
    await flushMicrotasks();
    await flushMicrotasks();

    await job.stop();
    // Still only 1 — the second tick was suppressed by the overlap guard.
    expect(callCount).toBe(1);
  });

  it('stop() awaits the in-flight tick before resolving', async () => {
    const useCase = new FakeSweepUseCase();
    const logger = new FakeLogger();

    let released = false;
    let releaseTick!: () => void;
    const tickLatch = new Promise<SweepRetainedSelfiesResult>((resolve) => {
      releaseTick = () => {
        released = true;
        resolve({
          evaluated: 0,
          deleted: 0,
          failed: 0,
          reaperRetried: 0,
          reaperSucceeded: 0,
          durationMs: 1,
        });
      };
    });
    useCase.execute = () => tickLatch;

    const job = buildJob(useCase, logger);
    job.start();

    // Fire the first tick — it blocks.
    vi.advanceTimersByTime(INTERVAL_MS);
    await flushMicrotasks();

    // Begin stopping — should not resolve yet (tick still in-flight).
    let stopResolved = false;
    const stopPromise = job.stop().then(() => {
      stopResolved = true;
    });

    await flushMicrotasks();
    expect(stopResolved).toBe(false);

    // Release the tick — stop() should now resolve.
    releaseTick();
    await flushMicrotasks();
    await flushMicrotasks();
    await stopPromise;

    expect(released).toBe(true);
    expect(stopResolved).toBe(true);
  });
});
