import type { Prisma } from '@prisma/client';
import type { Db } from './prisma.js';
import type { TxContext, UnitOfWork } from './unit-of-work.port.js';

/**
 * Prisma adapter for UnitOfWork. The `TxContext` returned to the closure
 * is the Prisma transaction client wrapped in an opaque marker — only
 * `unwrapTx` (called by other infrastructure adapters) can extract it.
 */
type PrismaTxContext = TxContext & {
  readonly __tx: Prisma.TransactionClient;
};

const wrap = (tx: Prisma.TransactionClient): PrismaTxContext =>
  ({ __brand: 'TxContext', __tx: tx }) as PrismaTxContext;

/**
 * Adapter-internal helper. Infrastructure code (repositories, event publisher)
 * calls this to recover the Prisma transaction client from an opaque TxContext.
 * Throws if the context did not originate from PrismaUnitOfWork.
 */
export const unwrapTx = (ctx: TxContext): Prisma.TransactionClient => {
  const candidate = ctx as PrismaTxContext;
  if (!candidate.__tx) {
    throw new Error('TxContext was not produced by PrismaUnitOfWork');
  }
  return candidate.__tx;
};

export class PrismaUnitOfWork implements UnitOfWork {
  constructor(private readonly db: Db) {}

  run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T> {
    return this.db.$transaction((tx) => work(wrap(tx)));
  }
}
