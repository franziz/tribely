import { getRequestContext } from '../context/request-context.js';
import { unwrapTx } from '../db/prisma-unit-of-work.js';
import type { TxContext } from '../db/unit-of-work.port.js';
import { logger } from '../middleware/logger.js';
import type { DomainEvent } from './domain-event.js';
import type { EventPublisher } from './event-publisher.port.js';

/**
 * Production EventPublisher impl. Writes events to the `outbox_events` table
 * inside the supplied TxContext, so event persistence is atomic with the
 * data change that produced it. The OutboxDispatcher polls the table and
 * forwards events to registered consumers.
 *
 * Audit correlation: reads the AsyncLocalStorage request-context frame
 * (opened by `requestContext` middleware on HTTP, or `runAsSystem` on
 * boot/cron) and persists `requestId` + `actorUserId` onto each outbox row.
 * The dispatcher later re-establishes the same context for downstream
 * consumers — Kafka's "headers" pattern in Postgres form.
 *
 * If `getRequestContext()` returns null we log a WARN and persist nulls.
 * That signals a publish path not wrapped in a context frame — almost
 * certainly a bug (boot code that forgot `runAsSystem`, a test that didn't
 * mock the middleware). The audit trail still records the event without
 * correlation; the WARN surfaces the offending call site.
 */
export class OutboxEventPublisher implements EventPublisher {
  async publish(ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    if (events.length === 0) return;
    const requestContext = getRequestContext();
    if (!requestContext) {
      logger.warn(
        { eventCount: events.length, eventTypes: events.map((e) => e.type) },
        'OutboxEventPublisher.publish called outside a request context — wrap callers in runWithContext or runAsSystem',
      );
    }
    const requestId = requestContext?.requestId ?? null;
    const actorUserId = requestContext?.actorUserId ?? null;

    const tx = unwrapTx(ctx);
    await tx.outboxEvent.createMany({
      data: events.map((event) => ({
        type: event.type,
        aggregateType: event.aggregateType,
        aggregateId: event.aggregateId,
        payload: event.payload as object,
        requestId,
        actorUserId,
      })),
    });
  }
}
