/**
 * UnitOfWork is the domain-facing port for atomicity across multiple
 * repository writes. The application layer calls `unitOfWork.run(work)`
 * and within `work` it can call repositories and the EventPublisher
 * passing the supplied `TxContext`. All writes inside the closure
 * commit atomically; if `work` throws, all writes roll back.
 *
 * `TxContext` is intentionally opaque to the domain — it carries
 * implementation-specific transaction state (Prisma, MongoDB session, etc.)
 * which infrastructure adapters unwrap. Domain code never inspects it.
 */
export interface TxContext {
  readonly __brand: 'TxContext';
}

export interface UnitOfWork {
  run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T>;
}
