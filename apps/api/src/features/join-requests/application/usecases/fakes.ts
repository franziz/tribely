import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type {
  JoinRequestRepository,
  ListByRequesterPage,
  ListJoinRequestsByRequesterCursor,
  ListJoinRequestsFilters,
} from '../../domain/repositories/join-request.repository.js';

// Re-export the cross-feature fakes from events so use case tests have a
// single import surface. These are pure infrastructure-free fakes — sharing
// them keeps a fake UoW / publisher / clock semantic identical across
// features (changing the contract in events automatically propagates here).
export {
  FakeEventPublisher,
  FakeEventRepository,
  FakeUnitOfWork,
  FakeUserRepository,
  FixedClock,
  TEST_TX,
} from '../../../events/application/usecases/fakes.js';

/**
 * In-memory JoinRequestRepository.
 *
 * Faithful to the production contract:
 *   - `findActiveByEventAndRequester` returns the (event, requester) row
 *     whose status is pending OR approved (the "active" set the partial
 *     unique index in Postgres protects).
 *   - `countApproved` iterates all stored aggregates — fine for in-process
 *     tests where the FakeUnitOfWork serializes work. Requires `ctx` to
 *     mirror the production type signature (capacity counting is
 *     transaction-bound in real life).
 *   - `save` is an upsert keyed by aggregate id; no race-loser simulation
 *     (the unique-violation path is exercised by the Prisma integration
 *     tests in Wave 2A, not here).
 */
export class FakeJoinRequestRepository implements JoinRequestRepository {
  private readonly byId = new Map<string, JoinRequest>();
  lastFindByIdCtx: TxContext | undefined = undefined;

  put(joinRequest: JoinRequest): void {
    this.byId.set(joinRequest.id, joinRequest);
  }

  all(): JoinRequest[] {
    return Array.from(this.byId.values());
  }

  findById(id: string, ctx?: TxContext): Promise<JoinRequest | null> {
    this.lastFindByIdCtx = ctx;
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findActiveByEventAndRequester(
    eventId: string,
    requesterUserId: string,
    _ctx?: TxContext,
  ): Promise<JoinRequest | null> {
    for (const jr of this.byId.values()) {
      if (
        jr.eventId === eventId &&
        jr.requesterUserId === requesterUserId &&
        (jr.status === 'pending' || jr.status === 'approved')
      ) {
        return Promise.resolve(jr);
      }
    }
    return Promise.resolve(null);
  }

  save(joinRequest: JoinRequest, _ctx?: TxContext): Promise<void> {
    this.byId.set(joinRequest.id, joinRequest);
    return Promise.resolve();
  }

  countApproved(eventId: string, _ctx: TxContext): Promise<number> {
    let count = 0;
    for (const jr of this.byId.values()) {
      if (jr.eventId === eventId && jr.status === 'approved') count += 1;
    }
    return Promise.resolve(count);
  }

  findByEvent(
    eventId: string,
    filters: ListJoinRequestsFilters,
    _ctx?: TxContext,
  ): Promise<JoinRequest[]> {
    const rows = Array.from(this.byId.values())
      .filter((jr) => jr.eventId === eventId)
      .filter(
        (jr) =>
          filters.requesterUserId === undefined || jr.requesterUserId === filters.requesterUserId,
      )
      .filter(
        (jr) =>
          filters.status === undefined ||
          filters.status.length === 0 ||
          filters.status.includes(jr.status),
      )
      // Stable order: oldest-requested first. Lets tests assert order without
      // depending on Map insertion semantics across rehydration paths.
      .sort((a, b) => a.requestedAt.getTime() - b.requestedAt.getTime());
    return Promise.resolve(rows);
  }

  listByRequester(
    requesterUserId: string,
    eventId: string | undefined,
    cursor: ListJoinRequestsByRequesterCursor | null,
    limit: number,
    _ctx?: TxContext,
  ): Promise<ListByRequesterPage> {
    let rows = Array.from(this.byId.values())
      .filter((jr) => jr.requesterUserId === requesterUserId)
      .filter((jr) => eventId === undefined || jr.eventId === eventId)
      .filter((jr) => {
        if (!cursor) return true;
        const ra = jr.requestedAt.getTime();
        const ca = cursor.lastRequestedAt.getTime();
        if (ra < ca) return true;
        if (ra === ca) return jr.id < cursor.lastJoinRequestId;
        return false;
      })
      // Newest-first (DESC requestedAt, DESC id)
      .sort((a, b) => {
        const delta = b.requestedAt.getTime() - a.requestedAt.getTime();
        return delta !== 0 ? delta : b.id.localeCompare(a.id);
      });

    const hasMore = rows.length > limit;
    if (hasMore) rows = rows.slice(0, limit);
    const last = rows.at(-1);
    const nextCursor: ListJoinRequestsByRequesterCursor | null =
      hasMore && last ? { lastRequestedAt: last.requestedAt, lastJoinRequestId: last.id } : null;

    return Promise.resolve({ joinRequests: rows, nextCursor });
  }
}
