import type { DomainEvent } from './domain-event.js';

export type EventHandler<TEvent extends DomainEvent = DomainEvent> = (
  event: TEvent,
) => Promise<void> | void;

/**
 * Inbound dispatch port: the OutboxDispatcher pushes events into this bus,
 * subscribers receive them. Today the impl is in-process; tomorrow it can
 * be replaced with a NATS/Kafka-backed adapter without changing subscribers.
 */
export interface EventBus {
  dispatch(event: DomainEvent): Promise<void>;
  subscribe<TEvent extends DomainEvent>(
    eventType: TEvent['type'],
    handler: EventHandler<TEvent>,
  ): () => void;
}
