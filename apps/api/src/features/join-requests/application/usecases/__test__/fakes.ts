import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { JoinRequest } from '../../../domain/entities/join-request.js';
import type {
  JoinRequestRepository,
  ListJoinRequestsFilters,
} from '../../../domain/repositories/join-request.repository.js';

// Re-export the cross-feature fakes from events so use case tests have a
// single import surface. These are pure infrastructure-free fakes — sharing
// them keeps a fake UoW / publisher / clock semantic identical across
// features (changing the contract in events automatically propagates here).
export {
  FakeEventPublisher,
  FakeEventRepository,
  FakeUnitOfWork,
  FixedClock,
  TEST_TX,
} from '../../../../events/application/usecases/__test__/fakes.js';

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
      // Stable order: oldest-requested first. Lets tests assert order without
      // depending on Map insertion semantics across rehydration paths.
      .sort((a, b) => a.requestedAt.getTime() - b.requestedAt.getTime());
    return Promise.resolve(rows);
  }
}
