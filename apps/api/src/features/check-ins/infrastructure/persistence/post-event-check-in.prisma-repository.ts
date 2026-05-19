import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import type {
  ApprovedAttendanceWithoutCheckIn,
  PostEventCheckInRepository,
  RetentionSweepFilter,
} from '../../domain/repositories/post-event-check-in.repository.js';
import { toCheckIn, toRow } from './post-event-check-in.mapper.js';

export class PostEventCheckInPrismaRepository implements PostEventCheckInRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string, ctx?: TxContext): Promise<PostEventCheckIn | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.postEventCheckIn.findUnique({ where: { id } });
    return row ? toCheckIn(row) : null;
  }

  async findByUserAndEvent(
    userId: string,
    eventId: string,
    ctx?: TxContext,
  ): Promise<PostEventCheckIn | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.postEventCheckIn.findUnique({
      where: { userId_eventId: { userId, eventId } },
    });
    return row ? toCheckIn(row) : null;
  }

  async listPendingForUser(userId: string, ctx?: TxContext): Promise<PostEventCheckIn[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const rows = await client.postEventCheckIn.findMany({
      where: { userId, status: 'pending' },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toCheckIn);
  }

  async save(checkIn: PostEventCheckIn, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.postEventCheckIn.upsert({
      where: { id: checkIn.id },
      create: toRow(checkIn),
      update: {
        status: checkIn.status,
        acknowledgedAt: checkIn.acknowledgedAt,
        flaggedAt: checkIn.flaggedAt,
        reportBody: checkIn.reportBody,
        resolvedAt: checkIn.resolvedAt,
      },
    });
  }

  async listForRetentionSweep(
    filter: RetentionSweepFilter,
    ctx?: TxContext,
  ): Promise<PostEventCheckIn[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const where: Parameters<typeof client.postEventCheckIn.findMany>[0]['where'] = {
      status: filter.status,
      createdAt: { lt: filter.olderThan },
    };
    if (filter.hasResolvedAt === true) {
      where.resolvedAt = { not: null };
    } else if (filter.hasResolvedAt === false) {
      where.resolvedAt = null;
    }
    const rows = await client.postEventCheckIn.findMany({
      where,
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toCheckIn);
  }

  async deleteById(id: string, ctx: TxContext): Promise<void> {
    const client = unwrapTx(ctx);
    await client.postEventCheckIn.delete({ where: { id } });
  }

  async pseudonymiseForUser(
    input: { userId: string; pseudonymUserId: string; role: 'attendee' | 'host' },
    ctx: TxContext,
  ): Promise<number> {
    const client = unwrapTx(ctx);
    const field = input.role === 'attendee' ? 'userId' : 'hostUserId';
    const result = await client.postEventCheckIn.updateMany({
      where: { [field]: input.userId },
      data: { [field]: input.pseudonymUserId },
    });
    return result.count;
  }

  /**
   * Raw SQL query: events where the user has an approved join request, the
   * event has ended within the look-back window, and no check-in exists yet.
   *
   * Column names use camelCase — Prisma's default mapping (no @map on those
   * columns). Verified against migration SQL in:
   *   - 20260511073509_join_requests: "requesterUserId", "eventId", "status"
   *   - 20260511051658_events: "hostUserId", "endsAt"
   *   - post_event_check_ins: "userId", "eventId" (this migration)
   */
  async findApprovedAttendancesWithoutCheckIn(
    userId: string,
    window: { sinceEndsAt: Date; untilEndsAt: Date },
    ctx?: TxContext,
  ): Promise<ApprovedAttendanceWithoutCheckIn[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const rows = await client.$queryRaw<ApprovedAttendanceWithoutCheckIn[]>`
      SELECT jr."eventId", e."hostUserId"
      FROM join_requests jr
      JOIN events e ON e.id = jr."eventId"
      WHERE jr."requesterUserId" = ${userId}
        AND jr.status = 'approved'
        AND e."endsAt" < ${window.untilEndsAt}
        AND e."endsAt" > ${window.sinceEndsAt}
        AND NOT EXISTS (
          SELECT 1 FROM post_event_check_ins p
          WHERE p."userId" = jr."requesterUserId"
            AND p."eventId" = jr."eventId"
        )
    `;
    return rows;
  }
}
