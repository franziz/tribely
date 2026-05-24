import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Report } from '../../domain/entities/report.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import { toReport, toRow } from './report.mapper.js';

const DEFAULT_LIST_LIMIT = 20;

/**
 * Encode a keyset cursor as base64url JSON. Opaque to callers.
 */
const encodeCursor = (lastCreatedAt: Date, lastReportId: string): string =>
  Buffer.from(
    JSON.stringify({ lastCreatedAt: lastCreatedAt.toISOString(), lastReportId }),
    'utf8',
  ).toString('base64url');

const decodeCursor = (raw: string): { lastCreatedAt: Date; lastReportId: string } => {
  try {
    const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof decoded !== 'object' ||
      decoded === null ||
      typeof (decoded as { lastCreatedAt: unknown }).lastCreatedAt !== 'string' ||
      typeof (decoded as { lastReportId: unknown }).lastReportId !== 'string'
    ) {
      throw new Error('shape');
    }
    const { lastCreatedAt, lastReportId } = decoded as {
      lastCreatedAt: string;
      lastReportId: string;
    };
    const at = new Date(lastCreatedAt);
    if (Number.isNaN(at.getTime())) throw new Error('date');
    return { lastCreatedAt: at, lastReportId };
  } catch {
    return { lastCreatedAt: new Date(0), lastReportId: '' };
  }
};

export class ReportPrismaRepository implements ReportRepository {
  constructor(private readonly db: Db) {}

  async save(report: Report, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.report.upsert({
      where: { id: report.id },
      create: toRow(report),
      update: {
        firstReviewedAt: report.firstReviewedAt,
        resolvedAt: report.resolvedAt,
        resolution: report.resolution,
        resolvedByUserId: report.resolvedByUserId,
      },
    });
  }

  async findById(id: string, ctx?: TxContext): Promise<Report | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.report.findUnique({ where: { id } });
    return row ? toReport(row) : null;
  }

  async listUnresolved(
    input: { cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Report[]; nextCursor: string | null }> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const limit = input.limit ?? DEFAULT_LIST_LIMIT;

    type WhereClause = {
      resolvedAt: null;
      OR?: Array<
        { createdAt: { gt: Date } } | { AND: [{ createdAt: Date }, { id: { gt: string } }] }
      >;
    };

    const where: WhereClause = { resolvedAt: null };

    if (input.cursor) {
      const decoded = decodeCursor(input.cursor);
      where.OR = [
        { createdAt: { gt: decoded.lastCreatedAt } },
        {
          AND: [{ createdAt: decoded.lastCreatedAt }, { id: { gt: decoded.lastReportId } }],
        },
      ];
    }

    const rows = await client.report.findMany({
      where,
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page.at(-1);
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { rows: page.map(toReport), nextCursor };
  }

  async listOlderThan(input: { resolvedAtBefore: Date }, ctx?: TxContext): Promise<Report[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const rows = await client.report.findMany({
      where: {
        resolvedAt: { not: null, lt: input.resolvedAtBefore },
      },
      orderBy: { resolvedAt: 'asc' },
    });
    return rows.map(toReport);
  }

  async listOpenOlderThan(input: { createdAtBefore: Date }, ctx?: TxContext): Promise<Report[]> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const rows = await client.report.findMany({
      where: {
        resolvedAt: null,
        createdAt: { lt: input.createdAtBefore },
      },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toReport);
  }

  async deleteAllForUser(userId: string, ctx: TxContext): Promise<number> {
    const client = unwrapTx(ctx);
    // Self-contained: deletes reports filed by the user AND reports targeting
    // reviews the user authored or was rated in. Order-independent w.r.t. the
    // reviews cascade — reads `reviews` to expand the target set even though
    // a sibling adapter will also delete from `reviews` in the same tx.
    //
    // NOTE: Polymorphic resolvers for targetType IN ('user', 'event') are
    // deferred — see TRI-30 spec and TRI-155 PM brief. Add resolver branches
    // for those target types when they are implemented.
    return await client.$executeRaw`
      DELETE FROM "reports"
       WHERE "reporterUserId" = ${userId}
          OR ("targetType" = 'review'
              AND "targetId" IN (
                SELECT "id" FROM "reviews"
                 WHERE "raterUserId" = ${userId}
                    OR "ratedUserId" = ${userId}
              ))
    `;
  }

  async listByReporter(
    input: { reporterUserId: string; cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Report[]; nextCursor: string | null }> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const limit = input.limit ?? DEFAULT_LIST_LIMIT;

    type WhereClause = {
      reporterUserId: string;
      OR?: Array<
        { createdAt: { lt: Date } } | { AND: [{ createdAt: Date }, { id: { lt: string } }] }
      >;
    };

    const where: WhereClause = { reporterUserId: input.reporterUserId };

    if (input.cursor) {
      const decoded = decodeCursor(input.cursor);
      where.OR = [
        { createdAt: { lt: decoded.lastCreatedAt } },
        {
          AND: [{ createdAt: decoded.lastCreatedAt }, { id: { lt: decoded.lastReportId } }],
        },
      ];
    }

    const rows = await client.report.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page.at(-1);
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { rows: page.map(toReport), nextCursor };
  }
}
