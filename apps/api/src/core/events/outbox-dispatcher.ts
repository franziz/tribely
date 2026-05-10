import type { Db } from '../db/prisma.js';
import { logger } from '../middleware/logger.js';
import type { EventBus } from './event-bus.port.js';

export interface OutboxDispatcherOptions {
  /** Polling interval in milliseconds. */
  intervalMs?: number;
  /** Max events to claim per tick. */
  batchSize?: number;
  /** Max attempts before an event is parked (no further retries). */
  maxAttempts?: number;
}

/**
 * Polls the outbox table and dispatches unprocessed events through the EventBus.
 * Guarantees at-least-once delivery — handlers must be idempotent.
 */
export class OutboxDispatcher {
  private readonly intervalMs: number;
  private readonly batchSize: number;
  private readonly maxAttempts: number;
  private timer: NodeJS.Timeout | undefined;
  private running = false;
  private stopped = false;

  constructor(
    private readonly db: Db,
    private readonly bus: EventBus,
    options: OutboxDispatcherOptions = {},
  ) {
    this.intervalMs = options.intervalMs ?? 1000;
    this.batchSize = options.batchSize ?? 50;
    this.maxAttempts = options.maxAttempts ?? 10;
  }

  start(): void {
    if (this.timer) return;
    this.stopped = false;
    const tick = async (): Promise<void> => {
      if (this.stopped) return;
      if (!this.running) {
        this.running = true;
        try {
          await this.drainOnce();
        } catch (err) {
          logger.error({ err }, 'Outbox dispatcher tick failed');
        } finally {
          this.running = false;
        }
      }
      this.timer = setTimeout(tick, this.intervalMs);
    };
    void tick();
  }

  async stop(): Promise<void> {
    this.stopped = true;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = undefined;
    }
    while (this.running) {
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }

  // TRI-38 in-progress: per-consumer-offsets dispatcher arrives in a later
  // commit on this branch. The schema migration (commit 1) already removed
  // processedAt/attempts/lastError from outbox_events, so the old loop
  // below cannot run. We keep `start()`/`stop()` as a NOP for now — boot
  // succeeds, no events dispatch — until commit 5 wires the real loop.
  private drainOnce(): Promise<void> {
    void this.maxAttempts;
    void this.batchSize;
    void this.bus;
    void this.db;
    return Promise.resolve();
  }
}
