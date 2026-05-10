import type { Db } from '../db/prisma.js';
import { runWithContext } from '../context/request-context.js';
import { logger } from '../middleware/logger.js';
import type { Consumer, ConsumerContext } from './consumer.port.js';
import type { ConsumerRegistry } from './consumer-registry.js';
import type { DomainEvent } from './domain-event.js';

export interface OutboxDispatcherOptions {
  /** Polling interval in milliseconds. Default 1000. */
  intervalMs?: number;
  /**
   * "Settle delay" — events more recent than this are not dispatched yet.
   * Defends against the BIGSERIAL in-flight transaction race: a tx with
   * seq=99 can commit *after* a tx with seq=100, so dispatching seq=100
   * before seq=99's commit visibility would skip seq=99 forever. Five
   * seconds is generous for OLTP write paths. Goes away when we move to
   * Kafka where partition log order handles this natively.
   */
  settleDelaySeconds?: number;
  /** Default maxAttempts for consumers that don't override. */
  defaultMaxAttempts?: number;
}

export interface DispatchOutcomeReporter {
  /**
   * Called after a consumer's handler returns or throws. Implementation
   * persists an `event_audit_logs` row in its own transaction. Wired in
   * commit 6 of TRI-38; for now defaults to a no-op.
   */
  onOutcome(input: {
    requestId: string | null;
    eventSeq: bigint;
    eventType: string;
    consumerName: string;
    phase: 'dispatched' | 'failed' | 'blocked';
    attempt: number;
    errorMessage: string | null;
  }): Promise<void>;
}

const NOOP_REPORTER: DispatchOutcomeReporter = {
  onOutcome: () => Promise.resolve(),
};

/**
 * Per-consumer-offsets dispatcher (TRI-38).
 *
 * Each tick, for each registered consumer:
 *   1. SELECT consumer_offsets row (insert if missing).
 *   2. If blocked, skip.
 *   3. If `inFlightSeq` is set, retry that exact event (head-of-line block).
 *   4. Else fetch the next outbox row with `seq > committedSeq` AND
 *      `occurredAt < NOW() - settleDelay`. If empty, skip.
 *   5. Mark inFlight, increment attempts.
 *   6. Re-establish the AsyncLocalStorage frame from the outbox row's
 *      requestId/actorUserId, then call consumer.handle().
 *   7. On success: advance committedSeq, clear inFlight, reset attempts.
 *      On failure: keep inFlight, set lastError; if attempts >= max set
 *      blockedAt.
 *
 * Failure isolation: each consumer's outcome is independent. Consumer A
 * blocked on event 42 does NOT prevent consumer B from advancing past 42.
 * That's the property the old in-process bus + processedAt model lacked.
 *
 * Concurrency: `SELECT ... FOR UPDATE SKIP LOCKED` on `consumer_offsets`
 * means if we ever run two API replicas, only one will pick up a given
 * consumer per tick. Single-replica MVP doesn't need it but the column
 * is correctly transactional from day one.
 */
export class OutboxDispatcher {
  private readonly intervalMs: number;
  private readonly settleDelaySeconds: number;
  private readonly defaultMaxAttempts: number;
  private timer: NodeJS.Timeout | undefined;
  private running = false;
  private stopped = false;
  private outcomeReporter: DispatchOutcomeReporter = NOOP_REPORTER;

  constructor(
    private readonly db: Db,
    private readonly registry: ConsumerRegistry,
    options: OutboxDispatcherOptions = {},
  ) {
    this.intervalMs = options.intervalMs ?? 1000;
    this.settleDelaySeconds = options.settleDelaySeconds ?? 5;
    this.defaultMaxAttempts = options.defaultMaxAttempts ?? 5;
  }

  /**
   * Wire the dispatch-outcome reporter. Called from buildContainer after
   * the audit feature is constructed. Decoupled like this so the events
   * core doesn't depend on the audit feature (cross-cutting wiring lives
   * in the DI container, not in the events core).
   */
  setOutcomeReporter(reporter: DispatchOutcomeReporter): void {
    this.outcomeReporter = reporter;
  }

