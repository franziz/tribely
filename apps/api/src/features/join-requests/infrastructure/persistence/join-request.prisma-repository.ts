import { Prisma } from '@prisma/client';
import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { AppError } from '@/core/errors/app-error.js';
import type { JoinRequest } from '../../domain/entities/join-request.js';
import type {
  JoinRequestRepository,
  ListJoinRequestsFilters,
} from '../../domain/repositories/join-request.repository.js';
import { toJoinRequest, toRow } from './join-request.mapper.js';

export class JoinRequestPrismaRepository implements JoinRequestRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<JoinRequest | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.joinRequest.findUnique({ where: { id } });
    return row ? toJoinRequest(row) : null;
  }

  async findActiveByEventAndRequester(
    eventId: string,
    requesterUserId: string,
    ctx?: TxContext,
  ): Promise<JoinRequest | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // "Active" === non-terminal. The partial unique index on the table covers
    // the same predicate, so at most one row can ever match.
    const row = await client.joinRequest.findFirst({
      where: {
        eventId,
        requesterUserId,
        status: { in: ['pending', 'approved'] },
      },
    });
    return row ? toJoinRequest(row) : null;
  }

  async save(jr: JoinRequest, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // `create` uses the full row projection (id, requestedAt, ...). `update`
    // sources from the aggregate's strict-typed getters — keeps Prisma's
    // `JoinRequestUpdateInput` happy under `exactOptionalPropertyTypes` (the
    // unchecked-create input allows `undefined` on optional columns; the
    // update input shape is stricter).
    //
    // The partial unique index `join_requests_active_per_user_event_uniq`
    // can fire on the `create` branch when a sibling request for the same
    // (eventId, requesterUserId) is already pending/approved. We translate
    // P2002 into a structured 409 with subcode 'ACTIVE_REQUEST_EXISTS' so the
    // presentation layer can render an unambiguous message without parsing
    // strings. This is the race-loser path — the use case's up-front
    // `findActiveByEventAndRequester` check handles the cooperating path.
    try {
      await client.joinRequest.upsert({
        where: { id: jr.id },
        create: toRow(jr),
        update: {
          status: jr.status,
          decidedAt: jr.decidedAt,
          decidedByUserId: jr.decidedByUserId,
          decisionReason: jr.decisionReason,
        },
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw AppError.conflict('Active join request already exists for this event', {
          subcode: 'ACTIVE_REQUEST_EXISTS',
        });
      }
      throw err;
    }
  }

  /**
   * Required-ctx by design: capacity enforcement only holds when the caller
   * has already acquired `SELECT ... FOR UPDATE` on the parent Event row
   * inside the same transaction. Allowing a non-tx call would silently bypass
   * the lock and admit a race window between count and approve.
   */
  async countApproved(eventId: string, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    return client.joinRequest.count({
      where: { eventId, status: 'approved' },
    });
  }

  async findByEvent(
    eventId: string,
    filters: ListJoinRequestsFilters,
    ctx?: TxContext,
  ): Promise<JoinRequest[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // No keyset pagination: capacity caps event size, so listings are bounded
    // small. If this assumption changes (mass-RSVP campaigns, viewer roles
    // that see history), revisit and add a cursor like `findManyForListing`.
    const where: Prisma.JoinRequestWhereInput = { eventId };
    if (filters.requesterUserId !== undefined) {
      where.requesterUserId = filters.requesterUserId;
    }
    const rows = await client.joinRequest.findMany({
      where,
      orderBy: { requestedAt: 'asc' },
    });
    return rows.map(toJoinRequest);
  }
}
