import { logger } from '../middleware/logger.js';
import type { DomainEvent } from './domain-event.js';
import type { EventBus, EventHandler } from './event-bus.port.js';

export class InProcessEventBus implements EventBus {
  private readonly handlers = new Map<string, Set<EventHandler>>();

  async dispatch(event: DomainEvent): Promise<void> {
    const subscribers = this.handlers.get(event.type);
    if (!subscribers || subscribers.size === 0) return;

    for (const handler of subscribers) {
      try {
        await handler(event);
      } catch (err) {
        logger.error(
          { err, eventType: event.type, aggregateId: event.aggregateId },
          'Event handler failed',
        );
      }
    }
  }

  subscribe<TEvent extends DomainEvent>(
    eventType: TEvent['type'],
    handler: EventHandler<TEvent>,
  ): () => void {
    let subscribers = this.handlers.get(eventType);
    if (!subscribers) {
      subscribers = new Set();
      this.handlers.set(eventType, subscribers);
    }
    subscribers.add(handler as EventHandler);

    return () => {
      this.handlers.get(eventType)?.delete(handler as EventHandler);
    };
  }
}
