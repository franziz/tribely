import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { Event } from '../../domain/entities/event.js';
import type {
  EventRepository,
  ListEventsCursor,
  ListEventsFilters,
  ListEventsPage,
} from '../../domain/repositories/event.repository.js';

// Core-port fakes — shared across features. Re-exported here for convenience
// so existing events test imports remain at `./fakes.js`.
export { FakeEventPublisher, FakeUnitOfWork, FixedClock, TEST_TX } from '@/core/testing/fakes.js';

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

  findByVerifiedPhone(phone: PhoneNumber): Promise<User | null> {
    for (const user of this.byId.values()) {
      if (user.phone?.value === phone.value && user.phoneVerifiedAt !== null) {
        return Promise.resolve(user);
      }
    }
    return Promise.resolve(null);
  }

  save(user: User): Promise<void> {
    this.byId.set(user.id, user);
    return Promise.resolve();
  }
}

export class FakeGetUserCapabilitiesUseCase {
  private _canPostPrivateVenue = false;
  private _canPerformVerifiedAction = false;
  setCanPostPrivateVenue(v: boolean): void {
    this._canPostPrivateVenue = v;
  }
  setCanPerformVerifiedAction(v: boolean): void {
    this._canPerformVerifiedAction = v;
  }
  execute(_input: {
    userId: string;
  }): Promise<{ canPostPrivateVenue: boolean; canPerformVerifiedAction: boolean }> {
    return Promise.resolve({
      canPostPrivateVenue: this._canPostPrivateVenue,
      canPerformVerifiedAction: this._canPerformVerifiedAction,
    });
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

  lastFindByIdCtx: TxContext | undefined = undefined;

  findById(id: string, ctx?: TxContext): Promise<Event | null> {
    this.lastFindByIdCtx = ctx;
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

  countCompletedByHost(hostUserId: string): Promise<number> {
    const count = Array.from(this.byId.values()).filter(
      (e) => e.hostUserId === hostUserId && e.status === 'completed',
    ).length;
    return Promise.resolve(count);
  }

  pseudonymiseHostForUser(
    userId: string,
    pseudonymHostId: string,
    _ctx: TxContext,
  ): Promise<number> {
    let count = 0;
    for (const event of this.byId.values()) {
      if (event.hostUserId === userId) {
        // Mutate the readonly field via Object.defineProperty — acceptable in
        // a test double where no domain invariants need enforcement.
        Object.defineProperty(event, 'hostUserId', {
          value: pseudonymHostId,
          writable: true,
          configurable: true,
        });
        count += 1;
      }
    }
    return Promise.resolve(count);
  }

  findCompletedForUserBetween(
    input: { userId: string; completedAfter: Date; completedBefore: Date },
    _ctx?: TxContext,
  ): Promise<Event[]> {
    // In the fake we cannot join join_requests — host-side participation only.
    // Callers that need the joiner path must use the integration repo.
    const rows = Array.from(this.byId.values()).filter(
      (e) =>
        e.status === 'completed' &&
        e.endsAt.getTime() > input.completedAfter.getTime() &&
        e.endsAt.getTime() <= input.completedBefore.getTime() &&
        e.hostUserId === input.userId,
    );
    return Promise.resolve(rows);
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
      .filter((e) => filters.hostUserId === undefined || e.hostUserId === filters.hostUserId)
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
