/**
 * Minimal in-memory stand-in for the subset of Prisma's Db API used by
 * `OutboxDispatcher`. Not a general-purpose mock — only mirrors the exact
 * call shapes used in the dispatcher's hot loop. Keeping it narrow keeps
 * the tests fast and the dispatcher's contract obvious from the surface
 * area we actually depend on.
 */

interface OutboxRow {
  id: string;
  seq: bigint;
  type: string;
  aggregateType: string;
  aggregateId: string;
  payload: unknown;
  occurredAt: Date;
  requestId: string | null;
  actorUserId: string | null;
}

interface ConsumerOffsetRow {
  consumerName: string;
  topic: string;
  committedSeq: bigint;
  inFlightSeq: bigint | null;
  attempts: number;
  lastError: string | null;
  lastErrorAt: Date | null;
  blockedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export class FakePrisma {
  readonly outbox: OutboxRow[] = [];
  readonly offsets = new Map<string, ConsumerOffsetRow>();

  // --- outboxEvent ---
  outboxEvent = {
    findUnique: (args: { where: { seq: bigint } }): Promise<OutboxRow | null> =>
      Promise.resolve(this.outbox.find((r) => r.seq === args.where.seq) ?? null),

    findFirst: (args: {
      where: {
        type: string;
        seq: { gt: bigint };
        occurredAt: { lt: Date };
      };
      orderBy: { seq: 'asc' };
    }): Promise<OutboxRow | null> => {
      const matches = this.outbox
        .filter(
          (r) =>
            r.type === args.where.type &&
            r.seq > args.where.seq.gt &&
            r.occurredAt < args.where.occurredAt.lt,
        )
        .sort((a, b) => Number(a.seq - b.seq));
      return Promise.resolve(matches[0] ?? null);
    },
  };

  // --- consumerOffset ---
  consumerOffset = {
    upsert: (args: {
      where: { consumerName: string };
      create: {
        consumerName: string;
        topic: string;
        committedSeq: bigint;
      };
      update: Partial<ConsumerOffsetRow>;
    }): Promise<ConsumerOffsetRow> => {
      const existing = this.offsets.get(args.where.consumerName);
      if (existing) {
        return Promise.resolve(existing);
      }
      const now = new Date();
      const row: ConsumerOffsetRow = {
        consumerName: args.create.consumerName,
        topic: args.create.topic,
        committedSeq: args.create.committedSeq,
        inFlightSeq: null,
        attempts: 0,
        lastError: null,
        lastErrorAt: null,
        blockedAt: null,
        createdAt: now,
        updatedAt: now,
      };
      this.offsets.set(row.consumerName, row);
      return Promise.resolve(row);
    },

    findUnique: (args: { where: { consumerName: string } }): Promise<ConsumerOffsetRow | null> =>
      Promise.resolve(this.offsets.get(args.where.consumerName) ?? null),

    update: (args: {
      where: { consumerName: string };
      data: Partial<ConsumerOffsetRow>;
    }): Promise<ConsumerOffsetRow> => {
      const existing = this.offsets.get(args.where.consumerName);
      if (!existing) {
        return Promise.reject(new Error(`offset not found: ${args.where.consumerName}`));
      }
      const merged: ConsumerOffsetRow = {
        ...existing,
        ...args.data,
        updatedAt: new Date(),
      };
      this.offsets.set(merged.consumerName, merged);
      return Promise.resolve(merged);
    },
  };

  // --- helpers used by tests ---
  insertEvent(partial: Partial<OutboxRow> & Pick<OutboxRow, 'seq' | 'type'>): void {
    this.outbox.push({
      id: `evt_${partial.seq.toString()}`,
      aggregateType: 'TestAggregate',
      aggregateId: 'agg_1',
      payload: {},
      occurredAt: new Date(Date.now() - 60_000), // 1 minute ago — past any settle delay
      requestId: null,
      actorUserId: null,
      ...partial,
    });
  }

  getOffset(name: string): ConsumerOffsetRow | undefined {
    return this.offsets.get(name);
  }
}
