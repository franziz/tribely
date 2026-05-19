/**
 * Shared test doubles for core/ ports.
 *
 * Every symbol here implements a `core/` (or cross-cutting) port and carries
 * no feature-specific seed helpers.  Feature-owned repository fakes (e.g.
 * FakeEventRepository, FakeUserRepository) belong in the owning feature's
 * `application/usecases/fakes.ts` file — they implement feature-owned
 * interfaces and know the aggregate's internal shape.
 *
 * Placement rationale: a fake that implements a core port is used across
 * multiple features.  Hosting it inside one feature's application layer creates
 * a cross-feature `application/usecases/` re-export, which violates the A11
 * bounded-context rule.  `core/testing/` is the canonical home.
 */
import type { TxContext, UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';

/** Opaque TxContext marker for use in unit tests. */
export const TEST_TX: TxContext = { __brand: 'TxContext' };

/** Fake UnitOfWork that executes work synchronously in the same callstack. */
export class FakeUnitOfWork implements UnitOfWork {
  async run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T> {
    return work(TEST_TX);
  }
}

/** Fake EventPublisher that accumulates published events for assertion. */
export class FakeEventPublisher implements EventPublisher {
  readonly published: DomainEvent[] = [];
  publish(_ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    this.published.push(...events);
    return Promise.resolve();
  }
}

/**
 * Deterministic Clock implementation.
 *
 * Note: Clock is defined in `features/auth/domain/ports/` but is a
 * cross-cutting concern used across events, join-requests, and auth.  Until
 * Clock is promoted to `core/`, its fake lives here to avoid cross-feature
 * application-layer re-exports.
 */
export class FixedClock implements Clock {
  constructor(private current: Date) {}
  now(): Date {
    return this.current;
  }
  advance(ms: number): void {
    this.current = new Date(this.current.getTime() + ms);
  }
  set(at: Date): void {
    this.current = at;
  }
}