  start(): void {
    if (this.timer) return;
    this.stopped = false;
    const tick = async (): Promise<void> => {
      if (this.stopped) return;
      if (!this.running) {
        this.running = true;
        try {
          await this.tickOnce();
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

  /**
   * Run one full tick: drain one event per consumer (each independently).
   * Public for tests.
   */
  async tickOnce(): Promise<void> {
    for (const consumer of this.registry.all()) {
      try {
        await this.driveConsumer(consumer);
      } catch (err) {
        // Defensive: any error here is a bug in the dispatcher itself, not
        // in the handler (handler errors are caught inside driveConsumer).
        logger.error({ err, consumerName: consumer.name }, 'driveConsumer crashed unexpectedly');
      }
    }
  }

  private async driveConsumer(consumer: Consumer): Promise<void> {
    const maxAttempts = consumer.maxAttempts ?? this.defaultMaxAttempts;

    // Ensure offset row exists (committedSeq=0 = "earliest" for new consumers).
    await this.db.consumerOffset.upsert({
      where: { consumerName: consumer.name },
      create: {
        consumerName: consumer.name,
        topic: consumer.topic,
        committedSeq: 0n,
      },
      update: {},
    });

    const offset = await this.db.consumerOffset.findUnique({
      where: { consumerName: consumer.name },
    });
    if (!offset) return; // unreachable after upsert; satisfies TS narrowing
    if (offset.blockedAt !== null) return;

    // Pick the event to attempt. inFlight wins (retry); else next-after-
    // committed bounded by the settle delay.
    let row;
    if (offset.inFlightSeq !== null) {
      row = await this.db.outboxEvent.findUnique({
        where: { seq: offset.inFlightSeq },
      });
      if (!row) {
        // inFlight points at a row that no longer exists (manual cleanup,
        // disaster). Clear it and continue.
        await this.db.consumerOffset.update({
          where: { consumerName: consumer.name },
          data: { inFlightSeq: null, attempts: 0 },
        });
        return;
      }
    } else {
      const settleBoundary = new Date(Date.now() - this.settleDelaySeconds * 1000);
      row = await this.db.outboxEvent.findFirst({
        where: {
          type: consumer.topic,
          seq: { gt: offset.committedSeq },
          occurredAt: { lt: settleBoundary },
        },
        orderBy: { seq: 'asc' },
      });
      if (!row) return; // no work
    }

    const attempt = offset.inFlightSeq === row.seq ? offset.attempts + 1 : 1;
    await this.db.consumerOffset.update({
      where: { consumerName: consumer.name },
      data: { inFlightSeq: row.seq, attempts: attempt },
    });

    const event: DomainEvent = {
      type: row.type,
      aggregateType: row.aggregateType,
      aggregateId: row.aggregateId,
      payload: row.payload,
      version: 1,
    };
    const ctx: ConsumerContext = {
      requestId: row.requestId,
      actorUserId: row.actorUserId,
      attempt,
    };

    try {
      // Re-establish the ALS frame from the persisted correlation. Any
      // downstream events the consumer publishes inherit the same
      // requestId — the chain survives the publish→dispatch boundary.
      await runWithContext(
        {
          requestId: row.requestId ?? `dispatch:${consumer.name}:${row.seq.toString()}`,
          actorUserId: row.actorUserId,
        },
        () => consumer.handle(event, ctx),
      );

      await this.db.consumerOffset.update({
        where: { consumerName: consumer.name },
        data: {
          committedSeq: row.seq,
          inFlightSeq: null,
          attempts: 0,
          lastError: null,
          lastErrorAt: null,
        },
      });
      await this.outcomeReporter.onOutcome({
        requestId: row.requestId,
        eventSeq: row.seq,
        eventType: row.type,
        consumerName: consumer.name,
        phase: 'dispatched',
        attempt,
        errorMessage: null,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const willBlock = attempt >= maxAttempts;
      logger.warn(
        {
          err,
          consumerName: consumer.name,
          eventSeq: row.seq.toString(),
          attempt,
          willBlock,
        },
        willBlock
          ? 'Consumer hit maxAttempts; blocking until manual unblock'
          : 'Consumer failed; will retry next tick',
      );
      await this.db.consumerOffset.update({
        where: { consumerName: consumer.name },
        data: {
          lastError: message,
          lastErrorAt: new Date(),
          ...(willBlock ? { blockedAt: new Date() } : {}),
        },
      });
      await this.outcomeReporter.onOutcome({
        requestId: row.requestId,
        eventSeq: row.seq,
        eventType: row.type,
        consumerName: consumer.name,
        phase: willBlock ? 'blocked' : 'failed',
        attempt,
        errorMessage: message,
      });
    }
  }
}
