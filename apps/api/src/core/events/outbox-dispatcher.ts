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
  private timer?: NodeJS.Timeout;
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

  private async drainOnce(): Promise<void> {
    const events = await this.db.outboxEvent.findMany({
      where: { processedAt: null, attempts: { lt: this.maxAttempts } },
      orderBy: { occurredAt: 'asc' },
      take: this.batchSize,
    });
    if (events.length === 0) return;

    for (const row of events) {
      try {
        await this.bus.dispatch({
          type: row.type,
          aggregateType: row.aggregateType,
          aggregateId: row.aggregateId,
          payload: row.payload as unknown,
          version: 1,
        });
        await this.db.outboxEvent.update({
          where: { id: row.id },
          data: { processedAt: new Date() },
        });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        logger.warn(
          { err, eventId: row.id, type: row.type, attempts: row.attempts + 1 },
          'Outbox dispatch failed; will retry',
        );
        await this.db.outboxEvent.update({
          where: { id: row.id },
          data: { attempts: { increment: 1 }, lastError: message },
        });
      }
    }
  }
}
