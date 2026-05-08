import type { TxContext } from '../db/unit-of-work.port.js';
import type { DomainEvent } from './domain-event.js';

/**
 * Outbound port from the domain perspective. Application services call this
 * to publish events. Implementations decide how delivery happens — the
 * production impl writes to the transactional outbox so publication is
 * atomic with the data change that produced the event.
 *
 * The `ctx` parameter is required: events must be published inside the same
 * transaction as the writes that produced them, otherwise we lose atomicity.
 */
export interface EventPublisher {
  publish(ctx: TxContext, ...events: DomainEvent[]): Promise<void>;
}
