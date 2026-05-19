import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { Db } from '@/core/db/prisma.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { UserBlock } from '../../domain/entities/user-block.js';
import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import { toRow, toUserBlock } from './user-block.mapper.js';

/**
 * Encode a keyset cursor for `listInitiatedBy`.
 * Encodes (createdAt, id) as base64url JSON — opaque to callers.
 */
const encodeCursor = (createdAt: Date, id: string): string =>
  Buffer.from(JSON.stringify({ createdAt: createdAt.toISOString(), id }), 'utf8').toString(
    'base64url',
  );

const decodeCursor = (raw: string): { createdAt: Date; id: string } => {
  try {
    const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof decoded !== 'object' ||
      decoded === null ||
      typeof (decoded as { createdAt: unknown }).createdAt !== 'string' ||
      typeof (decoded as { id: unknown }).id !== 'string'
    ) {
      throw new Error('shape');
    }
    const { createdAt, id } = decoded as { createdAt: string; id: string };
    const at = new Date(createdAt);
    if (Number.isNaN(at.getTime())) throw new Error('date');
    return { createdAt: at, id };
  } catch {
    return { createdAt: new Date(0), id: '' };
  }
};

export class UserBlockPrismaRepository implements UserBlockRepository {
  constructor(private readonly db: Db) {}

  async save(block: UserBlock, ctx?: TxContext): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    await client.userBlock.upsert({
      where: {
        initiatorUserId_blockedUserId: {
          initiatorUserId: block.initiatorUserId,
          blockedUserId: block.blockedUserId,
        },
      },
      create: toRow(block),
      update: {}, // Idempotent — no fields to update on an existing block.
    });
  }

  async delete(
    input: { initiatorUserId: string; blockedUserId: string },
    ctx?: TxContext,
  ): Promise<void> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    // deleteMany is safe when row doesn't exist (no-op) unlike delete which throws P2025.
    await client.userBlock.deleteMany({
      where: {
        initiatorUserId: input.initiatorUserId,
        blockedUserId: input.blockedUserId,
      },
    });
  }

  async findOne(
    input: { initiatorUserId: string; blockedUserId: string },
    ctx?: TxContext,
  ): Promise<UserBlock | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.userBlock.findUnique({
      where: {
        initiatorUserId_blockedUserId: {
          initiatorUserId: input.initiatorUserId,
          blockedUserId: input.blockedUserId,
        },
      },
    });
    return row ? toUserBlock(row) : null;
  }

  async findBidirectional(
    input: { userA: string; userB: string },
    ctx?: TxContext,
  ): Promise<UserBlock | null> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const row = await client.userBlock.findFirst({
      where: {
        OR: [
          { initiatorUserId: input.userA, blockedUserId: input.userB },
          { initiatorUserId: input.userB, blockedUserId: input.userA },
        ],
      },
    });
    return row ? toUserBlock(row) : null;
  }

  async filterBlocked(
    input: { viewerId: string; candidateIds: string[] },
    ctx?: TxContext,
  ): Promise<Set<string>> {
    if (input.candidateIds.length === 0) return new Set<string>();

    const client = ctx ? unwrapTx(ctx) : this.db;
    const rows = await client.userBlock.findMany({
      where: {
        OR: [
          {
            initiatorUserId: input.viewerId,
            blockedUserId: { in: input.candidateIds },
          },
          {
            initiatorUserId: { in: input.candidateIds },
            blockedUserId: input.viewerId,
          },
        ],
      },
      select: { initiatorUserId: true, blockedUserId: true },
    });

    const blocked = new Set<string>();
    for (const row of rows) {
      // Add whichever side is the candidate (not the viewer).
      if (row.initiatorUserId === input.viewerId) {
        blocked.add(row.blockedUserId);
      } else {
        blocked.add(row.initiatorUserId);
      }
    }
    return blocked;
  }

  async listInitiatedBy(
    input: { initiatorUserId: string; cursor?: string; limit: number },
    ctx?: TxContext,
  ): Promise<{ rows: UserBlock[]; nextCursor: string | null }> {
    const client = ctx ? unwrapTx(ctx) : this.db;
    const cursor = input.cursor ? decodeCursor(input.cursor) : null;

    const whereBase = { initiatorUserId: input.initiatorUserId };
    const whereWithCursor = cursor
      ? {
          ...whereBase,
          OR: [
            { createdAt: { lt: cursor.createdAt } },
            { AND: [{ createdAt: cursor.createdAt }, { id: { lt: cursor.id } }] },
          ],
        }
      : whereBase;

    const rows = await client.userBlock.findMany({
      where: whereWithCursor,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: input.limit + 1,
    });

    const hasMore = rows.length > input.limit;
    const page = hasMore ? rows.slice(0, input.limit) : rows;
    const last = page.at(-1);
    const nextCursor: string | null =
      hasMore && last ? encodeCursor(last.createdAt, last.id) : null;

    return { rows: page.map(toUserBlock), nextCursor };
  }
}
