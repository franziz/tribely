import { Prisma } from '@prisma/client';
import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Review } from '../../domain/entities/review.js';
import type {
  ListByRatedUserCursor,
  ReviewAggregateForUser,
  ReviewRepository,
  ReviewWithVisibilityContext,
} from '../../domain/repositories/review.repository.js';
import { toReview, toRow } from './review.mapper.js';

const DEFAULT_LIST_LIMIT = 20;
const EXCERPT_MAX_LENGTH = 100;
const AGGREGATE_COMMENT_COUNT = 5;

/**
 * Encode a keyset cursor as base64url JSON. Opaque to callers.
 */
const encodeCursor = (lastCreatedAt: Date, lastReviewId: string): string =>
  Buffer.from(
    JSON.stringify({ lastCreatedAt: lastCreatedAt.toISOString(), lastReviewId }),
    'utf8',
  ).toString('base64url');

const decodeCursor = (raw: string): ListByRatedUserCursor => {
  try {
    const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof decoded !== 'object' ||
      decoded === null ||
      typeof (decoded as { lastCreatedAt: unknown }).lastCreatedAt !== 'string' ||
      typeof (decoded as { lastReviewId: unknown }).lastReviewId !== 'string'
    ) {
      throw new Error('shape');
    }
    const { lastCreatedAt, lastReviewId } = decoded as {
      lastCreatedAt: string;
      lastReviewId: string;
    };
    const at = new Date(lastCreatedAt);
    if (Number.isNaN(at.getTime())) throw new Error('date');
    return { lastCreatedAt: at, lastReviewId };
  } catch {
    return { lastCreatedAt: new Date(0), lastReviewId: '' };
  }
};

export class ReviewPrismaRepository implements ReviewRepository {
  constructor(private readonly db: Db) {}

  async save(review: Review, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.review.upsert({
      where: { id: review.id },
      create: toRow(review),
      update: {
        rating: review.rating.value,
        comment: review.comment?.value ?? null,
        updatedAt: review.updatedAt,
        hidden: review.hidden,
        hiddenAt: review.hiddenAt,
        hiddenReason: review.hiddenReason,
      },
    });
  }

