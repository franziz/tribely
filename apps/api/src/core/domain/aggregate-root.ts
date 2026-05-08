import type { DomainEvent } from '../events/domain-event.js';

/**
 * Base class for aggregate roots.
 *
 * Aggregates record domain events when their state changes. Application
 * services pull events off the aggregate after a successful operation
 * and hand them to the EventPublisher inside the same UnitOfWork —
 * keeping event publication atomic with state change.
 *
 * Why aggregates emit (instead of use cases constructing events from raw data):
 *   - Events are part of the aggregate's invariants. The aggregate is the
 *     authority on what happened to it.
 *   - Use cases stay focused on orchestration, not on knowing every event
 *     shape.
 *   - Refactoring an aggregate's behavior automatically updates what events
 *     it emits — no chance of forgetting.
 */
export abstract class AggregateRoot {
  private readonly events: DomainEvent[] = [];

  protected record(event: DomainEvent): void {
    this.events.push(event);
  }

  pullEvents(): DomainEvent[] {
    const out = [...this.events];
    this.events.length = 0;
    return out;
  }
}
