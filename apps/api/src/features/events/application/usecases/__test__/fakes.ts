import type { TxContext, UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { Event } from '../../../domain/entities/event.js';
import type {
  EventRepository,
  ListEventsCursor,
  ListEventsFilters,
  ListEventsPage,
} from '../../../domain/repositories/event.repository.js';

/** Marker used by the fake UoW; domain code treats TxContext as opaque. */
const TEST_TX: TxContext = { __brand: 'TxContext' };

export class FakeUnitOfWork implements UnitOfWork {
  async run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T> {
    return work(TEST_TX);
  }
}

export class FakeEventPublisher implements EventPublisher {
  readonly published: DomainEvent[] = [];
  publish(_ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    this.published.push(...events);
    return Promise.resolve();
  }
}

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

export class FakeUserRepository implements UserRepository {
  private readonly byId = new Map<string, User>();

  put(user: User): void {
    this.byId.set(user.id, user);
  }

  findById(id: string): Promise<User | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findByEmail(email: Email): Promise<User | null> {
    for (const user of this.byId.values()) {
      if (user.email.equals(email)) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }

  save(user: User): Promise<void> {
    this.byId.set(user.id, user);
    return Promise.resolve();
  }
}

/**
 * In-memory EventRepository. `findManyForListing` reimplements the same
 * predicates the Prisma adapter uses (status=published, endsAt>now, optional
 * city/category/window, keyset ordering on `(startsAt, id)`) so use case
 * tests can assert filter behaviour without hitting Postgres.
 */
export class FakeEventRepository implements EventRepository {
  private readonly byId = new Map<string, Event>();

  put(event: Event): void {
    this.byId.set(event.id, event);
  }

  all(): Event[] {
    return Array.from(this.byId.values());
  }

  findById(id: string): Promise<Event | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  /**
   * In-memory equivalent of the production `SELECT … FOR UPDATE`. There is no
   * real row lock here — the in-process fake UoW serializes work anyway — so
   * this collapses to the same lookup as `findById`. Kept as a separate method
   * so use case tests can verify the lock path is invoked.
   */
  findByIdForUpdate(id: string): Promise<Event | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  save(event: Event): Promise<void> {
    this.byId.set(event.id, event);
    return Promise.resolve();
  }

  findManyForListing(
    filters: ListEventsFilters,
    cursor: ListEventsCursor | null,
    limit: number,
  ): Promise<ListEventsPage> {
    const filtered = Array.from(this.byId.values())
      .filter((e) => e.status === 'published')
      .filter((e) => e.endsAt.getTime() > filters.now.getTime())
      .filter((e) => filters.city === undefined || e.venue.city === filters.city)
      .filter((e) => filters.category === undefined || e.category.value === filters.category)
      .filter((e) => filters.from === undefined || e.startsAt.getTime() >= filters.from.getTime())
      .filter((e) => filters.to === undefined || e.startsAt.getTime() <= filters.to.getTime())
      .filter((e) => {
        if (!cursor) return true;
        const sa = e.startsAt.getTime();
        const csa = cursor.lastStartsAt.getTime();
        if (sa > csa) return true;
        if (sa === csa) return e.id > cursor.lastEventId;
        return false;
      })
      .sort((a, b) => {
        const delta = a.startsAt.getTime() - b.startsAt.getTime();
        return delta !== 0 ? delta : a.id.localeCompare(b.id);
      });

    const hasMore = filtered.length > limit;
    const page = hasMore ? filtered.slice(0, limit) : filtered;
    const last = page.at(-1);
    const nextCursor: ListEventsCursor | null =
      hasMore && last ? { lastStartsAt: last.startsAt, lastEventId: last.id } : null;
    return Promise.resolve({ events: page, nextCursor });
  }
}
