import { unwrapTx } from '../db/prisma-unit-of-work.js';
import type { TxContext } from '../db/unit-of-work.port.js';
import type { DomainEvent } from './domain-event.js';
import type { EventPublisher } from './event-publisher.port.js';

/**
 * Production EventPublisher impl. Writes events to the `outbox_events` table
 * inside the supplied TxContext, so event persistence is atomic with the
 * data change that produced it. The OutboxDispatcher polls the table and
 * forwards events to the EventBus.
 */
export class OutboxEventPublisher implements EventPublisher {
  async publish(ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    if (events.length === 0) return;
    const tx = unwrapTx(ctx);
    await tx.outboxEvent.createMany({
      data: events.map((event) => ({
        type: event.type,
        aggregateType: event.aggregateType,
        aggregateId: event.aggregateId,
        payload: event.payload as object,
      })),
    });
  }
}