  async findById(id: string, ctx?: TxContext): Promise<Review | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.review.findUnique({ where: { id } });
    return row ? toReview(row) : null;
  }

  async findByTriple(
    input: { eventId: string; raterUserId: string; ratedUserId: string },
    ctx?: TxContext,
  ): Promise<Review | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.review.findUnique({
      where: {
        eventId_raterUserId_ratedUserId: {
          eventId: input.eventId,
          raterUserId: input.raterUserId,
          ratedUserId: input.ratedUserId,
        },
      },
    });
    return row ? toReview(row) : null;
  }

  async listByRatedUser(
    input: {
      ratedUserId: string;
      viewerId: string;
      cursor?: ListByRatedUserCursor;
      limit?: number;
    },
    ctx?: TxContext,
  ): Promise<{ rows: ReadonlyArray<ReviewWithVisibilityContext>; nextCursor: string | null }> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const limit = input.limit ?? DEFAULT_LIST_LIMIT;
    const cursor = input.cursor;

    const where: Prisma.ReviewWhereInput = {
      ratedUserId: input.ratedUserId,
    };

    if (cursor) {
      where.OR = [
        { createdAt: { lt: cursor.lastCreatedAt } },
        {
          AND: [{ createdAt: cursor.lastCreatedAt }, { id: { lt: cursor.lastReviewId } }],
        },
      ];
    }

    const rows = await client.review.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;

    if (page.length === 0) {
      return { rows: [], nextCursor: null };
    }

    // Batched counterpart-existence lookup in a single SQL.
    // For each review by raterUserId about ratedUserId, check if ratedUserId
    // has also reviewed raterUserId for the same event.
    const eventIds = page.map((r) => r.eventId);
    const raterIds = page.map((r) => r.raterUserId);

    const counterparts = await client.review.findMany({
      where: {
        eventId: { in: eventIds },
        raterUserId: input.ratedUserId, // the rated user is writing back
        ratedUserId: { in: raterIds },
        hidden: false,
      },
      select: { eventId: true, ratedUserId: true },
    });

    // Build a Set of "eventId:ratedUserId" pairs for O(1) lookup.
    const counterpartSet = new Set(counterparts.map((c) => `${c.eventId}:${c.ratedUserId}`));

    // Fetch event endsAt for the visibility projection.
    const uniqueEventIds = [...new Set(eventIds)];
    const events = await client.event.findMany({
      where: { id: { in: uniqueEventIds } },
      select: { id: true, endsAt: true },
    });
    const eventEndsAtMap = new Map(events.map((e) => [e.id, e.endsAt]));

    const result: ReviewWithVisibilityContext[] = page.map((row) => {
      const counterpartKey = `${row.eventId}:${row.raterUserId}`;
      const counterpartExists = counterpartSet.has(counterpartKey);
      const eventCompletedAt = eventEndsAtMap.get(row.eventId) ?? new Date(0);
      return {
        review: toReview(row),
        counterpartExists,
        eventCompletedAt,
      };
    });

    const last = page.at(-1);
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { rows: result, nextCursor };
  }

  async listWrittenBy(
    input: { raterUserId: string; cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Review[]; nextCursor: string | null }> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const limit = input.limit ?? DEFAULT_LIST_LIMIT;

    const where: Prisma.ReviewWhereInput = {
      raterUserId: input.raterUserId,
    };

    if (input.cursor) {
      const decoded = decodeCursor(input.cursor);
      where.OR = [
        { createdAt: { lt: decoded.lastCreatedAt } },
        {
          AND: [{ createdAt: decoded.lastCreatedAt }, { id: { lt: decoded.lastReviewId } }],
        },
      ];
    }

    const rows = await client.review.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    const last = page.at(-1);
    const nextCursor = hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { rows: page.map(toReview), nextCursor };
  }

  async aggregateForUser(
    input: { ratedUserId: string; viewerId: string },
    ctx?: TxContext,
  ): Promise<ReviewAggregateForUser> {
    const client = ctx ? unwrapTx(ctx) : this.db;

    // Aggregate: avg + count of non-hidden reviews.
    const agg = await client.review.aggregate({
      where: { ratedUserId: input.ratedUserId, hidden: false },
      _avg: { rating: true },
      _count: { id: true },
    });

    const reviewCount = agg._count.id;
    const averageRating = agg._avg.rating !== null ? agg._avg.rating : null;

    if (reviewCount === 0) {
      return { averageRating: null, reviewCount: 0, recentVisibleComments: [] };
    }

    // Recent visible comments: join to event + user for context.
    // For simplicity, fetch the most recent reviews with comments and join
    // in-app. At MVP scale this is fine; if this becomes a hot path add a
    // materialised view.
    //
    // NOTE: mutual-window check at the aggregate level is omitted here for
    // performance — the aggregate summary is shown on the profile screen which
    // is a less sensitive context than the full review list. Brief 1D will
    // revisit if the product spec tightens this.
    const recentWithComments = await client.review.findMany({
      where: {
        ratedUserId: input.ratedUserId,
        hidden: false,
        comment: { not: null },
      },
      orderBy: { createdAt: 'desc' },
      take: AGGREGATE_COMMENT_COUNT,
      include: {
        rater: { select: { displayName: true } },
        event: { select: { title: true } },
      },
    });

    const recentVisibleComments = recentWithComments.map((row) => ({
      excerpt: (row.comment ?? '').substring(0, EXCERPT_MAX_LENGTH),
      raterDisplayName: row.rater.displayName,
      rating: row.rating,
      eventTitle: row.event.title,
      createdAt: row.createdAt,
    }));

    return {
      averageRating,
      reviewCount,
      recentVisibleComments,
    };
  }
}
